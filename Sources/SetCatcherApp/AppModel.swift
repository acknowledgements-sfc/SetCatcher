import AppKit
import Foundation
import ServiceManagement
import SetCatcherCore
import UniformTypeIdentifiers

/// Outcome of the most recently finished capture, for the menu bar's "previous capture" row.
enum LastCaptureOutcome: Equatable {
    case success(sessionID: UUID)
    case failed(String)
}

/// Canonical presentation input shared by the main Live surface and menu-bar cockpit.
/// Filesystem and bookmark checks are cached separately, so reading this snapshot is cheap.
struct CockpitSnapshot: Equatable {
    let state: LiveProtectionState
    let sourceDisplayName: String?
    let attentionEvent: AttentionEvent?
    let inputLevel: Float
    let recordingStartedAt: Date?
    let armedSinceText: String?
    let lastProtectedFooterText: String?
}

struct ProtectionReceipt: Equatable {
    let filename: String
    let archivePath: String
    let durationText: String
    let sizeText: String
}

private enum MenuBarPulseMode: Equatable {
    case none
    case flash
    case pulse
}

private struct PendingCaptureRecovery {
    let result: CaptureResult
    let sourceAppID: String
    let captureRoute: CaptureArchiveRoute
    let captureBackend: CaptureArchiveBackend?
    let captureDeviceTransport: String?
}

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var probeResults: [SoftwareProbeResult] = []
    @Published private(set) var sessions: [ArchiveMetadata] = []
    @Published private(set) var folderAccesses: [FolderAccess] = []
    @Published private(set) var lastScanResults: [FolderScanResult] = []
    @Published private(set) var importedTracklists: [String: [ImportedTracklist]] = [:]
    @Published private(set) var librarySummaries: [LibrarySessionSummary] = []
    @Published private(set) var setContexts: [UUID: SetContext] = [:]
    @Published private(set) var activityEvents: [ActivityEvent] = []
    @Published private(set) var settings = AppSettings.default
    @Published private(set) var virtualDJNetworkProbeResult: VirtualDJNetworkProbeResult?
    @Published private(set) var isCheckingVirtualDJNetwork = false
    @Published private(set) var isScanning = false
    @Published private(set) var isFolderChangeScanPending = false
    @Published private(set) var lastScanDate: Date?
    @Published private(set) var nextScanDate: Date?
    @Published var selectedRoute: Route = .home {
        didSet {
            recordRouteHistoryIfNeeded(from: oldValue)
        }
    }
    @Published var statusMessage = "Checking protection status"
    @Published private(set) var profile = DJProfile()
    /// True when macOS registered the login item but still needs Login Items approval.
    @Published private(set) var launchAtLoginNeedsApproval = false
    @Published private(set) var captureState = CaptureUIState() {
        didSet { handleCaptureStateChange(from: oldValue) }
    }
    /// What SetCatcher is listening to (hardware USB feed vs laptop driver). Plain language.
    @Published private(set) var liveCaptureListening = LiveCaptureListeningSnapshot.detecting
    @Published private(set) var virtualDJNetworkCommandResult: VirtualDJNetworkCommandResult?
    @Published private(set) var playbackState = PlaybackViewState()

    // MARK: Menu bar state
    /// True briefly after launch while background services spin up (prototype: ~1.6s flash).
    ///
    /// Icon flash/pulse is a ~10Hz `Task` (`menuBarIconOpacity`), never `TimelineView` in the
    /// `MenuBarExtra` label — that host spins CPU on `NSStatusBarButton.setImage`.
    @Published private(set) var isLaunchingForMenuBar = true {
        didSet {
            if oldValue != isLaunchingForMenuBar {
                noteMenuBarPresentationChanged()
            }
        }
    }
    /// Set when a capture just finished archiving; the menu bar shows "Protected" until this passes.
    @Published private(set) var justSavedUntil: Date? {
        didSet { noteMenuBarPresentationChanged() }
    }
    /// 1 = full; driven at ~10Hz while launching (flash) or capturing (pulse).
    @Published private(set) var menuBarIconOpacity: Double = 1
    /// 0…1 linear progress for the 1.35s label slide-in; 1 = settled.
    @Published private(set) var menuBarLabelSlideProgress: Double = 1
    private var menuBarPulseTask: Task<Void, Never>?
    private var menuBarPulseAnchor = Date()
    private var menuBarLabelSlideStartedAt: Date?
    private var lastMenuBarHadLabel = false
    private var lastMenuBarPulseMode: MenuBarPulseMode = .none
    @Published private(set) var recordingStartedAt: Date?
    @Published private(set) var armedSince: Date?
    @Published private(set) var lastCaptureOutcome: LastCaptureOutcome?
    /// Live staging WAV byte count while capturing (for the capture strip).
    @Published private(set) var captureStagingBytes: Int64?
    @Published private(set) var liveAttentionEvents: [AttentionEvent] = []
    @Published private(set) var recoverableStagingURL: URL?
    private var savedFlashTask: Task<Void, Never>?
    private static let savedFlashDuration: TimeInterval = 5
    private static let queuedToastMaxAge: TimeInterval = 30
    /// When the app was backgrounded at save time, hold toast until return if still fresh.
    private var queuedProtectedToastAt: Date?

    /// Optional account license snapshot. Nil when signed out or unreachable — local features stay full.
    @Published private(set) var accountLicenseSummary: String?
    @Published private(set) var accountSyncMessage: String?
    @Published private(set) var isAccountSyncing = false

    /// Consumed by `SessionLibraryView` when navigating from Home (session + optional search seed).
    @Published var libraryFocusSessionID: UUID?
    @Published var libraryFocusSearch: String = ""

    /// Preview-only clock override for greeting matrix (morning / afternoon / evening).
    @Published private(set) var previewNow: Date?

    private var routeHistory: [Route] = [.home]
    private var routeHistoryIndex: Int = 0
    private var isApplyingHistoryNavigation = false

    var canGoBack: Bool { routeHistoryIndex > 0 }
    var canGoForward: Bool { routeHistoryIndex < routeHistory.count - 1 }

    func openLibrary(sessionID: UUID? = nil, search: String = "") {
        libraryFocusSessionID = sessionID
        libraryFocusSearch = search
        selectedRoute = .library
    }

    func consumeLibraryFocus() -> (sessionID: UUID?, search: String) {
        let focus = (libraryFocusSessionID, libraryFocusSearch)
        libraryFocusSessionID = nil
        libraryFocusSearch = ""
        return focus
    }

    func goBack() {
        guard canGoBack else { return }
        isApplyingHistoryNavigation = true
        routeHistoryIndex -= 1
        selectedRoute = routeHistory[routeHistoryIndex]
        isApplyingHistoryNavigation = false
    }

    func goForward() {
        guard canGoForward else { return }
        isApplyingHistoryNavigation = true
        routeHistoryIndex += 1
        selectedRoute = routeHistory[routeHistoryIndex]
        isApplyingHistoryNavigation = false
    }

    private func recordRouteHistoryIfNeeded(from oldValue: Route) {
        guard !isApplyingHistoryNavigation else { return }
        guard selectedRoute != oldValue else { return }
        if routeHistoryIndex < routeHistory.count - 1 {
            routeHistory = Array(routeHistory[...routeHistoryIndex])
        }
        if routeHistory.last == selectedRoute {
            return
        }
        routeHistory.append(selectedRoute)
        routeHistoryIndex = routeHistory.count - 1
    }

    /// App id when `selectedRoute` is `.app` or `.recovery`.
    var selectedAppID: String? {
        selectedRoute.appID
    }

    var archiveRoot: URL {
        resolvedArchiveRoot()
    }

    var libraryStatistics: LibraryStatistics {
        LibraryStatisticsCalculator.calculate(archives: sessions, summaries: librarySummaries)
    }

    var topTracks: [TrackPlayCount] {
        CrossSetAggregation.topTracks(from: allImportedTracklists)
    }

    var venueCounts: [VenueCount] {
        CrossSetAggregation.venues(from: Array(setContexts.values))
    }

    var tagCounts: [TagCount] {
        CrossSetAggregation.tags(from: Array(setContexts.values))
    }

    private let probe = SoftwareProbe()
    private let folderAccessStore = FolderAccessStore()
    private let importedTracklistStore = ImportedTracklistStore()
    private let setContextStore = SetContextStore()
    private let activityLogStore = ActivityLogStore()
    private let appSettingsStore = AppSettingsStore()
    private let profileStore = DJProfileStore()
    private let pendingCaptureRecoveryStore = PendingCaptureRecoveryStore()
    private let notificationService = LocalNotificationService()
    private let folderChangeMonitor = FolderChangeMonitor()
    /// Watches history-export folders so late-written exports still auto-attach.
    private let historyChangeMonitor = FolderChangeMonitor()
    private let audioPlaybackService = LocalAudioPlaybackService()
    private let dataMigration = SetCatcherDataMigration()
    private var historyIngestTask: Task<Void, Never>?
    private var playbackProgressTask: Task<Void, Never>?
    let captureService = CaptureService()
    let appAudioCaptureService = AppAudioCaptureService()
    private var captureSession = CaptureSessionCoordinator()
    private let captureIdleSleepGuard = CaptureIdleSleepGuard()
    /// Weak handle so `AppDelegate.applicationWillTerminate` can release the idle-sleep activity.
    static weak var lifecycleOwner: AppModel?
    private var scanTask: Task<Void, Never>?
    private var folderChangeScanTask: Task<Void, Never>?
    var captureMeterTask: Task<Void, Never>?
    private var appAudioPollTask: Task<Void, Never>?
    private var captureTargetPollTask: Task<Void, Never>?
    private var captureInputPollTask: Task<Void, Never>?
    /// When true, auto-arm must not re-arm until the user Arms again or changes mode.
    private var userDisarmedAppAudio = false
    /// When true, Pioneer unattended Input Capture must not re-arm until Arm, posture change, or the device reappears.
    private var userDisarmedInputCapture = false
    /// When true, the DJ explicitly chose App audio and Pioneer auto-switch must wait for device reappear.
    private var userSuppressedPioneerAutoSwitch = false
    /// When true, the next Input device selection pins Analog Mixer rec-out.
    private var pendingAnalogRecOutPin = false
    private var lastPioneerDeviceID: String?
    /// `PendingAlternateSource.id`s the user has dismissed this session — suppresses
    /// re-prompting for the same still-running alternate on every poll.
    private var dismissedAlternateSourceIDs: Set<String> = []
    private var liveCaptureDetection = LiveCaptureDetectionTracker()
    private var lastLiveCaptureKind: LiveCaptureRouteKind?
    private var lastLiveCaptureDeviceID: String?
    private var lastLiveCaptureBackend: LiveCaptureRecordingBackend?
    private var hardwareObservationCache: [String: (channels: Int, formatOK: Bool)] = [:]
    /// When true, profile mutations stay in memory (SwiftUI previews).
    private var suppressProfilePersistence = false
    /// Attention event IDs already posted as urgent notifications this session.
    private var notifiedAttentionIDs: Set<String> = []
    private var pendingCaptureRecovery: PendingCaptureRecovery?

    init() {
        Self.lifecycleOwner = self
        notificationService.requestAuthorization()
        let migrationResult = dataMigration.run()
        refresh()
        restorePendingCaptureRecovery()
        if let migrationMessage = migrationResult.userMessage {
            statusMessage = migrationMessage
        }
        startBackgroundScanning()
        var next = captureState
        next.mode = settings.captureMode
        captureState = next
        captureSession = CaptureSessionCoordinator(config: settings.silenceSessionConfig)
        appAudioCaptureService.onStreamStopped = { [weak self] error in
            Task { @MainActor in
                self?.applyAppAudioCaptureFailure(error)
            }
        }
        appAudioCaptureService.onInterruptedCapture = { [weak self] result, error in
            Task { @MainActor in
                self?.applyInterruptedAppAudioCapture(result, error: error)
            }
        }
        startCapturePolling()
        // Launch catch-up: heal any set whose history export landed while the
        // app was closed, before the user ever looks at the library.
        ingestHistoryNow()
        // Defer audio-device enumeration and the first auto-arm pass until after the
        // first frame. Both can touch Core Audio; this init runs during SwiftUI scene
        // instantiation, so a HAL stall here would prevent the window from appearing.
        // Do NOT wait for the 15s idle poll — rekordbox already running at launch
        // would otherwise sit unarmed until that timer fires.
        Task { @MainActor [weak self] in
            await Task.yield()
            try? await Task.sleep(nanoseconds: 500_000_000)
            self?.refreshAudioInputs()
            await self?.refreshAppAudioTargets(attemptAutoArm: true)
        }

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            await MainActor.run { self?.isLaunchingForMenuBar = false }
        }
        noteMenuBarPresentationChanged()
    }

    deinit {
        scanTask?.cancel()
        folderChangeScanTask?.cancel()
        menuBarPulseTask?.cancel()
        captureMeterTask?.cancel()
        appAudioPollTask?.cancel()
        captureTargetPollTask?.cancel()
        captureInputPollTask?.cancel()
        historyIngestTask?.cancel()
        playbackProgressTask?.cancel()
        folderChangeMonitor.stop()
        historyChangeMonitor.stop()
        captureIdleSleepGuard.release()
    }

    /// Ends any idle-sleep activity held for Capture (Disarm, terminate, teardown).
    func releaseCaptureIdleSleepAssertion() {
        captureIdleSleepGuard.release()
    }

    var protectedAdapterCount: Int {
        probeResults.filter { result in
            !reachableRecordingFolders(for: result.software.id).isEmpty
        }.count
    }

    var protectionSymbolName: String {
        switch protectionState {
        case .protected, .scanning:
            return "record.circle.fill"
        case .needsSetup:
            return "record.circle"
        case .attentionNeeded:
            return "exclamationmark.triangle.fill"
        }
    }

    var protectionState: ProtectionState {
        let hasConfigured = folderAccesses.contains { $0.kind == .recordings }
        let hasUnreachable = folderAccesses.contains { access in
            access.kind == .recordings && !folderAccessStore.isReachable(access)
        }
        return ProtectionState.derive(
            isScanning: isScanning,
            hasUnreachableFolder: hasUnreachable,
            hasConfiguredRecordingsFolder: hasConfigured
        )
    }

    var headlineStatus: String {
        protectionState.headline
    }

    /// Compact warning shown in the menu bar regardless of the "show folder scan details" setting.
    var folderHealthWarning: String? {
        guard protectionState == .attentionNeeded else { return nil }
        let unreachableCount = folderAccesses.filter { access in
            access.kind == .recordings && !folderAccessStore.isReachable(access)
        }.count
        guard unreachableCount > 0 else { return nil }
        return "\(unreachableCount) folder\(unreachableCount == 1 ? "" : "s") unreachable"
    }

    // MARK: Menu bar

    var menuBarState: MenuBarState {
        MenuBarState.derive(
            isLaunching: isLaunchingForMenuBar,
            live: liveProtectionState,
            djAppName: liveSourceDisplayName
        )
    }

    var menuBarElapsedText: String? {
        guard let recordingStartedAt else { return nil }
        let elapsed = Int(Date().timeIntervalSince(recordingStartedAt))
        return ElapsedClockFormat.minutesSeconds(elapsed)
    }

    var menuBarElapsedHMS: String? {
        guard let recordingStartedAt else { return nil }
        let elapsed = Int(Date().timeIntervalSince(recordingStartedAt))
        return ElapsedClockFormat.hms(elapsed)
    }

    /// Starts or stops the 10Hz status-item opacity/slide task. Safe to call on every state change.
    func noteMenuBarPresentationChanged() {
        let state = menuBarState
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let hasLabel = state.label != nil

        if hasLabel && !lastMenuBarHadLabel {
            menuBarLabelSlideStartedAt = Date()
            menuBarLabelSlideProgress = reduceMotion ? 1 : 0
        } else if !hasLabel {
            menuBarLabelSlideStartedAt = nil
            menuBarLabelSlideProgress = 1
        }
        lastMenuBarHadLabel = hasLabel

        let mode: MenuBarPulseMode = state.isFlashing ? .flash : (state.isPulsing ? .pulse : .none)
        if mode != lastMenuBarPulseMode {
            menuBarPulseAnchor = Date()
            lastMenuBarPulseMode = mode
            if mode == .none || reduceMotion {
                menuBarIconOpacity = 1
            }
        }

        let needsTask = !reduceMotion && (state.isFlashing || state.isPulsing || menuBarLabelSlideProgress < 1)
        if !needsTask {
            menuBarPulseTask?.cancel()
            menuBarPulseTask = nil
            menuBarIconOpacity = 1
            if reduceMotion {
                menuBarLabelSlideProgress = 1
            }
            return
        }
        guard menuBarPulseTask == nil else { return }
        menuBarPulseTask = Task { [weak self] in
            while !Task.isCancelled {
                await MainActor.run { self?.tickMenuBarPresentation() }
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
    }

    private func tickMenuBarPresentation() {
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            menuBarIconOpacity = 1
            menuBarLabelSlideProgress = 1
            menuBarPulseTask?.cancel()
            menuBarPulseTask = nil
            return
        }

        let state = menuBarState
        let now = Date()
        if state.isFlashing {
            let t = now.timeIntervalSince(menuBarPulseAnchor)
            menuBarIconOpacity = 0.625 + 0.375 * cos(2 * Double.pi * t / 0.8)
        } else if state.isPulsing {
            let t = now.timeIntervalSince(menuBarPulseAnchor)
            menuBarIconOpacity = 0.725 + 0.275 * cos(2 * Double.pi * t / 2.4)
        } else {
            menuBarIconOpacity = 1
        }

        if let start = menuBarLabelSlideStartedAt {
            menuBarLabelSlideProgress = min(1, max(0, now.timeIntervalSince(start) / 1.35))
            if menuBarLabelSlideProgress >= 1 {
                menuBarLabelSlideStartedAt = nil
            }
        }

        if !state.isFlashing, !state.isPulsing, menuBarLabelSlideProgress >= 1 {
            menuBarPulseTask?.cancel()
            menuBarPulseTask = nil
            menuBarIconOpacity = 1
        }
    }

    // MARK: Live protection card

    var liveProtectionState: LiveProtectionState {
        LiveProtectionState.derive(input: LiveProtectionDeriveInput(
            capturePhase: captureState.phase,
            hasSelectedSource: captureState.selectedTargetApp != nil || captureState.selectedDeviceID != nil,
            hasDetectedSource: probeResults.contains {
                !$0.runningApplicationBundleIdentifiers.isEmpty || !$0.installedApplicationURLs.isEmpty
            },
            hasLiveAttention: !liveAttentionEvents.isEmpty,
            justSaved: justSavedUntil != nil,
            isWatching: captureState.phase == .watching
        ))
    }

    /// The completion toast is transient; controls and persistent status keep reflecting
    /// whether Capture resumed watching or finished disarmed underneath it.
    var liveOperationalState: LiveProtectionState {
        guard liveProtectionState == .setProtected else { return liveProtectionState }
        return captureState.phase == .watching ? .armed : .ready
    }

    var cockpitSnapshot: CockpitSnapshot {
        CockpitSnapshot(
            state: liveOperationalState,
            sourceDisplayName: liveSourceDisplayName,
            attentionEvent: liveAttentionEvents.first,
            inputLevel: captureState.inputLevel,
            recordingStartedAt: recordingStartedAt,
            armedSinceText: liveArmedSinceText,
            lastProtectedFooterText: liveLastProtectedFooterText
        )
    }

    var cockpitHeadline: String {
        let source = liveSourceDisplayName ?? "Protection"
        switch liveOperationalState.primaryDisplay {
        case .noSource: return "No protection source"
        case .detected: return "\(source) detected"
        case .ready: return "Ready"
        case .armed, .setProtected: return "Armed"
        case .capturing: return "Capturing"
        case .saving: return "Saving"
        case .attentionNeeded: return "Attention needed"
        }
    }

    var cockpitStatusDetail: String {
        let source = liveSourceDisplayName ?? "the selected source"
        switch liveOperationalState.primaryDisplay {
        case .noSource:
            return "Add a DJ app, recording folder, or input device to begin."
        case .detected:
            return "\(source) is available. Finish setup to protect the next set."
        case .ready:
            return "\(source) is configured but not armed."
        case .armed, .setProtected:
            return "Watching \(source) and waiting for audio."
        case .capturing:
            return "Capturing \(source). Saving and recovery controls remain available."
        case .saving:
            return "Finalizing the recording and verifying the archive copy."
        case .attentionNeeded:
            return liveAttentionEvents.first?.body ?? "Protection needs attention."
        }
    }

    var cockpitSymbolName: String {
        switch liveOperationalState.primaryDisplay {
        case .noSource: return "shield"
        case .detected: return "shield.lefthalf.filled"
        case .ready: return "checkmark.shield"
        case .armed, .setProtected: return "bolt.shield"
        case .capturing: return "record.circle.fill"
        case .saving: return "arrow.down.circle.fill"
        case .attentionNeeded: return "exclamationmark.triangle.fill"
        }
    }

    var liveSourceDisplayName: String? {
        if let app = captureState.selectedTargetApp?.software.displayName {
            return app
        }
        if let device = captureState.selectedDevice?.name {
            return device
        }
        if let running = probeResults.first(where: { !$0.runningApplicationBundleIdentifiers.isEmpty }) {
            return running.software.displayName
        }
        return nil
    }

    var liveArmedSinceText: String? {
        guard let armedSince else { return nil }
        return Self.liveTimeFormatter.string(from: armedSince)
    }

    var liveLastProtectedFooterText: String? {
        guard let summary = librarySummaries.max(by: { $0.archive.detectedAt < $1.archive.detectedAt }) else {
            return nil
        }
        let date = Self.liveDateFooterFormatter.string(from: summary.archive.detectedAt)
        let time = Self.liveTimeFormatter.string(from: summary.archive.detectedAt)
        return "Last: \(date) · \(time)"
    }

    var liveProtectedToastText: String {
        if let session = lastCaptureSession {
            let name = session.originalFilename
            let duration = session.durationSeconds.map { formattedDuration($0) } ?? "—"
            return "Set protected — \(name) · \(duration)"
        }
        return "Set protected"
    }

    var liveProtectionReceipt: ProtectionReceipt? {
        guard let session = lastCaptureSession else { return nil }
        return ProtectionReceipt(
            filename: session.originalFilename,
            archivePath: session.archivePath,
            durationText: session.durationSeconds.map { formattedDuration($0) } ?? "Duration unavailable",
            sizeText: ByteCountFormatter.string(fromByteCount: session.fileSize, countStyle: .file)
        )
    }

    /// Performs operational checks only on explicit refresh/state transitions, never meter ticks.
    private func buildLiveAttentionEvents() -> [AttentionEvent] {
        var events: [AttentionEvent] = []

        if case .needsScreenRecordingPermission = captureState.phase {
            events.append(.screenRecordingDenied())
        }

        for access in unreachableRecordingAccesses() {
            let name = displayName(for: access.appID)
            if let relocated = relocatedRecordingFolderURL(for: access) {
                events.append(.folderMoved(
                    appID: access.appID,
                    fromPath: access.url.path,
                    toPath: relocated.path
                ))
            } else {
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: access.url.path, isDirectory: &isDir) {
                    events.append(.permissionDenied(appID: access.appID, path: access.url.path))
                } else {
                    events.append(.folderMissing(appID: access.appID, appName: name, path: access.url.path))
                }
            }
        }

        if let disk = diskFullAttentionEvent() {
            events.append(disk)
        }

        if captureState.listeningState == .recoveryNeeded,
           captureState.phase == .watching || captureState.phase == .recording {
            let name = liveSourceDisplayName ?? "Capture source"
            events.append(.sourceUnreadable(sourceName: name))
        }

        if case .failed(let reason) = captureState.phase {
            let lower = reason.lowercased()
            if lower.contains("not responding") || lower.contains("stream stopped") || lower.contains("disconnected") {
                events.append(.sourceUnreadable(sourceName: liveSourceDisplayName ?? "Capture source"))
            } else {
                events.append(.saveFailed(
                    reason: reason,
                    temporaryRecordingRetained: recoverableStagingURL != nil
                ))
            }
        }

        return events.sorted { $0.kind.recoveryPriority < $1.kind.recoveryPriority }
    }

    var captureStagingSizeText: String? {
        guard let bytes = captureStagingBytes, bytes > 0 else { return nil }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func diskFullAttentionEvent() -> AttentionEvent? {
        let url = resolvedArchiveRoot()
        guard let capacity = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            .volumeAvailableCapacityForImportantUsage
        else { return nil }
        let gib = Double(capacity) / 1_073_741_824
        guard gib < 2 else { return nil }
        return .diskFull(remainingGigabytes: max(0, gib))
    }

    /// When the configured folder is unreachable, prefer a probe-discovered recordings path
    /// for the same app that still exists — treats that as a moved folder (dispatch-04).
    private func relocatedRecordingFolderURL(for access: FolderAccess) -> URL? {
        guard access.kind == .recordings else { return nil }
        let configuredPath = access.url.standardizedFileURL.path
        let candidates = probeResults
            .first { $0.software.id == access.appID }?
            .existingRecordingURLs ?? []
        for candidate in candidates {
            let path = candidate.standardizedFileURL.path
            guard path != configuredPath else { continue }
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
                continue
            }
            return candidate
        }
        return nil
    }

    /// Accept a probe-discovered relocated recordings folder (folderMoved primary action).
    func acceptRelocatedRecordingFolder(appID: String, newURL: URL) {
        do {
            let bookmark = try folderAccessStore.makeBookmarkData(for: newURL)
            let access = FolderAccess(appID: appID, kind: .recordings, url: newURL, bookmarkData: bookmark)
            try folderAccessStore.save(access)
            refresh()
            statusMessage = "Recording folder updated for \(displayName(for: appID))"
            appendActivity(
                kind: .scan,
                message: "Accepted relocated recordings folder",
                detail: "\(appID) → \(newURL.path)"
            )
        } catch {
            statusMessage = "Could not update folder: \(error.localizedDescription)"
        }
    }

    func dismissProtectedToast() {
        justSavedUntil = nil
        savedFlashTask?.cancel()
        savedFlashTask = nil
    }

    private func stagePendingCaptureRecovery(
        _ result: CaptureResult,
        sourceAppID: String,
        route: CaptureArchiveRoute,
        backend: CaptureArchiveBackend?,
        transport: String?
    ) {
        pendingCaptureRecovery = PendingCaptureRecovery(
            result: result,
            sourceAppID: sourceAppID,
            captureRoute: route,
            captureBackend: backend,
            captureDeviceTransport: transport
        )
        recoverableStagingURL = result.stagingURL
        let record = PendingCaptureRecoveryRecord(
            stagingURL: result.stagingURL,
            deviceID: result.deviceID,
            deviceName: result.deviceName,
            startedAt: result.startedAt,
            endedAt: result.endedAt,
            sourceAppID: sourceAppID,
            captureRoute: route,
            captureBackend: backend,
            captureDeviceTransport: transport,
            captureInterrupted: result.captureInterrupted,
            captureInterruptionReason: result.captureInterruptionReason
        )
        do {
            try pendingCaptureRecoveryStore.save(record)
        } catch {
            appendActivity(
                kind: .diagnostics,
                message: "Could not persist temporary recording recovery",
                detail: error.localizedDescription
            )
        }
    }

    private func restorePendingCaptureRecovery() {
        guard let record = try? pendingCaptureRecoveryStore.load() else { return }
        let result = CaptureResult(
            stagingURL: record.stagingURL,
            deviceID: record.deviceID,
            deviceName: record.deviceName,
            startedAt: record.startedAt,
            endedAt: record.endedAt,
            captureRoute: record.captureRoute,
            captureBackend: record.captureBackend,
            captureInterrupted: record.captureInterrupted,
            captureInterruptionReason: record.captureInterruptionReason
        )
        pendingCaptureRecovery = PendingCaptureRecovery(
            result: result,
            sourceAppID: record.sourceAppID,
            captureRoute: record.captureRoute,
            captureBackend: record.captureBackend,
            captureDeviceTransport: record.captureDeviceTransport
        )
        recoverableStagingURL = record.stagingURL
        lastCaptureOutcome = .failed("A temporary recording is waiting to be saved.")
    }

    private func ingestPendingCaptureRecovery() throws -> RecordingSession {
        guard let pending = pendingCaptureRecovery else {
            throw CaptureServiceError.engineFailed("No temporary capture is available to recover.")
        }
        let result = pending.result
        let session = try archiveService().ingestCapture(
            stagingURL: result.stagingURL,
            deviceID: result.deviceID,
            deviceName: result.deviceName,
            startedAt: result.startedAt,
            endedAt: result.endedAt,
            sourceAppID: pending.sourceAppID,
            captureRoute: pending.captureRoute,
            captureBackend: pending.captureBackend,
            captureDeviceTransport: pending.captureDeviceTransport,
            captureInterrupted: result.captureInterrupted,
            captureInterruptionReason: result.captureInterruptionReason
        )
        pendingCaptureRecovery = nil
        recoverableStagingURL = nil
        try? pendingCaptureRecoveryStore.remove()
        return session
    }

    func retryPendingCaptureSave() {
        guard pendingCaptureRecovery != nil else {
            statusMessage = "No temporary recording is waiting to be saved"
            return
        }
        do {
            let session = try ingestPendingCaptureRecovery()
            notifyForNewArchive(session)
            refresh()
            autopullTracklist(for: session)
            lastCaptureOutcome = .success(sessionID: session.id)
            statusMessage = "Temporary recording saved to the archive"
        } catch {
            lastCaptureOutcome = .failed(error.localizedDescription)
            statusMessage = "Could not save temporary recording: \(error.localizedDescription)"
            refreshOperationalAttention()
        }
    }

    func savePendingCaptureElsewhere() {
        guard let source = recoverableStagingURL else {
            statusMessage = "No temporary recording is available"
            return
        }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = source.lastPathComponent
        panel.allowedContentTypes = [.wav]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                throw CocoaError(.fileWriteFileExists)
            }
            try FileManager.default.copyItem(at: source, to: destination)
            NSWorkspace.shared.activateFileViewerSelecting([destination])
            statusMessage = "Temporary recording copied to \(destination.lastPathComponent)"
        } catch {
            statusMessage = "Could not copy temporary recording: \(error.localizedDescription)"
        }
    }

    func revealPendingCapture() {
        guard let url = recoverableStagingURL else {
            statusMessage = "No temporary recording is available"
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func handleLiveRecoveryPrimary(_ event: AttentionEvent) {
        switch event.kind {
        case .folderMoved:
            if let appID = event.relatedAppID, let path = event.relatedPath {
                acceptRelocatedRecordingFolder(appID: appID, newURL: URL(fileURLWithPath: path, isDirectory: true))
                openMainWindow()
            } else if let appID = event.relatedAppID {
                chooseFolder(appID: appID, kind: .recordings)
            }
        case .folderMissing, .permissionDenied:
            if let appID = event.relatedAppID {
                chooseFolder(appID: appID, kind: .recordings)
            } else {
                selectedRoute = .protection
                openMainWindow()
            }
        case .screenRecording:
            openScreenRecordingPrivacySettings()
        case .diskFull:
            if let url = URL(string: "x-apple.systempreferences:com.apple.settings.Storage") {
                NSWorkspace.shared.open(url)
            } else {
                selectedRoute = .settings
                openMainWindow()
            }
        case .saveFailed:
            if recoverableStagingURL != nil {
                retryPendingCaptureSave()
            } else {
                selectedRoute = .home
                openMainWindow()
            }
        case .sourceUnreadable:
            selectedRoute = .capture
            openMainWindow()
            if captureState.mode == .appAudio {
                armAppAudioCapture()
            } else {
                armInputCaptureWatching()
            }
        }
    }

    func handleLiveRecoverySecondary(_ event: AttentionEvent, title: String) {
        switch event.kind {
        case .screenRecording where title == "Retry":
            armAppAudioCapture()
        case .saveFailed where title == "Save Elsewhere…":
            savePendingCaptureElsewhere()
        case .saveFailed where title == "Reveal Temporary Recording":
            revealPendingCapture()
        case .saveFailed where title == "Open Archive Folder":
            openArchiveFolder()
        case .diskFull where title == "Open Archive Folder":
            openArchiveFolder()
        case .sourceUnreadable where title == "Open Capture":
            selectedRoute = .capture
            openMainWindow()
        case .permissionDenied where title == "Open System Settings":
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders") {
                NSWorkspace.shared.open(url)
            }
        case .folderMoved where title.hasPrefix("Choose"),
             .permissionDenied where title.hasPrefix("Grant") || title.hasPrefix("Choose"):
            if let appID = event.relatedAppID {
                chooseFolder(appID: appID, kind: .recordings)
            }
        case .folderMoved, .folderMissing, .permissionDenied:
            if let appID = event.relatedAppID {
                selectedRoute = .recovery(appID)
            }
            openMainWindow()
        default:
            selectedRoute = .home
            openMainWindow()
        }
    }

    private static let liveTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    private static let liveDateFooterFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return f
    }()

    var previousCaptureSummary: String? {
        guard let outcome = lastCaptureOutcome else { return nil }
        switch outcome {
        case .failed(let reason):
            return "Last capture failed: \(reason)"
        case .success(let sessionID):
            guard let session = sessions.first(where: { $0.id == sessionID }) else {
                return "Last capture saved"
            }
            let name = displayName(for: session.sourceAppID)
            if let duration = session.durationSeconds {
                return "Last capture: \(name), \(formattedDuration(duration)) — saved"
            }
            return "Last capture: \(name) — saved"
        }
    }

    var lastCaptureIsFailure: Bool {
        if case .failed = lastCaptureOutcome { return true }
        return false
    }

    var lastCaptureSession: ArchiveMetadata? {
        guard case .success(let sessionID) = lastCaptureOutcome else { return nil }
        return sessions.first { $0.id == sessionID }
    }

    private func formattedDuration(_ seconds: Double) -> String {
        let total = Int(seconds)
        let minutes = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    private func handleCaptureStateChange(from oldValue: CaptureUIState) {
        if captureState.phase == .recording, oldValue.phase != .recording {
            recordingStartedAt = Date()
        } else if captureState.phase != .recording {
            recordingStartedAt = nil
        }

        switch captureState.phase {
        case .watching, .armed:
            if oldValue.phase != .watching, oldValue.phase != .armed {
                armedSince = Date()
            }
        default:
            if oldValue.phase == .watching || oldValue.phase == .armed {
                armedSince = nil
            }
        }

        if oldValue.phase != captureState.phase {
            captureIdleSleepGuard.sync(shouldHold: captureState.phase.shouldPreventIdleSleep)
            if case .recording = captureState.phase {
                // Spec: new capture during toast dismisses toast immediately.
                dismissProtectedToast()
            }
        }

        if case .failed(let reason) = captureState.phase, oldValue.phase != captureState.phase {
            lastCaptureOutcome = .failed(reason)
        }

        if let newID = captureState.lastArchivedSessionID, newID != oldValue.lastArchivedSessionID {
            lastCaptureOutcome = .success(sessionID: newID)
            triggerSavedFlash()
        }

        let attentionInputsChanged = oldValue.phase != captureState.phase
            || oldValue.listeningState != captureState.listeningState
            || oldValue.selectedDeviceID != captureState.selectedDeviceID
            || oldValue.selectedTargetApp != captureState.selectedTargetApp
        if attentionInputsChanged {
            refreshOperationalAttention()
        }
        noteMenuBarPresentationChanged()
    }

    private func triggerSavedFlash() {
        // Spec: if app is backgrounded, queue toast and show on return only if < 30s old.
        if !NSApp.isActive {
            queuedProtectedToastAt = Date()
            justSavedUntil = nil
        } else {
            queuedProtectedToastAt = nil
            justSavedUntil = Date().addingTimeInterval(Self.savedFlashDuration)
        }
        if settings.notifyAfterArchiving {
            let name = lastCaptureSession?.originalFilename ?? "Set"
            let duration = lastCaptureSession?.durationSeconds.map { formattedDuration($0) } ?? "—"
            notificationService.notifySetProtected(setName: name, durationText: duration)
        }
        savedFlashTask?.cancel()
        savedFlashTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Self.savedFlashDuration * 1_000_000_000))
            await MainActor.run {
                guard let self, let until = self.justSavedUntil, Date() >= until else { return }
                self.justSavedUntil = nil
            }
        }
    }

    /// Flush a queued protected toast when the app returns to the foreground.
    func handleAppBecameActive() {
        guard let queued = queuedProtectedToastAt else { return }
        queuedProtectedToastAt = nil
        let age = Date().timeIntervalSince(queued)
        guard age < Self.queuedToastMaxAge else { return }
        justSavedUntil = Date().addingTimeInterval(Self.savedFlashDuration)
        savedFlashTask?.cancel()
        savedFlashTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Self.savedFlashDuration * 1_000_000_000))
            await MainActor.run {
                guard let self, let until = self.justSavedUntil, Date() >= until else { return }
                self.justSavedUntil = nil
            }
        }
    }

    func refreshCaptureStagingBytes() {
        guard captureState.phase == .recording else {
            if captureStagingBytes != nil { captureStagingBytes = nil }
            return
        }
        let bytes: Int64?
        if captureState.mode == .appAudio {
            bytes = appAudioCaptureService.currentStagingByteCount()
        } else {
            bytes = captureService.currentStagingByteCount()
        }
        if bytes != captureStagingBytes {
            captureStagingBytes = bytes
        }
    }

    private func syncAttentionNotifications() {
        let events = liveAttentionEvents
        let activeIDs = Set(events.map(\.id))
        for id in notifiedAttentionIDs.subtracting(activeIDs) {
            notificationService.clearAttentionNotification(id: id)
        }
        for event in events where !notifiedAttentionIDs.contains(event.id) {
            notificationService.notifyAttentionNeeded(event)
        }
        notifiedAttentionIDs = activeIDs
        noteMenuBarPresentationChanged()
    }

    private func refreshOperationalAttention() {
        let events = buildLiveAttentionEvents()
        if events != liveAttentionEvents {
            liveAttentionEvents = events
        }
        syncAttentionNotifications()
    }

    /// SwiftUI's `openWindow` action, registered from the WindowGroup's content on appear.
    /// Lets non-View code (menu bar actions, the menuBarOnly toggle) instantiate the
    /// WindowGroup window on demand instead of relying on one already existing in `NSApp.windows`.
    var requestOpenMainWindow: (() -> Void)?

    func openMainWindow() {
        NSApp.setActivationPolicy(.regular)
        Self.activateApp()
        // If a WindowGroup window already exists (the common case after launch), just bring
        // it front — avoids spawning a duplicate. Otherwise ask SwiftUI to create one; with a
        // MenuBarExtra present the window is created lazily and may not exist yet.
        if let window = NSApp.windows.first(where: { $0.canBecomeKey }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            requestOpenMainWindow?()
        }
    }

    static func activateApp() {
        NSApp.activate()
    }

    func viewLastCaptureInMainWindow() {
        guard let session = lastCaptureSession else { return }
        openMainWindow()
        openLibrary(sessionID: session.id)
    }

    func viewLastCaptureInFinder() {
        guard let session = lastCaptureSession else { return }
        let url = URL(fileURLWithPath: session.archivePath)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func updateMenuBarOnly(enabled: Bool) {
        updateAppPresentationMode(enabled ? .menuBarOnly : .menuBarAndMainWindow)
    }

    func updateAppPresentationMode(_ mode: AppPresentationMode) {
        let previous = settings.appPresentationMode
        guard mode != previous else { return }
        saveSettings(settings.updating(appPresentationMode: mode))
        applyAppPresentationMode(mode)
    }

    /// Applies Dock / accessory policy and window visibility for the chosen presentation mode.
    func applyAppPresentationMode(_ mode: AppPresentationMode) {
        if mode.usesAccessoryActivationPolicy {
            NSApp.setActivationPolicy(.accessory)
            NSApp.windows
                .filter { $0.canBecomeMain }
                .forEach { $0.orderOut(nil) }
        } else {
            NSApp.setActivationPolicy(.regular)
            if mode.opensMainWindowAtLaunch {
                openMainWindow()
            }
        }
    }

    func updateShowFolderScanDetailsInMenuBar(enabled: Bool) {
        saveSettings(settings.updating(showFolderScanDetailsInMenuBar: enabled))
    }

    var lastScanDisplayText: String {
        guard let lastScanDate else {
            return "Not yet"
        }

        return lastScanDate.formatted(date: .omitted, time: .shortened)
    }

    var nextScanDisplayText: String {
        guard settings.automaticScanningEnabled else {
            return "Off"
        }

        if isScanning {
            return "Scanning now"
        }

        if isFolderChangeScanPending {
            return "Soon"
        }

        guard let nextScanDate else {
            return "Pending"
        }

        return nextScanDate.formatted(date: .omitted, time: .shortened)
    }

    var scanScheduleDisplayText: String {
        if settings.automaticScanningEnabled {
            return "Every \(settings.scanIntervalSeconds) seconds"
        }

        return "Automatic scanning is off"
    }

    func refresh() {
        probeResults = probe.probeAll()
        folderAccesses = (try? folderAccessStore.all()) ?? []
        settings = (try? appSettingsStore.load()) ?? .default
        ensureArchiveRootExists()
        sessions = (try? sessionLibrary().archivedMetadata()) ?? []
        importedTracklists = Dictionary(
            grouping: (try? importedTracklistStore.all()) ?? [],
            by: \.appID
        ).mapValues { $0.sorted { $0.importedAt > $1.importedAt } }
        setContexts = Dictionary(
            uniqueKeysWithValues: ((try? setContextStore.all()) ?? []).map { ($0.sessionID, $0) }
        )
        librarySummaries = LibrarySessionMatcher().summaries(
            archives: sessions,
            importedTracklists: importedTracklists.values.flatMap { $0 },
            setContexts: Array(setContexts.values)
        )
        activityEvents = (try? activityLogStore.all()) ?? []
        profile = (try? profileStore.load()) ?? DJProfile()
        reconcileLaunchAtLogin()

        if protectedAdapterCount > 0 {
            statusMessage = "\(protectedAdapterCount) source\(protectedAdapterCount == 1 ? "" : "s") ready"
        } else {
            statusMessage = "Choose recording folders to start protecting sets"
        }

        restartFolderChangeMonitoring()
        restartHistoryMonitoring()
        refreshOperationalAttention()
    }

    /// Configured (user-granted) recordings folders plus probe-discovered defaults for setup hints.
    func recordingFolders(for appID: String) -> [URL] {
        let configured = configuredRecordingFolders(for: appID)
        let configuredPaths = Set(configured.map(\.path))
        let discovered = (probeResults.first { $0.software.id == appID }?.existingRecordingURLs ?? [])
            .filter { !configuredPaths.contains($0.path) }

        return configured + discovered
    }

    /// User-granted recordings folders only — source of truth for Ready / Watching / scanning.
    func configuredRecordingFolders(for appID: String) -> [URL] {
        folderAccesses
            .filter { $0.appID == appID && $0.kind == .recordings }
            .map { folderAccessStore.resolve($0) }
    }

    /// User-chosen recordings folder via security-scoped `FolderAccess` (HANDOFF-2 §4.10).
    /// Analog Mixer also counts as configured when a rec-out is pinned.
    func hasConfiguredRecordingsFolder(appID: String) -> Bool {
        let hasDump = folderAccesses.contains { $0.appID == appID && $0.kind == .recordings }
        if appID == SupportedDJSoftware.analogMixerAppID {
            return AnalogMixerPolicy.isConfigured(
                pinnedDeviceID: settings.pinnedAnalogInputDeviceID,
                hasDumpFolder: hasDump
            )
        }
        return hasDump
    }

    var hasPinnedAnalogRecOut: Bool {
        if let id = settings.pinnedAnalogInputDeviceID, !id.isEmpty { return true }
        return false
    }

    /// True while Choose rec-out is waiting for the DJ to pick an Input device in Capture.
    var pendingAnalogRecOutPinning: Bool { pendingAnalogRecOutPin }

    var pinnedAnalogInputDevice: AudioInputDevice? {
        guard let id = settings.pinnedAnalogInputDeviceID else { return nil }
        return captureState.devices.first { $0.id == id }
            ?? AudioInputDeviceCatalog.listInputs().first { $0.id == id }
    }

    var hasAnyRecordingsFolderAccess: Bool {
        folderAccesses.contains { $0.kind == .recordings }
    }

    func recordingsAccess(appID: String) -> FolderAccess? {
        folderAccesses.first { $0.appID == appID && $0.kind == .recordings }
    }

    var configuredRecordingsCount: Int {
        folderAccesses.filter { $0.kind == .recordings }.count
    }

    var installedOrRunningProbeCount: Int {
        probeResults.filter { !$0.installedApplicationURLs.isEmpty || $0.isRunning }.count
    }

    var configuredProbeResults: [SoftwareProbeResult] {
        probeResults.filter { hasConfiguredRecordingsFolder(appID: $0.software.id) }
    }

    var unconfiguredProbeResults: [SoftwareProbeResult] {
        probeResults.filter {
            $0.software.id != SupportedDJSoftware.captureAppID
                && !hasConfiguredRecordingsFolder(appID: $0.software.id)
        }
    }

    /// Configured recordings folder exists but none of its resolved URLs are reachable.
    func isConfiguredRecordingsFolderUnreachable(appID: String) -> Bool {
        let configuredURLs = folderAccesses
            .filter { $0.appID == appID && $0.kind == .recordings }
            .map { folderAccessStore.resolve($0) }

        guard !configuredURLs.isEmpty else {
            return false
        }

        return !configuredURLs.contains(where: isReachableDirectory(_:))
    }

    func isFolderAccessReachable(_ access: FolderAccess) -> Bool {
        folderAccessStore.isReachable(access)
    }

    func unreachableRecordingAccesses() -> [FolderAccess] {
        folderAccesses.filter { $0.kind == .recordings && !folderAccessStore.isReachable($0) }
    }

    func reachableRecordingFolders(for appID: String) -> [URL] {
        configuredRecordingFolders(for: appID).filter(isReachableDirectory(_:))
    }

    /// Preview / test helper — does not persist. Seeds `FolderAccess` rows for sidebar matrix previews.
    func previewApplyConfiguredRecordingsFolders(
        reachableAppIDs: [String],
        unreachableAppIDs: [String] = []
    ) {
        var accesses: [FolderAccess] = []

        for appID in reachableAppIDs {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("setcatcher-preview-\(appID)", isDirectory: true)
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            accesses.append(
                FolderAccess(appID: appID, kind: .recordings, url: url, bookmarkData: nil)
            )
        }

        for appID in unreachableAppIDs {
            let url = URL(fileURLWithPath: "/Volumes/MissingDrive-\(appID)/Recordings", isDirectory: true)
            accesses.append(
                FolderAccess(appID: appID, kind: .recordings, url: url, bookmarkData: nil)
            )
        }

        folderAccesses = accesses
    }

    /// Preview / test helper — does not persist.
    func previewSetScanning(_ scanning: Bool) {
        isScanning = scanning
    }

    /// Preview / test helper — does not persist.
    func previewApplyProfile(_ profile: DJProfile) {
        self.profile = profile
        suppressProfilePersistence = true
    }

    /// Preview / test helper — forces greeting hour without waiting for wall clock.
    func previewApplyNow(_ date: Date?) {
        previewNow = date
    }

    /// Preview / test helper — does not persist. Seeds library surfaces for Home / Library / Activity.
    func previewApplyLibrary(
        archives: [ArchiveMetadata] = [],
        summaries: [LibrarySessionSummary] = [],
        activity: [ActivityEvent] = [],
        imported: [ImportedTracklist] = [],
        contexts: [SetContext] = []
    ) {
        sessions = archives
        librarySummaries = summaries.isEmpty
            ? archives.map { LibrarySessionSummary(archive: $0, matchedTracklist: nil) }
            : summaries
        activityEvents = activity
        importedTracklists = Dictionary(grouping: imported, by: \.appID)
        setContexts = Dictionary(uniqueKeysWithValues: contexts.map { ($0.sessionID, $0) })
    }

    func historyFolders(for appID: String) -> [URL] {
        let configured = folderAccesses
            .filter { $0.appID == appID && $0.kind == .history }
            .map { folderAccessStore.resolve($0) }

        let discovered = probeResults
            .first { $0.software.id == appID }?
            .existingHistoryURLs ?? []

        return configured + discovered
    }

    func chooseFolder(appID: String, kind: FolderKind) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        panel.title = kind == .recordings ? "Set Recording Folder" : "Set History Folder"
        panel.message = kind == .recordings
            ? recordingsFolderPanelMessage(appID: appID)
            : "Choose the folder where this DJ app saves history or exports."
        panel.directoryURL = defaultFolderPanelURL(appID: appID, kind: kind)

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            let bookmark = try folderAccessStore.makeBookmarkData(for: url)
            let access = FolderAccess(appID: appID, kind: kind, url: url, bookmarkData: bookmark)
            try folderAccessStore.save(access)
            refresh()
            statusMessage = "Saved \(kind.displayName.lowercased()) folder for \(displayName(for: appID))"
        } catch {
            appendActivity(kind: .error, message: "Folder access save failed", detail: error.localizedDescription)
            statusMessage = "Could not save folder access: \(error.localizedDescription)"
        }
    }

    private func recordingsFolderPanelMessage(appID: String) -> String {
        switch appID {
        case SupportedDJSoftware.pioneerHardwareAppID:
            return "Choose the USB stick or PIONEERREC folder where MASTER REC writes RECxxx.WAV files."
        case SupportedDJSoftware.denonHardwareAppID:
            return "Choose the USB/SD Sessions folder where Engine OS writes set recordings."
        case SupportedDJSoftware.analogMixerAppID:
            return "Choose the dump folder on your recorder or USB stick. SetCatcher copies files and leaves the originals unchanged."
        case SupportedDJSoftware.raneHardwareAppID:
            return "Optional: choose a dump folder if you record outside Serato. Serato users should grant Serato’s Recording folder instead."
        default:
            return "Choose the folder where this DJ app saves recordings."
        }
    }

    func pinAnalogRecOut(deviceID: String) {
        pendingAnalogRecOutPin = false
        let newSettings = settings.updating(
            lastCaptureDeviceID: .some(deviceID),
            captureMode: .inputDevice,
            pinnedAnalogInputDeviceID: .some(deviceID)
        )
        do {
            try appSettingsStore.save(newSettings)
            settings = newSettings
        } catch {
            statusMessage = "Could not save pinned rec-out: \(error.localizedDescription)"
            return
        }
        selectCaptureDevice(deviceID)
        var next = captureState
        next.mode = .inputDevice
        if next.phase == .idle {
            next.phase = .armed
        }
        next.statusMessage = AnalogMixerPolicy.listeningSummary(
            deviceName: next.devices.first { $0.id == deviceID }?.name ?? "rec-out"
        )
        captureState = next
        userDisarmedInputCapture = false
        applyAnalogPinUnattendedWatch()
        statusMessage = "Pinned rec-out. Recording starts when audio is detected; idle silence saves the take."
        refresh()
    }

    func clearAnalogRecOutPin() {
        let newSettings = settings.updating(pinnedAnalogInputDeviceID: .some(nil))
        do {
            try appSettingsStore.save(newSettings)
            settings = newSettings
        } catch {
            statusMessage = "Could not clear pinned rec-out: \(error.localizedDescription)"
            return
        }
        statusMessage = AnalogMixerPolicy.needsSetupMessage
        refresh()
    }

    /// Presents the input-device picker flow for Analog Mixer Choose rec-out.
    func beginChooseAnalogRecOut() {
        pendingAnalogRecOutPin = true
        refreshAudioInputs()
        var next = captureState
        next.mode = .inputDevice
        next.phase = captureState.devices.isEmpty ? .idle : .armed
        next.statusMessage = "Choose the mixer REC OUT / SESSION OUT input, then pin it."
        captureState = next
        selectedRoute = .capture
    }

    func clearFolder(appID: String, kind: FolderKind) {
        do {
            try folderAccessStore.remove(appID: appID, kind: kind)
            refresh()
        } catch {
            statusMessage = "Could not remove folder access: \(error.localizedDescription)"
        }
    }

    func importHistory(appID: String) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [
            .commaSeparatedText,
            .tabSeparatedText,
            .plainText,
            .xml,
            UTType(filenameExtension: "nml") ?? .xml,
            UTType(filenameExtension: "m3u") ?? .plainText,
            UTType(filenameExtension: "m3u8") ?? .plainText,
            UTType(filenameExtension: "vdjfolder") ?? .xml
        ]
        panel.prompt = "Import"
        panel.message = "Choose a history export or tracklist file."

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let parser = TracklistAutopull.parser(forHistoryAppID: appID)
            let tracks = try parser.parse(data: data, sourceName: url.lastPathComponent)
            let importedTracklist = ImportedTracklist(
                appID: appID,
                sourceURL: url,
                kind: TracklistAutopull.tracklistKind(appID: appID, sourceURL: url),
                tracks: tracks
            )
            try importedTracklistStore.save(importedTracklist)
            try activityLogStore.append(ActivityEvent(
                kind: .importTracklist,
                message: "Imported \(tracks.count) tracks",
                detail: url.lastPathComponent
            ))
            refresh()
            statusMessage = "Imported \(tracks.count) track\(tracks.count == 1 ? "" : "s") from \(url.lastPathComponent)"
        } catch {
            appendActivity(kind: .error, message: "History import failed", detail: error.localizedDescription)
            statusMessage = "Could not import history: \(error.localizedDescription)"
        }
    }

    func deleteImportedTracklist(id: UUID) {
        do {
            try importedTracklistStore.remove(id: id)
            try activityLogStore.append(ActivityEvent(kind: .importTracklist, message: "Deleted imported tracklist"))
            refresh()
        } catch {
            appendActivity(kind: .error, message: "Delete import failed", detail: error.localizedDescription)
            statusMessage = "Could not delete import: \(error.localizedDescription)"
        }
    }

    func saveSetContext(_ context: SetContext) {
        do {
            try setContextStore.save(context)
            try activityLogStore.append(ActivityEvent(
                kind: .scan,
                message: "Updated set details",
                detail: context.eventName.isEmpty ? nil : context.eventName
            ))
            refresh()
            statusMessage = "Set details saved"
        } catch {
            appendActivity(kind: .error, message: "Set details save failed", detail: error.localizedDescription)
            statusMessage = "Could not save set details: \(error.localizedDescription)"
        }
    }

    func attachTracklist(sessionID: UUID, tracklistID: UUID?) {
        do {
            var context = try setContextStore.context(for: sessionID)
            context.manualTracklistID = tracklistID
            try setContextStore.save(context)
            if let tracklistID,
               let archive = sessions.first(where: { $0.id == sessionID }),
               let tracklist = allImportedTracklists.first(where: { $0.id == tracklistID })
            {
                let stamped = tracklist.stampingPlayedOn(Calendar.current.startOfDay(for: archive.detectedAt))
                try importedTracklistStore.save(stamped)
            }
            try activityLogStore.append(ActivityEvent(
                kind: .importTracklist,
                message: tracklistID == nil ? "Detached tracklist" : "Attached tracklist"
            ))
            refresh()
            statusMessage = tracklistID == nil ? "Tracklist detached" : "Tracklist attached"
        } catch {
            appendActivity(kind: .error, message: "Tracklist attachment failed", detail: error.localizedDescription)
            statusMessage = "Could not update tracklist match: \(error.localizedDescription)"
        }
    }

    func scanNow() {
        guard !isScanning else { return }

        isScanning = true
        isFolderChangeScanPending = false
        nextScanDate = nil
        let requests = scanRequests()
        let coordinator = scanCoordinator()

        Task {
            let results = await Task.detached(priority: .userInitiated) {
                coordinator.scanRecent(requests: requests)
            }.value

            await MainActor.run {
                lastScanResults = results
                lastScanDate = Date()
                isScanning = false
                appendScanActivity(results)
                refresh()
                scheduleNextScanIfNeeded()
                statusMessage = scanStatusMessage(for: results)
                let archived = results.flatMap(\.archivedSessions)
                for session in archived {
                    autopullTracklist(for: session)
                }
                // Backstop: every periodic scan also re-sweeps history folders so
                // exports that FSEvents missed (machine asleep, coalesced events,
                // network volumes) still get ingested and matched.
                ingestHistoryNow()
            }
        }
    }

    func checkVirtualDJNetworkControl() {
        guard !isCheckingVirtualDJNetwork else { return }

        isCheckingVirtualDJNetwork = true
        statusMessage = "Checking VirtualDJ Network Control"

        Task {
            let result = await VirtualDJNetworkProbe().probe()

            await MainActor.run {
                virtualDJNetworkProbeResult = result
                isCheckingVirtualDJNetwork = false
                appendActivity(
                    kind: result.reachable ? .scan : .error,
                    message: result.reachable ? "VirtualDJ Network Control reachable" : "VirtualDJ Network Control not reachable",
                    detail: result.errorDescription ?? result.endpoint.absoluteString
                )
                statusMessage = result.reachable
                    ? "VirtualDJ Network Control is reachable"
                    : "VirtualDJ Network Control is not reachable"
            }
        }
    }

    func clearActivity() {
        do {
            try activityLogStore.clear()
            refresh()
        } catch {
            statusMessage = "Could not clear activity: \(error.localizedDescription)"
        }
    }

    func updateAutomaticScanning(enabled: Bool) {
        saveSettings(settings.updating(automaticScanningEnabled: enabled))
    }

    func updateScanInterval(seconds: Int) {
        saveSettings(settings.updating(scanIntervalSeconds: seconds))
    }

    func updateArchiveNamingTemplate(_ template: String) {
        saveSettings(settings.updating(archiveNamingTemplate: template))
    }

    func updateVerifyCopies(enabled: Bool) {
        saveSettings(settings.updating(verifyCopies: enabled))
    }

    func updateNotifyAfterArchiving(enabled: Bool) {
        saveSettings(settings.updating(notifyAfterArchiving: enabled))
    }

    func updateAutoArmOnDJAppFound(enabled: Bool) {
        let newSettings = settings.updating(autoArmOnDJAppFound: enabled)
        do {
            try appSettingsStore.save(newSettings)
            settings = newSettings
            if enabled {
                userDisarmedAppAudio = false
                statusMessage = "Auto-arm is on. App audio Capture will arm when a shareable DJ app is found."
                if captureState.mode == .appAudio, !captureState.isWatchingOrRecording {
                    Task { await refreshAppAudioTargets(attemptAutoArm: true) }
                }
            } else {
                statusMessage = "Auto-arm is off. Arm App audio Capture manually when you want it watching."
            }
        } catch {
            appendActivity(kind: .error, message: "Settings save failed", detail: error.localizedDescription)
            statusMessage = "Could not save settings: \(error.localizedDescription)"
        }
    }

    func updateDualRoutePosture(_ posture: DualRoutePosture) {
        saveSettings(settings.updating(dualRoutePosture: posture))
        userSuppressedPioneerAutoSwitch = false
        userDisarmedInputCapture = false
        statusMessage = posture.explanation
        refreshAudioInputs()
    }

    func updateLaunchAtLogin(enabled: Bool) {
        applyLaunchAtLogin(enabled: enabled, persistPreference: true)
    }

    /// Saves local DJ identity for Home. Blank strings become nil — never invent placeholders.
    func updateProfile(displayName: String, handle: String, city: String, residency: String) {
        var next = DJProfile(
            displayName: Self.nilIfBlank(displayName),
            handle: Self.nilIfBlank(handle),
            city: Self.nilIfBlank(city),
            residency: Self.nilIfBlank(residency),
            memberSince: profile.memberSince
        )

        let hasIdentity = next.displayName != nil
            || next.handle != nil
            || next.city != nil
            || next.residency != nil
        if hasIdentity, next.memberSince == nil {
            next.memberSince = Date()
        }
        if !hasIdentity {
            next.memberSince = nil
        }

        do {
            if !suppressProfilePersistence {
                try profileStore.save(next)
            }
            profile = next
            statusMessage = hasIdentity ? "Profile saved" : "Profile cleared"
        } catch {
            appendActivity(kind: .error, message: "Profile save failed", detail: error.localizedDescription)
            statusMessage = "Could not save profile: \(error.localizedDescription)"
        }
    }

    func openLoginItemsSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    func completeOnboarding(destination: Route = .protection) {
        saveSettings(settings.updating(hasCompletedOnboarding: true))
        selectedRoute = destination
        statusMessage = protectedAdapterCount > 0
            ? "\(protectedAdapterCount) source\(protectedAdapterCount == 1 ? "" : "s") ready"
            : "Choose recording folders to start protecting sets"
    }

    /// Compatibility shim for call sites that still pass a destination string tag.
    func completeOnboarding(destinationAppID: String) {
        completeOnboarding(destination: Self.route(fromLegacySelection: destinationAppID))
    }

    func showOnboardingAgain() {
        saveSettings(settings.updating(hasCompletedOnboarding: false))
        selectedRoute = .protection
    }

    static func route(fromLegacySelection id: String) -> Route {
        switch id {
        case "home":
            return .home
        case "protection":
            return .protection
        case "library":
            return .library
        case "activity":
            return .activity
        case "settings":
            return .settings
        default:
            return .app(id)
        }
    }

    func chooseArchiveFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        panel.title = "Set Archive Folder"
        panel.message = "Choose where SetCatcher stores protected recording copies."
        panel.directoryURL = archiveRoot

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            let bookmark = try folderAccessStore.makeBookmarkData(for: url)
            saveSettings(settings.updating(
                archiveRootPath: .some(url.path),
                archiveRootBookmarkData: .some(bookmark)
            ))
            refresh()
            statusMessage = "Archive folder set to \(url.lastPathComponent)"
        } catch {
            appendActivity(kind: .error, message: "Archive folder save failed", detail: error.localizedDescription)
            statusMessage = "Could not save archive folder: \(error.localizedDescription)"
        }
    }

    func resetArchiveFolder() {
        saveSettings(settings.updating(
            archiveRootPath: .some(nil),
            archiveRootBookmarkData: .some(nil)
        ))
        refresh()
        statusMessage = "Archive folder reset to ~/Music/SetCatcher"
    }

    func exportDiagnostics() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "SetCatcher-Diagnostics-\(diagnosticsTimestamp()).json"
        panel.message = "Save a diagnostics report with setup, archive, import, and recent activity counts."

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            let report = makeDiagnosticsReport()

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            encoder.dateEncodingStrategy = .iso8601

            try encoder.encode(report).write(to: url, options: .atomic)
            try activityLogStore.append(ActivityEvent(
                kind: .diagnostics,
                message: "Exported diagnostics",
                detail: url.path
            ))
            refresh()
            revealInFinder(url)
            statusMessage = "Diagnostics saved to \(url.lastPathComponent)"
        } catch {
            appendActivity(kind: .error, message: "Diagnostics export failed", detail: error.localizedDescription)
            statusMessage = "Could not export diagnostics: \(error.localizedDescription)"
        }
    }

    /// Optional account sync after Clerk sign-in. Never gates archive/scan/protection.
    func syncAccountSession(bearerToken: String?) async {
        guard let bearerToken, !bearerToken.isEmpty else {
            accountLicenseSummary = nil
            accountSyncMessage = nil
            return
        }

        isAccountSyncing = true
        defer { isAccountSyncing = false }

        do {
            let host = ProcessInfo.processInfo.hostName
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            let platformID = host.replacingOccurrences(of: " ", with: "-")
            _ = try await AccountAPIClient.registerDevice(
                bearerToken: bearerToken,
                deviceName: host.isEmpty ? "Mac" : host,
                appVersion: version,
                installChannel: "local",
                platformDeviceId: platformID.isEmpty ? UUID().uuidString : platformID
            )
            let license = try await AccountAPIClient.fetchLicense(bearerToken: bearerToken)
            accountLicenseSummary = "\(license.license.plan) · \(license.license.status)"
            accountSyncMessage = license.localFeatures.note
            statusMessage = "Account connected — local protection still works offline"
        } catch {
            // Offline / unreachable account server must not block local features.
            accountLicenseSummary = accountLicenseSummary ?? "Unavailable (local features full)"
            accountSyncMessage = "Could not reach the account server. Local protection is unchanged."
            statusMessage = "Account sync skipped: \(error.localizedDescription)"
        }
    }

    func clearAccountSessionState() {
        accountLicenseSummary = nil
        accountSyncMessage = nil
    }

    /// User-initiated metadata-only diagnostics upload. Never called from archive/scan paths.
    func uploadDiagnosticsToAccount(bearerToken: String) async {
        isAccountSyncing = true
        defer { isAccountSyncing = false }

        do {
            let report = makeDiagnosticsReport()
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(report)
            guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw AccountAPIClient.ClientError.decoding
            }
            let response = try await AccountAPIClient.uploadDiagnostics(
                bearerToken: bearerToken,
                metadata: object
            )
            try activityLogStore.append(ActivityEvent(
                kind: .diagnostics,
                message: "Uploaded diagnostics metadata",
                detail: response.upload.id
            ))
            refresh()
            accountSyncMessage = "Diagnostics metadata uploaded. Audio and tracklists were not sent."
            statusMessage = "Diagnostics metadata uploaded"
        } catch {
            appendActivity(kind: .error, message: "Diagnostics upload failed", detail: error.localizedDescription)
            accountSyncMessage = "Could not upload diagnostics: \(error.localizedDescription)"
            statusMessage = accountSyncMessage ?? "Diagnostics upload failed"
        }
    }

    func makeDiagnosticsReport() -> DiagnosticsReport {
        DiagnosticsReportBuilder().build(
            archiveRoot: archiveRoot,
            probeResults: probeResults,
            recordingFolders: { [weak self] appID in self?.recordingFolders(for: appID) ?? [] },
            historyFolders: { [weak self] appID in self?.historyFolders(for: appID) ?? [] },
            folderAccesses: folderAccesses,
            archives: sessions,
            importedTracklists: allImportedTracklists,
            activityEvents: activityEvents
        )
    }

    func scanResults(for appID: String) -> [FolderScanResult] {
        lastScanResults.filter { $0.appID == appID }
    }

    func setupState(for result: SoftwareProbeResult) -> AppSetupState {
        let configured = configuredRecordingFolders(for: result.software.id)
        let appNotInstalledOrRunning = !result.software.bundleIdentifiers.isEmpty
            && result.installedApplicationURLs.isEmpty
            && !result.isRunning

        let hasConfigured = hasConfiguredRecordingsFolder(appID: result.software.id)
        // Analog Mixer can be configured via pin alone (no dump folder). Treat pin as reachable.
        let foldersReachable: Bool
        if result.software.id == SupportedDJSoftware.analogMixerAppID,
           hasPinnedAnalogRecOut,
           configured.isEmpty {
            foldersReachable = true
        } else {
            foldersReachable = configured.contains(where: isReachableDirectory(_:))
        }

        return AppSetupState.derive(
            scanResults: scanResults(for: result.software.id),
            hasConfiguredRecordingsFolder: hasConfigured,
            configuredFoldersReachable: foldersReachable,
            appNotInstalledOrRunning: appNotInstalledOrRunning,
            isScanning: isScanning,
            hasRecentUnstableRecording: hasRecentUnstableRecording(for: result.software.id)
        )
    }

    func importedTracklists(for appID: String) -> [ImportedTracklist] {
        importedTracklists[appID] ?? []
    }

    func displayName(for appID: String) -> String {
        probeResults.first { $0.software.id == appID }?.software.displayName
            ?? SupportedDJSoftware.all.first { $0.id == appID }?.displayName
            ?? appID
    }

    var allImportedTracklists: [ImportedTracklist] {
        importedTracklists.values.flatMap { $0 }.sorted { $0.importedAt > $1.importedAt }
    }

    func revealInFinder(_ url: URL) {
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: url.path) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            NSWorkspace.shared.open(url.deletingLastPathComponent())
        }
    }

    func openArchiveFolder() {
        do {
            try archiveService().ensureArchiveRootExists()
            NSWorkspace.shared.open(archiveRoot)
        } catch {
            statusMessage = "Could not open archive folder: \(error.localizedDescription)"
        }
    }

    func togglePlayback(sessionID: UUID, url: URL) {
        do {
            if playbackState.sessionID != sessionID || audioPlaybackService.loadedURL != url {
                playbackProgressTask?.cancel()
                try audioPlaybackService.load(url: url)
                playbackState = PlaybackViewState(
                    sessionID: sessionID,
                    currentTime: audioPlaybackService.currentTime,
                    duration: audioPlaybackService.duration
                )
            }

            if audioPlaybackService.isPlaying {
                audioPlaybackService.pause()
                syncPlaybackState(isPlaying: false)
                playbackProgressTask?.cancel()
            } else {
                audioPlaybackService.play()
                syncPlaybackState(isPlaying: audioPlaybackService.isPlaying)
                startPlaybackProgressUpdates()
            }
        } catch {
            playbackProgressTask?.cancel()
            audioPlaybackService.stop()
            playbackState = PlaybackViewState(
                sessionID: sessionID,
                errorMessage: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            )
        }
    }

    func seekPlayback(sessionID: UUID, progress: Double) {
        guard playbackState.sessionID == sessionID, playbackState.duration > 0 else { return }
        audioPlaybackService.seek(to: playbackState.duration * min(1, max(0, progress)))
        syncPlaybackState(isPlaying: audioPlaybackService.isPlaying)
    }

    func stopPlayback(sessionID: UUID? = nil) {
        if let sessionID, playbackState.sessionID != sessionID { return }
        playbackProgressTask?.cancel()
        audioPlaybackService.stop()
        playbackState = PlaybackViewState()
    }

    private func startPlaybackProgressUpdates() {
        playbackProgressTask?.cancel()
        playbackProgressTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled, let self else { return }
                let isPlaying = self.audioPlaybackService.isPlaying
                self.syncPlaybackState(isPlaying: isPlaying)
                if !isPlaying { return }
            }
        }
    }

    private func syncPlaybackState(isPlaying: Bool) {
        guard let sessionID = playbackState.sessionID else { return }
        playbackState = PlaybackViewState(
            sessionID: sessionID,
            isPlaying: isPlaying,
            currentTime: audioPlaybackService.currentTime,
            duration: audioPlaybackService.duration
        )
    }

    private func startBackgroundScanning() {
        scanTask?.cancel()
        guard settings.automaticScanningEnabled else {
            scanTask = nil
            folderChangeScanTask?.cancel()
            isFolderChangeScanPending = false
            nextScanDate = nil
            folderChangeMonitor.stop()
            historyChangeMonitor.stop()
            historyIngestTask?.cancel()
            return
        }

        let intervalSeconds = settings.scanIntervalSeconds
        scheduleNextScanIfNeeded()
        restartFolderChangeMonitoring()
        restartHistoryMonitoring()
        scanTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(intervalSeconds))
                self?.scanNow()
            }
        }
    }

    private func restartFolderChangeMonitoring() {
        guard settings.automaticScanningEnabled else {
            folderChangeMonitor.stop()
            return
        }

        folderChangeMonitor.start(requests: scanRequests()) { [weak self] in
            Task { @MainActor in
                self?.scheduleFolderChangeScan()
            }
        }
    }

    private func scheduleFolderChangeScan() {
        guard settings.automaticScanningEnabled else { return }

        folderChangeScanTask?.cancel()
        isFolderChangeScanPending = true
        nextScanDate = Date().addingTimeInterval(5)
        statusMessage = "Recording folder changed; scanning soon"

        folderChangeScanTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            await MainActor.run {
                guard let self, !Task.isCancelled else { return }
                self.isFolderChangeScanPending = false
                self.scanNow()
            }
        }
    }

    private func restartHistoryMonitoring() {
        guard settings.automaticScanningEnabled else {
            historyChangeMonitor.stop()
            return
        }

        historyChangeMonitor.start(requests: historyRequests()) { [weak self] in
            Task { @MainActor in
                self?.scheduleHistoryIngest()
            }
        }
    }

    /// Debounce a burst of history-folder FS events into a single ingest sweep.
    private func scheduleHistoryIngest() {
        guard settings.automaticScanningEnabled else { return }

        historyIngestTask?.cancel()
        historyIngestTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            await MainActor.run {
                guard let self, !Task.isCancelled else { return }
                self.ingestHistoryNow()
            }
        }
    }

    private func historyRequests() -> [FolderScanRequest] {
        FolderScanRequest.historyRequests(from: folderAccesses) { [folderAccessStore] access in
            folderAccessStore.resolve(access)
        }
    }

    /// App IDs whose history folders are worth sweeping: those the user granted,
    /// plus any app with documented default history paths.
    private func historySweepAppIDs() -> [String] {
        var appIDs = Set(folderAccesses.filter { $0.kind == .history }.map(\.appID))
        for software in SupportedDJSoftware.all where !software.defaultHistoryPaths.isEmpty {
            appIDs.insert(software.id)
        }
        return Array(appIDs)
    }

    /// Ingest any fresh in-window history export and re-match. Idempotent and
    /// safe to call repeatedly — FSEvents, the backstop poll, and the launch
    /// catch-up sweep all funnel here. Runs synchronously on the main actor,
    /// mirroring `autopullTracklist`; history exports are small text files.
    func ingestHistoryNow() {
        guard settings.automaticScanningEnabled else { return }
        let appIDs = historySweepAppIDs()
        guard !appIDs.isEmpty, !sessions.isEmpty else { return }

        let references = sessions.map { HistoryAutoIngest.ArchiveReference(date: $0.detectedAt) }
        let result = HistoryAutoIngest().sweep(
            historyAppIDs: appIDs,
            historyAccesses: folderAccesses.filter { $0.kind == .history },
            folderAccessStore: folderAccessStore,
            importedTracklistStore: importedTracklistStore,
            activityLogStore: activityLogStore,
            references: references,
            existing: allImportedTracklists
        )
        if !result.isEmpty {
            refresh()
        }
    }

    private func scheduleNextScanIfNeeded() {
        nextScanDate = settings.automaticScanningEnabled
            ? Date().addingTimeInterval(TimeInterval(settings.scanIntervalSeconds))
            : nil
    }

    private func scanRequests() -> [FolderScanRequest] {
        FolderScanRequest.recordingRequests(from: folderAccesses) { [folderAccessStore] access in
            folderAccessStore.resolve(access)
        }
    }

    private func hasRecentUnstableRecording(for appID: String, now: Date = Date()) -> Bool {
        let checker = FileStabilityChecker()
        let cutoff = Calendar.current.date(byAdding: .hour, value: -24, to: now) ?? .distantPast
        let unstableAfter = now.addingTimeInterval(-30)

        return scanRequests()
            .filter { $0.appID == appID }
            .contains { request in
                (try? withSecurityScopedFolder(request) { folderURL in
                    try !checker.recentUnstableAudioFiles(
                        in: folderURL,
                        modifiedAfter: cutoff,
                        unstableAfter: unstableAfter
                    ).isEmpty
                }) ?? false
            }
    }

    private func isReachableDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    private func withSecurityScopedFolder<T>(
        _ request: FolderScanRequest,
        operation: (URL) throws -> T
    ) throws -> T {
        do {
            return try SecurityScopedAccess.withScopedAccess(
                bookmarkData: request.bookmarkData,
                fallbackURL: request.folderURL,
                operation: operation
            )
        } catch SecurityScopedAccessError.staleBookmark {
            throw FolderScanAccessError.staleBookmark(request.folderURL)
        } catch SecurityScopedAccessError.resolveFailed {
            throw CocoaError(.fileNoSuchFile)
        }
    }

    private func defaultFolderPanelURL(appID: String, kind: FolderKind) -> URL? {
        switch kind {
        case .recordings:
            return recordingFolders(for: appID).first
        case .history:
            return historyFolders(for: appID).first
        }
    }

    private func scanCoordinator() -> ScanCoordinator {
        let scanner = RecordingFolderScanner(archiveService: archiveService())
        return ScanCoordinator(scanner: scanner)
    }

    private func archiveService() -> ArchiveService {
        ArchiveService(
            archiveRoot: archiveRoot,
            namingTemplate: settings.archiveNamingTemplate,
            archiveRootBookmarkData: settings.archiveRootBookmarkData,
            verifyCopies: settings.verifyCopies
        )
    }

    private func sessionLibrary() -> SessionLibrary {
        SessionLibrary(
            archiveRoot: archiveRoot,
            archiveRootBookmarkData: settings.archiveRootBookmarkData
        )
    }

    private func ensureArchiveRootExists() {
        do {
            try archiveService().ensureArchiveRootExists()
        } catch {
            appendActivity(kind: .error, message: "Archive folder unavailable", detail: error.localizedDescription)
        }
    }

    private func resolvedArchiveRoot() -> URL {
        if let bookmarkData = settings.archiveRootBookmarkData,
           let url = try? SecurityScopedAccess.resolve(bookmarkData: bookmarkData) {
            return url
        }

        if let archiveRootPath = settings.archiveRootPath, !archiveRootPath.isEmpty {
            return URL(fileURLWithPath: (archiveRootPath as NSString).expandingTildeInPath, isDirectory: true)
        }

        return ArchiveService.defaultArchiveRoot()
    }

    private func withSecurityScopedArchiveRoot<T>(_ operation: () throws -> T) throws -> T {
        try SecurityScopedAccess.withScopedArchiveRootAccess(
            bookmarkData: settings.archiveRootBookmarkData,
            operation: operation
        )
    }

    private func scanStatusMessage(for results: [FolderScanResult]) -> String {
        guard !results.isEmpty else {
            return "Choose recording folders to start protecting sets"
        }

        let archivedCount = results.reduce(0) { $0 + $1.archivedSessions.count }
        let pendingCount = results.reduce(0) { $0 + $1.pendingRecordingURLs.count }
        let errorCount = results.filter { $0.errorDescription != nil }.count

        if pendingCount > 0 {
            return "Detected \(pendingCount) active recording\(pendingCount == 1 ? "" : "s"). Waiting for file to finish."
        }

        if archivedCount > 0 {
            return "Archived \(archivedCount) set\(archivedCount == 1 ? "" : "s")"
        }

        if errorCount > 0 {
            return "\(errorCount) folder\(errorCount == 1 ? "" : "s") need attention"
        }

        return "Scan complete. No new recordings found."
    }

    private func appendScanActivity(_ results: [FolderScanResult]) {
        guard !results.isEmpty else {
            appendActivity(kind: .scan, message: "Scan skipped", detail: "No recording folders configured")
            return
        }

        for result in results {
            if let errorDescription = result.errorDescription {
                appendActivity(kind: .error, message: "Scan failed", detail: "\(result.folderURL.path): \(errorDescription)")
            } else if !result.pendingRecordingURLs.isEmpty {
                appendActivity(
                    kind: .scan,
                    message: "Recording detected",
                    detail: pendingRecordingDetail(for: result)
                )
            } else if result.archivedSessions.isEmpty {
                appendActivity(kind: .scan, message: "No new recordings", detail: result.folderURL.path)
            } else {
                appendActivity(
                    kind: .archive,
                    message: "Archived \(result.archivedSessions.count) recording\(result.archivedSessions.count == 1 ? "" : "s")",
                    detail: result.folderURL.path
                )
                if settings.notifyAfterArchiving {
                    for session in result.archivedSessions {
                        notifyForNewArchive(session)
                    }
                }
            }
        }
    }

    private func pendingRecordingDetail(for result: FolderScanResult) -> String {
        let names = result.pendingRecordingURLs
            .map(\.lastPathComponent)
            .joined(separator: ", ")
        return "\(result.folderURL.path): waiting for \(names)"
    }

    private func notifyForNewArchive(_ session: RecordingSession) {
        guard settings.notifyAfterArchiving else { return }
        let meta = ArchiveMetadata(session: session, originalFilename: session.sourceURL.lastPathComponent)
        switch PerformanceSessionLinker.attachment(of: meta, existing: sessions) {
        case .newPerformance:
            notificationService.notifyArchiveSaved(count: 1)
        case .hardwareBackupAttached:
            notificationService.notifyPerformanceAttachment("Hardware backup attached to this set.")
        case .primaryAttached(let appID):
            notificationService.notifyPerformanceAttachment(
                "\(displayName(for: appID)) recording attached as the primary file."
            )
        }
    }

    private func appendActivity(kind: ActivityEventKind, message: String, detail: String? = nil) {
        do {
            try activityLogStore.append(ActivityEvent(kind: kind, message: message, detail: detail))
            activityEvents = (try? activityLogStore.all()) ?? activityEvents
        } catch {
            statusMessage = "Could not write activity: \(error.localizedDescription)"
        }
    }

    private func saveSettings(_ newSettings: AppSettings) {
        do {
            try appSettingsStore.save(newSettings)
            settings = newSettings
            startBackgroundScanning()
            statusMessage = newSettings.automaticScanningEnabled
                ? "Automatic scan runs every \(newSettings.scanIntervalSeconds) seconds"
                : "Automatic scan is off"
        } catch {
            appendActivity(kind: .error, message: "Settings save failed", detail: error.localizedDescription)
            statusMessage = "Could not save settings: \(error.localizedDescription)"
        }
    }

    private func reconcileLaunchAtLogin() {
        let status = SMAppService.mainApp.status
        launchAtLoginNeedsApproval = status == .requiresApproval
        let osEnabled = status == .enabled

        if settings.launchAtLogin == osEnabled {
            return
        }

        if settings.launchAtLogin, !osEnabled {
            // Prefer the saved preference; do not clear it if registration fails outside a real .app bundle.
            applyLaunchAtLogin(enabled: true, persistPreference: false, quiet: true)
            launchAtLoginNeedsApproval = SMAppService.mainApp.status == .requiresApproval
            return
        }

        if !settings.launchAtLogin, osEnabled {
            applyLaunchAtLogin(enabled: false, persistPreference: true, quiet: true)
        }
    }

    private func applyLaunchAtLogin(enabled: Bool, persistPreference: Bool, quiet: Bool = false) {
        let service = SMAppService.mainApp
        do {
            if enabled {
                if service.status != .enabled {
                    try service.register()
                }
            } else if service.status != .notRegistered {
                try service.unregister()
            }

            launchAtLoginNeedsApproval = service.status == .requiresApproval
            if persistPreference {
                persistLaunchAtLoginPreference(enabled)
            }

            if quiet { return }

            if enabled, service.status == .requiresApproval {
                statusMessage = "macOS needs approval for launch at login in System Settings → Login Items."
            } else {
                statusMessage = enabled ? "Launch at login enabled" : "Launch at login disabled"
            }
        } catch {
            let actuallyEnabled = SMAppService.mainApp.status == .enabled
            launchAtLoginNeedsApproval = SMAppService.mainApp.status == .requiresApproval
            if persistPreference {
                persistLaunchAtLoginPreference(actuallyEnabled)
            }
            appendActivity(kind: .error, message: "Launch at login failed", detail: error.localizedDescription)
            if quiet { return }
            if SMAppService.mainApp.status == .requiresApproval {
                statusMessage = "macOS needs approval for launch at login in System Settings → Login Items."
            } else {
                statusMessage = "Could not update launch at login: \(error.localizedDescription). Preference was left matching the system."
            }
        }
    }

    private func persistLaunchAtLoginPreference(_ enabled: Bool) {
        let newSettings = settings.updating(launchAtLogin: enabled)
        do {
            try appSettingsStore.save(newSettings)
            settings = newSettings
        } catch {
            appendActivity(kind: .error, message: "Settings save failed", detail: error.localizedDescription)
            statusMessage = "Could not save settings: \(error.localizedDescription)"
        }
    }

    private static func nilIfBlank(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func diagnosticsTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.string(from: Date())
    }

    /// Fast poll while nothing is armed yet — first detection should feel prompt. Once
    /// armed/watching/recording, the only remaining job of these poll loops is the
    /// alternate-source heads-up (see `refreshAppAudioTargets`/`refreshAudioInputs`), which
    /// isn't time-critical, so back off to a slower cadence rather than repeating the same
    /// (occasionally expensive — e.g. ScreenCaptureKit's shareable-content enumeration) work
    /// four times a minute for no benefit.
    private static let capturePollIntervalIdle: UInt64 = 15_000_000_000
    private static let capturePollIntervalEngaged: UInt64 = 60_000_000_000

    /// The only two `.failed` reasons that are safe to auto-clear once targets/devices
    /// reappear — both mean "nothing to arm against yet," not a real capture failure. Any other
    /// `.failed` reason (wrong permission, disk full, stream stopped, engine error — all set by
    /// `applyAppAudioCaptureFailure`/`applyCaptureFailure`) must stay visible until the user
    /// explicitly re-arms; silently clearing those tore down and rebuilt a live Process Audio Tap
    /// mid-recording, corrupting the in-progress take.
    private static let noAppAudioTargetsFoundMessage = "No supported DJ apps are running and shareable."
    private static let noAudioInputDevicesFoundMessage = "No audio input devices are available."

    private func startCapturePolling() {
        captureTargetPollTask?.cancel()
        captureInputPollTask?.cancel()
        captureTargetPollTask = Task { [weak self] in
            var isFirst = true
            while !Task.isCancelled {
                guard let self else { return }
                if !isFirst {
                    let interval = await MainActor.run {
                        self.captureState.isWatchingOrRecording
                            ? Self.capturePollIntervalEngaged
                            : Self.capturePollIntervalIdle
                    }
                    try? await Task.sleep(nanoseconds: interval)
                }
                isFirst = false
                await MainActor.run {
                    guard self.captureState.mode == .appAudio else { return }
                    switch self.captureState.phase {
                    case .requestingPermission, .saving:
                        return
                    case .needsScreenRecordingPermission:
                        guard AppAudioCaptureService.screenCapturePermissionGranted() else { return }
                    default:
                        break
                    }
                    // `attemptAutoArm: true` is safe to pass unconditionally — auto-arm only
                    // actually fires when phase is idle/armed (see `refreshAppAudioTargets`), so
                    // while watching/recording this call only ever does the alternate-source check.
                    Task { await self.refreshAppAudioTargets(attemptAutoArm: true) }
                }
            }
        }
        captureInputPollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let interval = await MainActor.run {
                    self.captureState.isWatchingOrRecording
                        ? Self.capturePollIntervalEngaged
                        : Self.capturePollIntervalIdle
                }
                try? await Task.sleep(nanoseconds: interval)
                await MainActor.run {
                    if case .saving = self.captureState.phase { return }
                    self.refreshAudioInputs()
                }
            }
        }
    }

    /// After archive, pull a nearby history export from known local history folders (soft-fail).
    private func autopullTracklist(for session: RecordingSession) {
        let appIDs = TracklistAutopull.historyAppIDs(
            sourceAppID: session.sourceAppID,
            selectedTargetAppID: captureState.selectedTargetApp?.software.id,
            historyAccesses: folderAccesses
        )
        do {
            let result = try TracklistAutopull().attempt(
                session: session,
                historyAppIDs: appIDs,
                historyAccesses: folderAccesses.filter { $0.kind == .history },
                folderAccessStore: folderAccessStore,
                importedTracklistStore: importedTracklistStore,
                activityLogStore: activityLogStore,
                setContextStore: setContextStore,
                archives: sessions,
                importedTracklists: allImportedTracklists,
                setContexts: Array(setContexts.values)
            )
            refresh()
            switch result {
            case .attached:
                break
            case .notFound, .failed:
                if statusMessage.hasPrefix("Archived")
                    || statusMessage.hasPrefix("App audio")
                    || statusMessage.hasPrefix("Capture saved")
                {
                    statusMessage = "\(statusMessage) No history export found to attach."
                }
            }
        } catch {
            appendActivity(kind: .error, message: "History autopull failed", detail: error.localizedDescription)
            refresh()
        }
    }
}


extension AppModel {
    func previewApplyCaptureState(_ state: CaptureUIState) { captureState = state }

    func previewSetRecordingStartedAt(_ date: Date?) { recordingStartedAt = date }

    func candidateTracklists(for archive: ArchiveMetadata) -> [ImportedTracklist] {
        let matchable = allImportedTracklists.filter(\.kind.isMatchableToRecording)
        if LibrarySessionMatcher.hardwareCaptureAppIDs.contains(archive.sourceAppID) {
            return matchable.filter { LibrarySessionMatcher.hardwareRelatedTracklistAppIDs.contains($0.appID) }
        }
        return matchable.filter { $0.appID == archive.sourceAppID }
    }

    func setCaptureMode(_ mode: CaptureMode) {
        applyCaptureMode(mode, userInitiated: true)
    }

    private func applyCaptureMode(_ mode: CaptureMode, userInitiated: Bool) {
        if captureState.mode == mode { return }
        if captureState.mode == .appAudio, captureState.isWatchingOrRecording {
            haltAppAudioCapture(markUserDisarmed: userInitiated)
        }
        if captureState.mode == .inputDevice, captureService.isMonitoring || captureState.isRecording {
            haltInputCapture(markUserDisarmed: userInitiated)
        }
        if userInitiated {
            userDisarmedAppAudio = false
            userDisarmedInputCapture = false
            userSuppressedPioneerAutoSwitch = (mode == .appAudio)
        }
        var next = captureState
        next.mode = mode
        next.phase = .idle
        next.inputLevel = 0
        next.statusMessage = mode == .appAudio
            ? "Choose a running DJ app, then arm App audio Capture."
            : "Choose an input device, then start Capture."
        next.pendingAlternateSource = nil
        next.appAudioSourceName = nil
        captureState = next
        let newSettings = settings.updating(captureMode: mode)
        do { try appSettingsStore.save(newSettings); settings = newSettings } catch {}
        if mode == .inputDevice {
            refreshAudioInputs()
        } else {
            Task { await refreshAppAudioTargets(attemptAutoArm: true) }
        }
    }

    func refreshAppAudioTargets(attemptAutoArm: Bool = true) async {
        do {
            let apps = try await appAudioCaptureService.listShareableDJApps()
            var next = captureState
            next.targetApps = apps
            if next.selectedTargetAppID == nil {
                next.selectedTargetAppID = settings.lastCaptureTargetAppID ?? apps.first?.software.id
            } else if !apps.contains(where: { $0.software.id == next.selectedTargetAppID }) {
                next.selectedTargetAppID = apps.first?.software.id
            }
            // DJs don't run multiple DJ apps at once. If we're already watching/recording one
            // app and a *different* one shows up, never silently retarget — surface it instead
            // and let the user decide (or dismiss). Mirrors the same rule for input devices in
            // `refreshAudioInputs()`.
            if next.mode == .appAudio, next.isWatchingOrRecording, let currentID = next.selectedTargetAppID {
                if let alternate = apps.first(where: { $0.software.id != currentID }) {
                    let pending = PendingAlternateSource(
                        kind: .appAudio(softwareID: alternate.software.id),
                        displayName: alternate.software.displayName
                    )
                    if next.pendingAlternateSource != pending, !dismissedAlternateSourceIDs.contains(pending.id) {
                        next.pendingAlternateSource = pending
                        notificationService.notifyAlternateSourceDetected(displayName: pending.displayName)
                    }
                } else if case .appAudio = next.pendingAlternateSource?.kind {
                    next.pendingAlternateSource = nil
                }
            }
            if next.phase == .idle || next.phase == .armed {
                next.phase = apps.isEmpty ? .idle : .armed
            }
            // Only auto-recover from the benign "nothing detected yet" failure this function
            // itself sets — never silently promote a genuine capture-engine failure (wrong
            // permission, disk full, stream stopped, etc., set by `applyAppAudioCaptureFailure`)
            // back to `.armed`. That used to happen unconditionally here, which meant any transient
            // mid-recording failure got silently retried on the next poll — tearing down and
            // rebuilding the Process Audio Tap mid-session without the user ever seeing the
            // failure, corrupting the in-progress recording.
            if case .failed(Self.noAppAudioTargetsFoundMessage) = next.phase {
                next.phase = apps.isEmpty ? .failed(Self.noAppAudioTargetsFoundMessage) : .armed
            }
            if !next.isWatchingOrRecording {
                next.statusMessage = apps.isEmpty
                    ? "Open Serato, rekordbox, Traktor, VirtualDJ, or djay Pro, then refresh targets. If the DJ app routes audio only to a hardware interface, use Input device Capture or folder Protection instead."
                    : "Arm App audio Capture to record when the DJ app plays — even if Record/Save is off. After \(settings.appAudioIdleSeconds)s of silence, SetCatcher saves and waits for the next set."
            }
            captureState = next

            let canAutoArm = attemptAutoArm
                && settings.autoArmOnDJAppFound
                && !userDisarmedAppAudio
                && next.mode == .appAudio
                && !apps.isEmpty
                && (next.phase == .idle || next.phase == .armed)
            if canAutoArm {
                armAppAudioCapture()
            }
        } catch let error as AppAudioCaptureError {
            applyAppAudioCaptureFailure(error)
        } catch {
            var next = captureState
            next.targetApps = []
            next.phase = .failed(error.localizedDescription)
            next.statusMessage = "Could not list shareable DJ apps: \(error.localizedDescription). Refresh targets, or use Input device Capture / folder Protection."
            captureState = next
        }
    }

    func selectCaptureTargetApp(_ softwareID: String) {
        var next = captureState
        next.selectedTargetAppID = softwareID
        captureState = next
        let newSettings = settings.updating(lastCaptureTargetAppID: .some(softwareID))
        do { try appSettingsStore.save(newSettings); settings = newSettings } catch {}
    }

    func armAppAudioCapture() {
        userDisarmedAppAudio = false
        Task {
            await refreshAppAudioTargets(attemptAutoArm: false)
            guard let target = captureState.selectedTargetApp else {
                var next = captureState
                next.phase = .failed("Choose a running DJ app before arming App audio Capture.")
                next.statusMessage = "Choose a running DJ app before arming App audio Capture. Open a DJ app, refresh targets, then try again."
                captureState = next
                return
            }

            let inputDevices = AudioInputDeviceCatalog.listInputs()
            let runningIDs = currentDJSoftwareIDs()
            let selection = AppAudioCaptureService.preferredSelection(
                targetSoftware: target.software,
                inputDevices: inputDevices,
                runningSoftwareIDs: runningIDs
            )

            var requesting = captureState
            requesting.phase = .requestingPermission
            switch selection {
            case .virtualInputDevice(let device, _):
                requesting.statusMessage = "Requesting microphone access for \(device.name)…"
            case .processAudioTap:
                requesting.statusMessage = "Requesting System Audio Recording access for Process Audio Tap…"
            case .screenCaptureKit:
                requesting.statusMessage = "Requesting Screen & System Audio Recording access…"
            }
            captureState = requesting

            if case .virtualInputDevice = selection {
                if !CaptureService.microphonePermissionGranted() {
                    let granted = await CaptureService.requestMicrophonePermission()
                    guard granted else {
                        var denied = captureState
                        denied.phase = .failed("Microphone access is denied. SetCatcher cannot Capture without it.")
                        denied.statusMessage = "Microphone access is denied. Open System Settings to allow SetCatcher."
                        captureState = denied
                        statusMessage = "Microphone access is denied"
                        return
                    }
                }
            } else if selection.kind == .screenCaptureKit, !AppAudioCaptureService.screenCapturePermissionGranted() {
                // CGRequestScreenCaptureAccess often returns before the user finishes Settings.
                _ = AppAudioCaptureService.requestScreenCapturePermission()
                // Brief settle for in-process grants; Settings toggles still require Arm again.
                try? await Task.sleep(nanoseconds: 400_000_000)
                if !AppAudioCaptureService.screenCapturePermissionGranted() {
                    var denied = captureState
                    denied.phase = .needsScreenRecordingPermission
                    denied.statusMessage = "Screen & System Audio Recording permission is required. Open System Settings to allow SetCatcher, then return here and Arm again. Folder Protection and Input device Capture still work."
                    captureState = denied
                    statusMessage = "Screen recording access is denied"
                    return
                }
            }

            do {
                try await appAudioCaptureService.startMonitoring(
                    bundleIdentifier: target.matchedBundleIdentifier,
                    displayName: target.software.displayName,
                    // Buffer at least the start hold (plus margin) so takes begin at the true first
                    // signal, not after the silence session's start-hold delay.
                    prerollSeconds: settings.silenceSessionConfig.prerollSeconds,
                    softwareID: target.software.id,
                    inputDevices: inputDevices,
                    runningSoftwareIDs: runningIDs
                )
                let tick = captureSession.prepareWatching(
                    config: settings.silenceSessionConfig,
                    targetDisplayName: target.software.displayName
                )
                var watching = captureState
                watching.phase = tick.phase
                watching.inputLevel = tick.inputLevel
                watching.appAudioSourceName = appAudioCaptureService.captureSourceDisplayName
                watching.statusMessage = appAudioArmedStatusMessage(tick: tick, selection: selection)
                captureState = watching
                statusMessage = "App Audio Capture: \(appAudioCaptureService.captureSourceDisplayName)"
                appendActivity(
                    kind: .capture,
                    message: "App audio backend \(appAudioCaptureService.activeBackendKind.rawValue)",
                    detail: appAudioBackendLogDetail()
                )
                startAppAudioPolling()
            } catch let error as AppAudioCaptureError {
                applyAppAudioCaptureFailure(error)
            } catch {
                var failed = captureState
                failed.phase = .failed(error.localizedDescription)
                failed.statusMessage = error.localizedDescription
                captureState = failed
            }
        }
    }

    private func appAudioArmedStatusMessage(
        tick: CaptureSessionTick,
        selection: AppAudioCaptureBackendSelection
    ) -> String {
        let sourceLine = "App Audio Capture: \(appAudioCaptureService.captureSourceDisplayName)"
        if appAudioCaptureService.virtualBindDidFallBack {
            return "\(sourceLine) could not bind; using \(appAudioCaptureService.activeBackendKind.displayName). \(tick.statusMessage)"
        }
        if appAudioCaptureService.activeBackendKind == .screenCaptureKit,
           selection.kind == .processAudioTap || selection.kind == .virtualInputDevice {
            return "Process audio capture is unavailable on this Mac; using fallback capture. \(tick.statusMessage)"
        }
        if appAudioCaptureService.activeBackendKind == .virtualInputDevice {
            return "\(sourceLine). \(tick.statusMessage)"
        }
        return tick.statusMessage
    }

    private func appAudioBackendLogDetail() -> String {
        let kind = appAudioCaptureService.activeBackendKind.rawValue
        if let device = appAudioCaptureService.activeVirtualDevice {
            return "backend=\(kind) device=\(device.name) uid=\(device.id) transport=\(device.transportType.archiveLabel)"
        }
        return "backend=\(kind)"
    }

    private func currentDJSoftwareIDs() -> Set<String> {
        var ids = Set(probeResults.filter(\.isRunning).map(\.software.id))
        ids.formUnion(captureState.targetApps.map(\.software.id))
        return ids
    }

    func disarmAppAudioCapture() {
        haltAppAudioCapture(markUserDisarmed: true)
        Task {
            let tick = captureSession.disarm(hasTargets: !captureState.targetApps.isEmpty)
            var next = captureState
            next.phase = tick.phase
            next.inputLevel = 0
            next.statusMessage = tick.statusMessage
            next.pendingAlternateSource = nil
            next.appAudioSourceName = nil
            captureState = next
            statusMessage = "App audio Capture disarmed"
        }
    }

    private func startAppAudioPolling() {
        appAudioPollTask?.cancel()
        appAudioPollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 100_000_000)
                await MainActor.run {
                    guard let self else { return }
                    guard self.captureState.mode == .appAudio else { return }
                    guard self.captureState.phase == .watching || self.captureState.phase == .recording else { return }
                    let level = self.appAudioCaptureService.currentInputLevel()
                    let tick = self.captureSession.tick(level: level)
                    self.applyCaptureSessionTick(tick)
                    self.refreshCaptureStagingBytes()
                }
            }
        }
    }

    private func applyCaptureSessionTick(_ tick: CaptureSessionTick) {
        var next = captureState
        if !tick.statusMessage.isEmpty {
            next.statusMessage = tick.statusMessage
        }
        next.phase = tick.phase
        next.inputLevel = tick.inputLevel
        applyLiveCaptureListening(
            to: &next,
            hardwareMonitor: .unbound
        )
        captureState = next

        guard let action = tick.engineAction else { return }
        switch action {
        case .beginRecordingFile:
            do {
                try appAudioCaptureService.beginRecordingFile()
                let now = Date()
                let displayName = captureState.selectedTargetApp?.software.displayName ?? "DJ app"
                if settings.notifyAfterArchiving {
                    notificationService.notifyCaptureStarted(displayName: displayName, at: now)
                }
                statusMessage = LocalNotificationService.captureStartedBody(displayName: displayName, at: now)
            } catch let error as AppAudioCaptureError {
                applyAppAudioCaptureFailure(error)
            } catch {
                var failed = captureState
                failed.phase = .failed(error.localizedDescription)
                failed.statusMessage = error.localizedDescription
                captureState = failed
            }
        case .endRecordingFile(let discard):
            finalizeAppAudioSession(discard: discard)
        }
    }

    private func finalizeAppAudioSession(discard: Bool, resumeWatching: Bool = true) {
        var saving = captureState
        saving.phase = .saving
        saving.statusMessage = discard ? "Discarding short take…" : "Saving app audio into your archive…"
        captureState = saving
        do {
            let result = try appAudioCaptureService.endRecordingFile(discard: discard)
            if let result, !discard {
                stagePendingCaptureRecovery(
                    result,
                    sourceAppID: captureState.selectedTargetApp?.software.id ?? SupportedDJSoftware.captureAppID,
                    route: result.captureRoute ?? .appAudio,
                    backend: result.captureBackend ?? appAudioCaptureService.activeBackendKind.archiveBackend,
                    transport: result.deviceTransport?.archiveLabel
                        ?? appAudioCaptureService.activeVirtualDevice?.transportType.archiveLabel
                )
                let session = try ingestPendingCaptureRecovery()
                notifyForNewArchive(session)
                refresh()
                autopullTracklist(for: session)
                var done = captureState
                done.lastArchivedSessionID = session.id
                if resumeWatching {
                    let tick = captureSession.resumeWatchingAfterSave(
                        discarded: false,
                        minDurationSeconds: TimeInterval(settings.appAudioMinDurationSeconds),
                        level: appAudioCaptureService.currentInputLevel()
                    )
                    done.phase = tick.phase
                    done.inputLevel = tick.inputLevel
                    done.statusMessage = tick.statusMessage
                } else {
                    appAudioPollTask?.cancel()
                    appAudioPollTask = nil
                    let tick = captureSession.disarm(hasTargets: !captureState.targetApps.isEmpty)
                    done.phase = tick.phase
                    done.inputLevel = 0
                    done.statusMessage = tick.statusMessage
                    userDisarmedAppAudio = true
                    Task { await appAudioCaptureService.stopMonitoring() }
                }
                captureState = done
                statusMessage = "App audio Capture saved"
            } else {
                var done = captureState
                if resumeWatching {
                    let tick = captureSession.resumeWatchingAfterSave(
                        discarded: true,
                        minDurationSeconds: TimeInterval(settings.appAudioMinDurationSeconds),
                        level: appAudioCaptureService.currentInputLevel()
                    )
                    done.phase = tick.phase
                    done.inputLevel = tick.inputLevel
                    done.statusMessage = tick.statusMessage
                } else {
                    appAudioPollTask?.cancel()
                    appAudioPollTask = nil
                    let tick = captureSession.disarm(hasTargets: !captureState.targetApps.isEmpty)
                    done.phase = tick.phase
                    done.inputLevel = 0
                    done.statusMessage = tick.statusMessage
                    userDisarmedAppAudio = true
                    Task { await appAudioCaptureService.stopMonitoring() }
                }
                captureState = done
            }
        } catch let error as AppAudioCaptureError {
            applyAppAudioCaptureFailure(error)
        } catch {
            var failed = captureState
            failed.phase = .failed(error.localizedDescription)
            failed.statusMessage = error.localizedDescription
            captureState = failed
            statusMessage = "Could not save app audio: \(error.localizedDescription)"
        }
    }

    func refreshAudioInputs() {
        // Blocked ambient/system mics (built-in, Bluetooth, Continuity) never appear in the
        // picker and can never be selected — SetCatcher must never record from a room mic.
        let allDevices = AudioInputDeviceCatalog.listInputs()
        let devices = AudioInputDeviceCatalog.selectableInputs(from: allDevices)
        refreshHardwareObservationCache(from: devices)
        var next = captureState
        next.devices = devices

        // Clear a previously-persisted blocked selection (e.g. the built-in mic saved by an
        // older build before this guard existed): drop it and tell the user why. Validate the
        // *current* selection every refresh, not only when it's nil/missing.
        var clearedBlockedSelection = false
        if let selectedID = next.selectedDeviceID,
           let selected = allDevices.first(where: { $0.id == selectedID }),
           selected.isBlockedInput {
            next.selectedDeviceID = nil
            clearedBlockedSelection = true
        }
        if let lastID = settings.lastCaptureDeviceID,
           let last = allDevices.first(where: { $0.id == lastID }),
           last.isBlockedInput {
            // Also scrub the persisted setting so it can't be re-applied on a later launch.
            let newSettings = settings.updating(lastCaptureDeviceID: .some(nil))
            do { try appSettingsStore.save(newSettings); settings = newSettings } catch {}
        }

        if next.selectedDeviceID == nil {
            let persisted = settings.lastCaptureDeviceID.flatMap { id in devices.first(where: { $0.id == id }) }
            next.selectedDeviceID = persisted?.id ?? AudioInputDeviceCatalog.preferredDefault(
                from: devices,
                currentSoftwareIDs: currentDJSoftwareIDs()
            )?.id
        } else if !devices.contains(where: { $0.id == next.selectedDeviceID }) {
            next.selectedDeviceID = AudioInputDeviceCatalog.preferredDefault(
                from: devices,
                currentSoftwareIDs: currentDJSoftwareIDs()
            )?.id
        }

        let preferred = devices.first(where: \.isTrustedDJHardwareFeed)
        if lastPioneerDeviceID == nil, preferred != nil {
            userSuppressedPioneerAutoSwitch = false
            userDisarmedInputCapture = false
        }
        lastPioneerDeviceID = preferred?.id

        // Analog pin wins over DualRoute auto-select when set.
        if let pinnedID = settings.pinnedAnalogInputDeviceID,
           devices.contains(where: { $0.id == pinnedID }),
           next.mode == .inputDevice,
           !next.isRecording,
           next.phase != .saving,
           next.selectedDeviceID != pinnedID,
           !next.isWatchingOrRecording
        {
            next.selectedDeviceID = pinnedID
        } else if DualRoutePolicy.shouldAutoSelectHardware(posture: settings.dualRoutePosture),
           next.mode == .inputDevice,
           !next.isRecording,
           next.phase != .saving,
           let preferred,
           next.selectedDeviceID != preferred.id,
           settings.pinnedAnalogInputDeviceID == nil
        {
            if next.isWatchingOrRecording {
                // DJs don't run multiple hardware sources at once. Already watching a device —
                // never silently retarget mid-session, surface the alternate instead.
                let pending = PendingAlternateSource(
                    kind: .inputDevice(deviceID: preferred.id),
                    displayName: preferred.name
                )
                if next.pendingAlternateSource != pending, !dismissedAlternateSourceIDs.contains(pending.id) {
                    next.pendingAlternateSource = pending
                    notificationService.notifyAlternateSourceDetected(displayName: pending.displayName)
                }
            } else {
                next.selectedDeviceID = preferred.id
                let newSettings = settings.updating(lastCaptureDeviceID: .some(preferred.id))
                do { try appSettingsStore.save(newSettings); settings = newSettings } catch {}
            }
        }
        // Clear a pending device alternate once it's no longer the distinct preferred device
        // (unplugged, or the user already switched to it via `selectCaptureDevice`).
        if case .inputDevice(let pendingDeviceID) = next.pendingAlternateSource?.kind,
           preferred?.id != pendingDeviceID || next.selectedDeviceID == pendingDeviceID
        {
            next.pendingAlternateSource = nil
        }

        // Same fix as the app-audio path in `refreshAppAudioTargets`: only auto-clear the
        // benign "nothing to arm against yet" failure, never a genuine capture-engine failure.
        if case .failed(Self.noAudioInputDevicesFoundMessage) = next.phase {
            next.phase = devices.isEmpty ? .failed(Self.noAudioInputDevicesFoundMessage) : .armed
        } else if next.phase == .idle {
            next.phase = devices.isEmpty ? .idle : .armed
        }
        if next.mode == .inputDevice,
           !next.isRecording,
           next.phase != .saving,
           next.phase != .watching,
           next.phase != .recording
        {
            if clearedBlockedSelection {
                next.statusMessage = "The built-in microphone can't be used for capture. Choose a DJ mixer, deck, or App audio Capture."
            } else if let pinnedID = settings.pinnedAnalogInputDeviceID,
                      !devices.contains(where: { $0.id == pinnedID }) {
                let name = settings.lastCaptureDeviceID.flatMap { id in
                    allDevices.first { $0.id == id }?.name
                } ?? "your interface"
                next.statusMessage = AnalogMixerPolicy.missingPinnedDeviceMessage(deviceName: name)
            } else {
                next.statusMessage = devices.isEmpty
                    ? "Connect a DJM or other audio input, then refresh devices."
                    : "Choose an input device, then start Capture."
            }
        }
        applyLiveCaptureListening(
            to: &next,
            hardwareMonitor: LiveCaptureHardwareMonitorReading(
                monitoredDeviceID: next.selectedDeviceID,
                level: next.inputLevel,
                observing: captureService.isMonitoring
            )
        )
        captureState = next
        applyDualRoutePolicy()
    }

    func selectCaptureDevice(_ deviceID: String) {
        var next = captureState
        next.selectedDeviceID = deviceID
        captureState = next
        let shouldPinAnalog = pendingAnalogRecOutPin
            || selectedAppID == SupportedDJSoftware.analogMixerAppID
        let newSettings: AppSettings
        if shouldPinAnalog {
            pendingAnalogRecOutPin = false
            newSettings = settings.updating(
                lastCaptureDeviceID: .some(deviceID),
                pinnedAnalogInputDeviceID: .some(deviceID)
            )
        } else {
            newSettings = settings.updating(lastCaptureDeviceID: .some(deviceID))
        }
        do { try appSettingsStore.save(newSettings); settings = newSettings } catch {}
        if shouldPinAnalog {
            applyAnalogPinUnattendedWatch()
            refresh()
            statusMessage = "Pinned rec-out. Recording starts when audio is detected; idle silence saves the take."
        }
    }

    private func applyDualRoutePolicy() {
        guard captureState.phase != .saving else { return }
        let observations = liveCaptureObservations(
            devices: captureState.devices,
            hardwareMonitor: LiveCaptureHardwareMonitorReading(
                monitoredDeviceID: captureState.selectedDeviceID,
                level: captureState.inputLevel,
                observing: captureService.isMonitoring
            )
        )
        // USB plug-in of a CDJ/player is not a capturable mix. Prefer a verified or
        // still-detecting mixer / all-in-one USB feed only.
        let hardwarePresent = LiveCaptureHardwareClassifier.assess(observations).prefersHardwareInput

        if DualRoutePolicy.shouldAutoSwitchToInput(
            posture: settings.dualRoutePosture,
            hardwarePresent: hardwarePresent,
            userSuppressedAutoSwitch: userSuppressedPioneerAutoSwitch
        ), captureState.mode != .inputDevice, captureState.phase != .recording,
           settings.pinnedAnalogInputDeviceID == nil {
            haltAppAudioCapture(markUserDisarmed: false)
            var next = captureState
            next.mode = .inputDevice
            next.phase = captureState.devices.isEmpty ? .idle : .armed
            next.statusMessage = "Choose an input device, then start Capture."
            captureState = next
            let newSettings = settings.updating(captureMode: .inputDevice)
            do { try appSettingsStore.save(newSettings); settings = newSettings } catch {}
        }

        if DualRoutePolicy.shouldFallBackToAppAudio(
            posture: settings.dualRoutePosture,
            hardwarePresent: hardwarePresent,
            userSuppressedAutoSwitch: userSuppressedPioneerAutoSwitch
        ), captureState.mode == .inputDevice,
           captureState.phase != .recording,
           captureState.phase != .watching,
           captureState.phase != .saving,
           settings.pinnedAnalogInputDeviceID == nil {
            haltInputCapture(markUserDisarmed: false)
            var next = captureState
            next.mode = .appAudio
            next.phase = .idle
            next.statusMessage = "Choose a running DJ app, then arm App audio Capture."
            captureState = next
            let newSettings = settings.updating(captureMode: .appAudio)
            do { try appSettingsStore.save(newSettings); settings = newSettings } catch {}
            publishLiveCaptureListening(hardwareMonitor: .unbound)
            Task { await refreshAppAudioTargets(attemptAutoArm: true) }
            return
        }

        if DualRoutePolicy.shouldUnattendedWatch(
            posture: settings.dualRoutePosture,
            hardwarePresent: hardwarePresent,
            userDisarmedInput: userDisarmedInputCapture
        ), captureState.mode == .inputDevice,
           (captureState.phase == .idle || captureState.phase == .armed) {
            armInputCaptureWatching()
        }
        applyAnalogPinUnattendedWatch()
        publishLiveCaptureListening(
            hardwareMonitor: LiveCaptureHardwareMonitorReading(
                monitoredDeviceID: captureState.selectedDeviceID,
                level: captureState.inputLevel,
                observing: captureService.isMonitoring
            )
        )
    }

    private func applyAnalogPinUnattendedWatch() {
        guard AnalogMixerPolicy.shouldUnattendedWatch(
            pinnedDeviceID: settings.pinnedAnalogInputDeviceID,
            selectedDeviceID: captureState.selectedDeviceID,
            userDisarmedInput: userDisarmedInputCapture
        ) else { return }
        if captureState.mode != .inputDevice {
            var next = captureState
            next.mode = .inputDevice
            captureState = next
            let newSettings = settings.updating(captureMode: .inputDevice)
            do { try appSettingsStore.save(newSettings); settings = newSettings } catch {}
        }
        if captureState.phase == .idle || captureState.phase == .armed {
            armInputCaptureWatching()
        }
    }

    private func refreshHardwareObservationCache(from devices: [AudioInputDevice]) {
        var cache: [String: (channels: Int, formatOK: Bool)] = [:]
        for device in devices where device.isTrustedDJHardwareFeed {
            cache[device.id] = (
                AudioInputDeviceCatalog.inputChannelCount(forUID: device.id),
                AudioInputDeviceCatalog.isSupportedCaptureFormat(forUID: device.id)
            )
        }
        hardwareObservationCache = cache
    }

    private func liveCaptureObservations(
        devices: [AudioInputDevice],
        hardwareMonitor: LiveCaptureHardwareMonitorReading
    ) -> [HardwareInputObservation] {
        let drafts = LiveCaptureRouteFactsBuilder.pioneerDrafts(
            from: devices,
            cache: hardwareObservationCache
        )
        return liveCaptureDetection.observe(
            drafts,
            monitoredDeviceID: hardwareMonitor.monitoredDeviceID,
            level: hardwareMonitor.level,
            observing: hardwareMonitor.observing,
            now: Date()
        )
    }

    private func makeLiveCaptureFacts(
        devices: [AudioInputDevice],
        phase: CapturePhase,
        hardwareMonitor: LiveCaptureHardwareMonitorReading,
        recordingAlreadyActive: Bool
    ) -> LiveCaptureRouteFacts {
        let running = currentDJSoftwareIDs()
        let vendor = LiveCaptureRouteFactsBuilder.vendorVirtualInput(
            runningDJSoftwareIDs: running,
            devices: devices
        )
        let routingStatus = SeratoOutputRoutingAdapter().routingStatus(runningSoftwareIDs: running)
        let appAudio = LiveCaptureRouteFactsBuilder.appAudioObservation(
            runningDJSoftwareIDs: running,
            isMonitoring: appAudioCaptureService.isMonitoring,
            activeBackend: appAudioCaptureService.activeBackendKind,
            sourceDeviceUID: appAudioCaptureService.activeSourceDeviceUID,
            peakLevel: appAudioCaptureService.currentInputLevel(),
            applePathExhausted: appAudioCaptureService.appleAppAudioPathExhausted,
            screenCapturePermissionGranted: AppAudioCaptureService.screenCapturePermissionGranted()
        )
        let hardware = liveCaptureObservations(devices: devices, hardwareMonitor: hardwareMonitor)
        let currentFeedIsProducingSignal = LiveCaptureRouteFactsBuilder.hardwareFeedIsProducingSignal(
            currentKind: lastLiveCaptureKind,
            currentDeviceID: lastLiveCaptureDeviceID,
            monitoredDeviceID: hardwareMonitor.monitoredDeviceID,
            level: hardwareMonitor.level
        )

        return LiveCaptureRouteFactsBuilder.build(
            LiveCaptureRouteFactsBuilder.Input(
                devices: devices,
                hardwareObservationCache: hardwareObservationCache,
                hardwareMonitor: hardwareMonitor,
                hardware: hardware,
                driverAvailability: SetCatcherAudioDriverIdentity.availability(in: devices),
                vendorVirtualInput: vendor,
                vendorVirtualEnabled: AppAudioCaptureBackendSelector.virtualAppAudioEnabled,
                runningDJSoftwareIDs: running,
                appAudioCapability: appAudio.capability,
                appAudio: appAudio,
                phase: phase,
                currentKind: lastLiveCaptureKind,
                currentDeviceID: lastLiveCaptureDeviceID,
                currentBackend: lastLiveCaptureBackend,
                currentFeedIsProducingSignal: currentFeedIsProducingSignal,
                recordingAlreadyActive: recordingAlreadyActive,
                routingAutomation: routingStatus.automation
            )
        )
    }

    private func applyLiveCaptureListening(
        to state: inout CaptureUIState,
        hardwareMonitor: LiveCaptureHardwareMonitorReading
    ) {
        let facts = makeLiveCaptureFacts(
            devices: state.devices,
            phase: state.phase,
            hardwareMonitor: hardwareMonitor,
            recordingAlreadyActive: state.isRecording || captureService.isRecording || appAudioCaptureService.isWriting
        )
        let decision = LiveCaptureRouteResolver.resolve(facts)
        liveCaptureListening = decision.resolution.snapshot
        lastLiveCaptureKind = decision.resolution.kind
        lastLiveCaptureDeviceID = decision.resolution.sessionDeviceID
        lastLiveCaptureBackend = decision.resolution.backend
        state.listeningState = decision.resolution.listeningState
        state.listeningSummary = decision.resolution.listeningSummary
    }

    private func publishLiveCaptureListening(hardwareMonitor: LiveCaptureHardwareMonitorReading) {
        var next = captureState
        applyLiveCaptureListening(to: &next, hardwareMonitor: hardwareMonitor)
        guard next.listeningState != captureState.listeningState
            || next.listeningSummary != captureState.listeningSummary
        else { return }
        captureState = next
    }

    func armInputCaptureWatching() {
        userDisarmedInputCapture = false
        guard captureState.mode == .inputDevice else { return }
        guard let device = captureState.selectedDevice else {
            var next = captureState
            next.phase = .failed("Choose an audio input device before starting Capture.")
            next.statusMessage = "Choose an audio input device before starting Capture."
            captureState = next
            return
        }
        // Last-line defense: never arm/record from a blocked ambient mic, even if some future
        // path re-introduces one as the selection. The invariant is enforced at selection,
        // at the UI, and here immediately before any audio is captured.
        guard !device.isBlockedInput else {
            var next = captureState
            next.selectedDeviceID = nil
            next.phase = .failed("The built-in microphone can't be used for capture.")
            next.statusMessage = "The built-in microphone can't be used for capture. Choose a DJ mixer, deck, or App audio Capture."
            captureState = next
            statusMessage = "Built-in microphone blocked for capture"
            return
        }
        Task {
            var requesting = captureState
            requesting.phase = .requestingPermission
            requesting.statusMessage = "Requesting microphone access…"
            captureState = requesting
            if !CaptureService.microphonePermissionGranted() {
                let granted = await CaptureService.requestMicrophonePermission()
                guard granted else {
                    var denied = captureState
                    denied.phase = .failed("Microphone access is denied. SetCatcher cannot Capture without it.")
                    denied.statusMessage = "Microphone access is denied. Open System Settings to allow SetCatcher."
                    captureState = denied
                    statusMessage = "Microphone access is denied"
                    return
                }
            }
            do {
                if !captureService.isMonitoring {
                    try captureService.startMonitoring(
                        device: device,
                        prerollSeconds: settings.silenceSessionConfig.prerollSeconds
                    )
                }
                let tick = captureSession.prepareWatching(
                    config: settings.silenceSessionConfig,
                    targetDisplayName: "the \(device.name) input",
                    route: .inputDevice
                )
                var watching = captureState
                watching.phase = tick.phase
                watching.inputLevel = tick.inputLevel
                watching.statusMessage = tick.statusMessage
                captureState = watching
                statusMessage = "Input device Capture armed"
                startInputWatchPolling()
            } catch let error as CaptureServiceError {
                applyCaptureFailure(error)
            } catch {
                var failed = captureState
                failed.phase = .failed(error.localizedDescription)
                failed.statusMessage = error.localizedDescription
                captureState = failed
            }
        }
    }

    func disarmCapture() {
        if captureState.mode == .appAudio {
            disarmAppAudioCapture()
        } else {
            disarmInputCapture()
        }
    }

    func disarmInputCapture() {
        haltInputCapture(markUserDisarmed: true)
        let tick = captureSession.disarm(hasTargets: !captureState.devices.isEmpty)
        var next = captureState
        next.phase = tick.phase
        next.inputLevel = 0
        next.statusMessage = tick.statusMessage
        next.pendingAlternateSource = nil
        captureState = next
        statusMessage = "Input device Capture disarmed"
    }

    /// Switches an already-armed/watching/recording session to the detected alternate app or
    /// device — the only path that ever retargets a live session, and only on explicit user
    /// action (never automatically; see `refreshAppAudioTargets`/`refreshAudioInputs`).
    func switchToPendingAlternateSource() {
        guard let pending = captureState.pendingAlternateSource else { return }
        guard captureState.phase != .recording, captureState.phase != .saving else {
            statusMessage = "Finish the current capture before switching to \(pending.displayName)"
            return
        }
        let current = liveSourceDisplayName ?? "the current source"
        guard CaptureConfirmationAlert.confirmSourceSwitch(from: current, to: pending.displayName) else { return }
        switch pending.kind {
        case .appAudio(let softwareID):
            haltAppAudioCapture(markUserDisarmed: false)
            var next = captureState
            next.pendingAlternateSource = nil
            captureState = next
            selectCaptureTargetApp(softwareID)
            armAppAudioCapture()
        case .inputDevice(let deviceID):
            haltInputCapture(markUserDisarmed: false)
            var next = captureState
            next.pendingAlternateSource = nil
            captureState = next
            selectCaptureDevice(deviceID)
            armInputCaptureWatching()
        }
    }

    /// Keeps the current session running and stops prompting for this particular alternate
    /// (until it goes away and a genuinely new one appears).
    func dismissPendingAlternateSource() {
        guard let pending = captureState.pendingAlternateSource else { return }
        dismissedAlternateSourceIDs.insert(pending.id)
        var next = captureState
        next.pendingAlternateSource = nil
        captureState = next
    }

    private func haltAppAudioCapture(markUserDisarmed: Bool) {
        if markUserDisarmed {
            userDisarmedAppAudio = true
        }
        appAudioPollTask?.cancel()
        appAudioPollTask = nil
        var next = captureState
        next.appAudioSourceName = nil
        captureState = next
        Task {
            if appAudioCaptureService.isWriting {
                _ = try? appAudioCaptureService.endRecordingFile(discard: true)
            }
            await appAudioCaptureService.stopMonitoring()
        }
    }

    private func haltInputCapture(markUserDisarmed: Bool) {
        if markUserDisarmed {
            userDisarmedInputCapture = true
        }
        captureMeterTask?.cancel()
        captureMeterTask = nil
        captureService.stopMonitoring()
        captureSession = CaptureSessionCoordinator(config: settings.silenceSessionConfig)
    }

    private func startInputWatchPolling() {
        captureMeterTask?.cancel()
        captureMeterTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 100_000_000)
                await MainActor.run {
                    guard let self else { return }
                    guard self.captureState.mode == .inputDevice else { return }
                    guard self.captureState.phase == .watching || self.captureState.phase == .recording else { return }
                    let level = self.captureService.currentInputLevel()
                    let tick = self.captureSession.tick(level: level)
                    self.applyInputCaptureSessionTick(tick)
                    self.refreshCaptureStagingBytes()
                }
            }
        }
    }

    private func applyInputCaptureSessionTick(_ tick: CaptureSessionTick) {
        var next = captureState
        if !tick.statusMessage.isEmpty {
            next.statusMessage = tick.statusMessage
        }
        next.phase = tick.phase
        next.inputLevel = tick.inputLevel
        applyLiveCaptureListening(
            to: &next,
            hardwareMonitor: LiveCaptureHardwareMonitorReading(
                monitoredDeviceID: captureState.selectedDeviceID,
                level: tick.inputLevel,
                observing: captureService.isMonitoring
            )
        )
        captureState = next

        guard let action = tick.engineAction else { return }
        switch action {
        case .beginRecordingFile:
            do {
                try captureService.beginRecordingFile()
                let now = Date()
                let displayName = captureState.selectedDevice?.name ?? "input"
                if settings.notifyAfterArchiving {
                    notificationService.notifyCaptureStarted(displayName: displayName, at: now)
                }
                statusMessage = LocalNotificationService.captureStartedBody(displayName: displayName, at: now)
            } catch let error as CaptureServiceError {
                applyCaptureFailure(error)
            } catch {
                var failed = captureState
                failed.phase = .failed(error.localizedDescription)
                failed.statusMessage = error.localizedDescription
                captureState = failed
            }
        case .endRecordingFile(let discard):
            finalizeInputCaptureSession(discard: discard, resumeWatching: true)
        }
    }

    private func finalizeInputCaptureSession(discard: Bool, resumeWatching: Bool) {
        var saving = captureState
        saving.phase = .saving
        saving.statusMessage = discard ? "Discarding short take…" : "Saving capture into your archive…"
        captureState = saving
        do {
            let result = try captureService.endRecordingFile(discard: discard)
            if let result, !discard {
                stagePendingCaptureRecovery(
                    result,
                    sourceAppID: SupportedDJSoftware.captureAppID,
                    route: result.captureRoute ?? .inputDevice,
                    backend: result.captureBackend,
                    transport: result.deviceTransport?.archiveLabel
                )
                let session = try ingestPendingCaptureRecovery()
                notifyForNewArchive(session)
                refresh()
                autopullTracklist(for: session)
                var done = captureState
                done.lastArchivedSessionID = session.id
                if resumeWatching {
                    let tick = captureSession.resumeWatchingAfterSave(
                        discarded: false,
                        minDurationSeconds: TimeInterval(settings.appAudioMinDurationSeconds),
                        level: captureService.currentInputLevel()
                    )
                    done.phase = tick.phase
                    done.inputLevel = tick.inputLevel
                    done.statusMessage = tick.statusMessage
                    startInputWatchPolling()
                } else {
                    haltInputCapture(markUserDisarmed: true)
                    let tick = captureSession.disarm(hasTargets: !captureState.devices.isEmpty)
                    done.phase = tick.phase
                    done.inputLevel = 0
                    done.statusMessage = tick.statusMessage
                }
                captureState = done
                statusMessage = "Capture saved"
            } else if resumeWatching {
                let tick = captureSession.resumeWatchingAfterSave(
                    discarded: true,
                    minDurationSeconds: TimeInterval(settings.appAudioMinDurationSeconds),
                    level: captureService.currentInputLevel()
                )
                var done = captureState
                done.phase = tick.phase
                done.inputLevel = tick.inputLevel
                done.statusMessage = tick.statusMessage
                captureState = done
                startInputWatchPolling()
            } else {
                haltInputCapture(markUserDisarmed: true)
                let tick = captureSession.disarm(hasTargets: !captureState.devices.isEmpty)
                var done = captureState
                done.phase = tick.phase
                done.inputLevel = 0
                done.statusMessage = tick.statusMessage
                captureState = done
            }
        } catch let error as CaptureServiceError {
            applyCaptureFailure(error)
        } catch {
            var failed = captureState
            failed.phase = .failed(error.localizedDescription)
            failed.statusMessage = error.localizedDescription
            captureState = failed
            statusMessage = "Could not save capture: \(error.localizedDescription)"
        }
    }

    func startCapture() {
        guard captureState.mode == .inputDevice else {
            armAppAudioCapture()
            return
        }
        refreshAudioInputs()
        guard let device = captureState.selectedDevice else {
            var next = captureState
            next.phase = .failed("Choose an audio input device before starting Capture.")
            next.statusMessage = "Choose an audio input device before starting Capture."
            captureState = next
            return
        }
        // Last-line defense, same as armInputCaptureWatching(): never record from a blocked mic.
        guard !device.isBlockedInput else {
            var next = captureState
            next.selectedDeviceID = nil
            next.phase = .failed("The built-in microphone can't be used for capture.")
            next.statusMessage = "The built-in microphone can't be used for capture. Choose a DJ mixer, deck, or App audio Capture."
            captureState = next
            statusMessage = "Built-in microphone blocked for capture"
            return
        }
        Task {
            var requesting = captureState
            requesting.phase = .requestingPermission
            requesting.statusMessage = "Requesting microphone access…"
            captureState = requesting
            if !CaptureService.microphonePermissionGranted() {
                let granted = await CaptureService.requestMicrophonePermission()
                guard granted else {
                    var denied = captureState
                    denied.phase = .failed("Microphone access is denied. SetCatcher cannot Capture without it.")
                    denied.statusMessage = "Microphone access is denied. Open System Settings to allow SetCatcher."
                    captureState = denied
                    statusMessage = "Microphone access is denied"
                    return
                }
            }
            do {
                try captureService.start(device: device)
                var recording = captureState
                recording.phase = .recording
                recording.inputLevel = 0
                recording.statusMessage = "Capturing from \(device.name)…"
                captureState = recording
                statusMessage = "Capture started"
                captureMeterTask?.cancel()
                captureMeterTask = Task { [weak self] in
                    while !Task.isCancelled {
                        try? await Task.sleep(nanoseconds: 100_000_000)
                        await MainActor.run {
                            guard let self, self.captureState.isRecording else { return }
                            var next = self.captureState
                            next.inputLevel = self.captureService.currentInputLevel()
                            self.captureState = next
                        }
                    }
                }
            } catch let error as CaptureServiceError {
                applyCaptureFailure(error)
            } catch {
                var failed = captureState
                failed.phase = .failed(error.localizedDescription)
                failed.statusMessage = error.localizedDescription
                captureState = failed
            }
        }
    }

    func requestStopCapture() {
        guard captureState.phase == .recording else {
            stopCapture()
            return
        }
        guard CaptureConfirmationAlert.confirmStopCapture() else { return }
        stopCapture(resumeWatching: true)
    }

    func requestStopAndDisarmCapture() {
        guard captureState.phase == .recording else {
            disarmCapture()
            return
        }
        guard CaptureConfirmationAlert.confirmStopAndDisarm() else { return }
        stopCapture(resumeWatching: false)
    }

    func requestDisarmCapture() {
        if captureState.phase == .recording {
            requestStopAndDisarmCapture()
            return
        }
        disarmCapture()
    }

    func startCaptureNow() {
        guard captureState.phase == .watching else { return }
        let level = currentCaptureInputLevel()
        guard let tick = captureSession.requestManualStart(level: level) else { return }
        if captureState.mode == .appAudio {
            applyCaptureSessionTick(tick)
        } else {
            applyInputCaptureSessionTick(tick)
        }
    }

    func toggleArmFromShortcut() {
        switch captureState.phase {
        case .recording:
            requestStopAndDisarmCapture()
        case .watching:
            requestDisarmCapture()
        case .armed, .idle:
            if captureState.mode == .appAudio {
                armAppAudioCapture()
            } else if captureState.selectedDevice != nil {
                armInputCaptureWatching()
            }
        default:
            break
        }
    }

    private func currentCaptureInputLevel() -> Float {
        if captureState.mode == .appAudio {
            return appAudioCaptureService.currentInputLevel()
        }
        return captureService.currentInputLevel()
    }

    func stopCapture(resumeWatching: Bool = true) {
        if captureState.mode == .appAudio {
            switch captureState.phase {
            case .saving:
                // Ignore double Stop while archive ingest is in progress.
                return
            case .recording:
                let tick = captureSession.requestManualSave()
                var saving = captureState
                saving.phase = tick.phase
                saving.statusMessage = tick.statusMessage
                captureState = saving
                finalizeAppAudioSession(discard: false, resumeWatching: resumeWatching)
                if resumeWatching, appAudioCaptureService.isMonitoring {
                    startAppAudioPolling()
                }
            default:
                disarmAppAudioCapture()
            }
            return
        }
        captureMeterTask?.cancel(); captureMeterTask = nil
        if captureSession.currentPhase == .recording || captureState.phase == .watching {
            if captureState.phase == .watching {
                disarmInputCapture()
                return
            }
            let tick = captureSession.requestManualSave()
            var saving = captureState
            saving.phase = tick.phase
            saving.statusMessage = tick.statusMessage
            captureState = saving
            finalizeInputCaptureSession(discard: false, resumeWatching: resumeWatching)
            return
        }
        var saving = captureState
        saving.phase = .saving
        saving.statusMessage = "Saving capture into your archive…"
        captureState = saving
        do {
            let result = try captureService.stop()
            let session = try archiveService().ingestCapture(
                stagingURL: result.stagingURL,
                deviceID: result.deviceID,
                deviceName: result.deviceName,
                startedAt: result.startedAt,
                endedAt: result.endedAt,
                captureRoute: result.captureRoute ?? .inputDevice,
                captureDeviceTransport: result.deviceTransport?.archiveLabel
            )
            notifyForNewArchive(session)
            refresh()
            autopullTracklist(for: session)
            var done = captureState
            done.phase = .armed
            done.inputLevel = 0
            done.lastArchivedSessionID = session.id
            done.statusMessage = "Capture saved. Import a tracklist from Set Detail when you have an export."
            captureState = done
            statusMessage = "Capture saved"
        } catch let error as CaptureServiceError {
            applyCaptureFailure(error)
        } catch {
            var failed = captureState
            failed.phase = .failed(error.localizedDescription)
            failed.statusMessage = error.localizedDescription
            captureState = failed
            statusMessage = "Could not save capture: \(error.localizedDescription)"
        }
    }

    func openMicrophonePrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }

    func openScreenRecordingPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    func setCloudSyncEnabled(_ enabled: Bool) {
        let newSettings = settings.updating(cloudSyncEnabled: enabled, cloudArchiveBackupEnabled: enabled ? settings.cloudArchiveBackupEnabled : false)
        try? appSettingsStore.save(newSettings)
        settings = newSettings
        statusMessage = enabled ? "Cloud sync is on. Archive backup stays off until you enable it." : "Cloud sync is off. Everything stays on this Mac."
    }

    func setCloudArchiveBackupEnabled(_ enabled: Bool) {
        guard settings.cloudSyncEnabled || !enabled else {
            statusMessage = "Turn on cloud sync before enabling archive backup."
            return
        }
        let newSettings = settings.updating(cloudArchiveBackupEnabled: enabled)
        try? appSettingsStore.save(newSettings)
        settings = newSettings
        statusMessage = enabled ? "Archive backup is opted in. SetCatcher will never upload audio automatically." : "Archive backup is off."
    }

    func exportPublishPack(sessionID: UUID) {
        guard let summary = librarySummaries.first(where: { $0.id == sessionID }) else {
            statusMessage = "Select an archived set before exporting a publish pack."
            return
        }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Export"
        panel.message = "Choose a folder for the local publish pack. Nothing is uploaded."
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        do {
            let packURL = try PublishExportService().exportPack(archive: summary.archive, tracklist: summary.matchedTracklist, destinationDirectory: destination)
            NSWorkspace.shared.activateFileViewerSelecting([packURL])
            statusMessage = "Publish pack exported"
        } catch {
            statusMessage = "Could not export publish pack: \(error.localizedDescription)"
        }
    }

    func runVirtualDJNetworkCommand(_ command: VirtualDJNetworkCommand) {
        guard !isCheckingVirtualDJNetwork else { return }
        isCheckingVirtualDJNetwork = true
        Task {
            let result = await VirtualDJNetworkClient().run(command: command)
            await MainActor.run {
                virtualDJNetworkCommandResult = result
                isCheckingVirtualDJNetwork = false
                statusMessage = result.reachable ? "VirtualDJ Network Control command succeeded" : "VirtualDJ Network Control command failed"
            }
        }
    }

    private func applyCaptureFailure(_ error: CaptureServiceError) {
        let message: String
        switch error {
        case .permissionDenied: message = "Microphone access is denied. Open System Settings to allow SetCatcher."
        case .deviceMissing: message = "The selected audio input is missing. Refresh devices and try again."
        case .diskFull: message = "This Mac is out of disk space. Free space, then Capture again."
        case .engineFailed(let detail): message = "Capture engine failed: \(detail)"
        case .alreadyRecording: message = "Capture is already running."
        case .notRecording: message = "Capture is not running."
        }
        var failed = captureState
        failed.phase = .failed(message)
        failed.inputLevel = 0
        failed.statusMessage = message
        captureState = failed
        statusMessage = message
    }

    private func applyAppAudioCaptureFailure(_ error: AppAudioCaptureError) {
        appAudioPollTask?.cancel()
        appAudioPollTask = nil
        let message: String
        let phase: CapturePhase
        switch error {
        case .permissionDenied:
            message = "System Audio Recording permission is required. Open System Settings to allow SetCatcher, then return here and Arm again. Folder Protection and Input device Capture still work."
            phase = .needsScreenRecordingPermission
        case .appNotShareable(let name):
            message = "\(name) is not available to app-audio capture right now. Open the DJ app, refresh targets, or use Input device Capture / folder Protection if audio is routed only to hardware."
            phase = .failed(message)
        case .noDisplay:
            message = "No display is available for App audio Capture."
            phase = .failed(message)
        case .diskFull:
            message = "This Mac is out of disk space. Free space, then arm App audio Capture again."
            phase = .failed(message)
        case .engineFailed(let detail):
            message = "App audio Capture failed: \(detail)"
            phase = .failed(message)
        case .streamStopped(let detail):
            message = "App audio Capture stopped: \(detail). Retry to resume watching. Folder Protection still works."
            phase = .armed
        case .alreadyMonitoring:
            message = "App audio Capture is already armed."
            phase = .watching
        case .notMonitoring:
            message = "App audio Capture is not armed."
            phase = .armed
        case .alreadyWriting:
            message = "An app audio session is already recording."
            phase = .recording
        case .notWriting:
            message = "No app audio session is recording."
            phase = .watching
        }
        var failed = captureState
        if case .permissionDenied = error {
            failed.targetApps = []
        }
        failed.phase = phase
        failed.inputLevel = 0
        failed.statusMessage = message
        if case .streamStopped = error {
            failed.listeningState = .recoveryNeeded
            failed.listeningSummary = message
        }
        captureState = failed
        statusMessage = message
        switch error {
        case .alreadyMonitoring, .alreadyWriting, .notWriting, .streamStopped:
            break
        default:
            Task { await appAudioCaptureService.stopMonitoring() }
        }
    }

    private func applyInterruptedAppAudioCapture(_ result: CaptureResult, error: AppAudioCaptureError) {
        let reason: String
        if case .streamStopped(let detail) = error {
            reason = detail
        } else {
            reason = error.localizedDescription
        }
        saveInterruptedAppAudioCapture(result, reason: reason)
    }

    private func saveInterruptedAppAudioCapture(_ result: CaptureResult, reason: String) {
        var saving = captureState
        saving.phase = .saving
        saving.statusMessage = "Saving interrupted take…"
        captureState = saving
        do {
            let session = try archiveService().ingestCapture(
                stagingURL: result.stagingURL,
                deviceID: result.deviceID,
                deviceName: result.deviceName,
                startedAt: result.startedAt,
                endedAt: result.endedAt,
                sourceAppID: captureState.selectedTargetApp?.software.id ?? SupportedDJSoftware.captureAppID,
                captureRoute: result.captureRoute ?? .appAudio,
                captureBackend: result.captureBackend ?? appAudioCaptureService.activeBackendKind.archiveBackend,
                captureDeviceTransport: result.deviceTransport?.archiveLabel
                    ?? appAudioCaptureService.activeVirtualDevice?.transportType.archiveLabel,
                captureInterrupted: true,
                captureInterruptionReason: reason
            )
            notifyForNewArchive(session)
            refresh()
            var done = captureState
            done.phase = .armed
            done.listeningState = .recoveryNeeded
            done.listeningSummary = "App audio stream stopped. Retry to resume watching."
            done.lastArchivedSessionID = session.id
            done.statusMessage = "Interrupted take saved to your archive."
            captureState = done
            statusMessage = done.statusMessage
        } catch {
            var failed = captureState
            failed.phase = .armed
            failed.listeningState = .recoveryNeeded
            failed.listeningSummary = "App audio stream stopped. Retry to resume watching."
            failed.statusMessage = "Could not save interrupted take: \(error.localizedDescription)"
            captureState = failed
        }
        appAudioPollTask?.cancel()
        appAudioPollTask = nil
    }
}

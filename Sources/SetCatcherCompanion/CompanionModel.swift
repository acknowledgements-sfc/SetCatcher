import AVFoundation
import Foundation
import SetCatcherCore
import Observation
#if canImport(UIKit)
import UIKit
#endif

/// iPad view-model. Standalone local archive/import; optional account only. No Mac connection.
@MainActor
@Observable
public final class CompanionModel {
    public enum Route: String, CaseIterable, Identifiable {
        case library
        case importSets
        case capture
        case settings

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .library: return "Library"
            case .importSets: return "Import"
            case .capture: return "Capture"
            case .settings: return "Settings"
            }
        }

        public var systemImage: String {
            switch self {
            case .library: return "rectangle.stack"
            case .importSets: return "square.and.arrow.down"
            case .capture: return "waveform"
            case .settings: return "gearshape"
            }
        }
    }

    public enum StatusKind: Equatable, Sendable {
        case importIdle
        case importing
        case library
        case capture
        case account
    }

    public static let importIdleMessage = "Choose recordings to import. Source files are copied, never moved."

    public var selectedRoute: Route = .library
    public var sessions: [ArchiveMetadata] = []
    public var setContexts: [UUID: SetContext] = [:]
    public var remoteCatalogSessions: [ArchiveCatalogSessionDTO] = []
    public var statusMessage = CompanionModel.importIdleMessage
    public var statusKind: StatusKind = .importIdle
    public var isImporting = false
    public var isCapturing = false
    public var captureElapsedSeconds: Int = 0
    public var selectedInputID: String?
    public var accountLicenseSummary: String?
    public var accountSyncMessage: String?

    private let paths = DefaultPathProvider()
    private let setContextStore = SetContextStore()
    private let captureService = CaptureService()
    private var captureTimer: Timer?
    private var localSessions: [ArchiveMetadata] = []
    private var accountBearerToken: String?

    public var archiveRoot: URL { paths.defaultArchiveRoot() }

    public var audioInputs: [AudioInputDevice] {
        AudioInputDeviceCatalog.listInputs()
    }

    public var selectableAudioInputs: [AudioInputDevice] {
        AudioInputDeviceCatalog.selectableInputs(from: audioInputs)
    }

    public init() {
        selectedInputID = AudioInputDeviceCatalog.preferredDefault()?.id
        refresh()
    }

    public func setStatus(_ message: String, kind: StatusKind) {
        statusMessage = message
        statusKind = kind
    }

    public func refresh() {
        do {
            try ArchiveService(archiveRoot: archiveRoot).ensureArchiveRootExists()
            localSessions = try SessionLibrary(archiveRoot: archiveRoot).archivedMetadata()
            setContexts = Dictionary(
                uniqueKeysWithValues: (try setContextStore.all()).map { ($0.sessionID, $0) }
            )
            applyDisplayedSessions()
        } catch {
            setStatus("Could not load library: \(error.localizedDescription). Tap Import to add a recording.", kind: .library)
            localSessions = []
            sessions = []
        }
    }

    private func applyDisplayedSessions() {
        sessions = ArchiveCatalogMerger().mergedArchives(
            localArchives: localSessions,
            remoteSessions: remoteCatalogSessions
        )
    }

    public func catalogAvailability(for sessionID: UUID) -> ArchiveCatalogAvailability {
        let hasLocal = localSessions.contains { $0.sessionID == sessionID }
        return ArchiveCatalogMerger().catalogAvailability(
            for: sessionID,
            hasLocalFile: hasLocal,
            remoteSessions: remoteCatalogSessions
        )
    }

    public func context(for sessionID: UUID) -> SetContext {
        setContexts[sessionID] ?? SetContext(sessionID: sessionID)
    }

    public func saveContext(_ context: SetContext) {
        do {
            try setContextStore.save(context)
            setContexts[context.sessionID] = context
            setStatus("Saved set details on this device", kind: .library)
            pushArchiveCatalogIfNeeded()
        } catch {
            setStatus("Could not save set details: \(error.localizedDescription)", kind: .library)
        }
    }

    /// Copy user-selected audio into the local archive. Sources are never moved or deleted.
    public func importAudioURLs(_ urls: [URL], appID: String = MobileDJSoftware.djay.id) {
        guard !urls.isEmpty else { return }
        isImporting = true
        defer {
            isImporting = false
            refresh()
        }

        var imported = 0
        var failures: [String] = []
        let archiveService = ArchiveService(archiveRoot: archiveRoot)

        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer {
                if scoped { url.stopAccessingSecurityScopedResource() }
            }

            do {
                _ = try archiveService.archive(sourceURL: url, sourceAppID: appID)
                imported += 1
            } catch {
                failures.append("\(url.lastPathComponent): \(error.localizedDescription)")
            }
        }

        if imported > 0 && failures.isEmpty {
            setStatus("Imported \(imported) recording\(imported == 1 ? "" : "s"). Sources were copied, not moved.", kind: .importing)
            selectedRoute = .library
            pushArchiveCatalogIfNeeded()
        } else if imported > 0 {
            setStatus("Imported \(imported). Some failed: \(failures.joined(separator: "; "))", kind: .importing)
        } else {
            setStatus("Import failed. \(failures.first ?? "Choose a different file and try again.")", kind: .importing)
        }
    }

    public func startCapture() async {
        var granted = CaptureService.microphonePermissionGranted()
        if !granted {
            granted = await CaptureService.requestMicrophonePermission()
        }
        guard granted else {
            setStatus("Microphone access is off. Enable it in Settings, then try Capture again.", kind: .capture)
            return
        }

        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
        } catch {
            setStatus("Could not configure audio session: \(error.localizedDescription)", kind: .capture)
            return
        }
        #endif

        guard let device = selectableAudioInputs.first(where: { $0.id == selectedInputID })
                ?? AudioInputDeviceCatalog.preferredDefault(from: selectableAudioInputs) else {
            setStatus("No audio input found. Plug in an interface or allow microphone access, then try again.", kind: .capture)
            return
        }

        do {
            try captureService.start(device: device)
            selectedInputID = device.id
            isCapturing = true
            captureElapsedSeconds = 0
            captureTimer?.invalidate()
            captureTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.captureElapsedSeconds += 1
                }
            }
            setStatus("Capturing on this device. Stop when the set ends; the copy is archived locally.", kind: .capture)
        } catch {
            setStatus("Could not start capture: \(error.localizedDescription)", kind: .capture)
            isCapturing = false
        }
    }

    public func stopCaptureAndArchive() {
        captureTimer?.invalidate()
        captureTimer = nil
        isCapturing = false

        do {
            let result = try captureService.stop()
            _ = try ArchiveService(archiveRoot: archiveRoot).ingestCapture(
                stagingURL: result.stagingURL,
                deviceID: result.deviceID,
                deviceName: result.deviceName,
                startedAt: result.startedAt,
                endedAt: result.endedAt,
                sourceAppID: MobileDJSoftware.capture.id,
                removeStagingAfterCopy: true
            )
            refresh()
            setStatus("Capture archived on this device. Staging was removed after a successful copy.", kind: .capture)
            selectedRoute = .library
            pushArchiveCatalogIfNeeded()
        } catch {
            setStatus("Capture finished but archive failed: \(error.localizedDescription). Check Documents for a staging file.", kind: .capture)
        }
    }

    public func syncAccount(bearerToken: String?) async {
        guard let bearerToken, !bearerToken.isEmpty else {
            accountBearerToken = nil
            accountLicenseSummary = nil
            accountSyncMessage = nil
            remoteCatalogSessions = []
            applyDisplayedSessions()
            return
        }

        accountBearerToken = bearerToken

        do {
            #if canImport(UIKit)
            let device = UIDevice.current.name
            let platformDeviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
            #else
            let device = ProcessInfo.processInfo.hostName
            let platformDeviceId = device
            #endif
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            _ = try await CompanionAccountClient.registerDevice(
                bearerToken: bearerToken,
                deviceName: device,
                appVersion: version,
                installChannel: "ipad",
                platformDeviceId: platformDeviceId
            )
            let license = try await CompanionAccountClient.fetchLicense(bearerToken: bearerToken)
            accountLicenseSummary = "\(license.license.plan) · \(license.license.status)"
            accountSyncMessage = license.localFeatures.note
            setStatus("Account connected — library and import still work offline", kind: .account)
            await syncArchiveCatalog(bearerToken: bearerToken)
        } catch {
            accountLicenseSummary = accountLicenseSummary ?? "Unavailable (local features full)"
            accountSyncMessage = "Could not reach the account server. Local library is unchanged."
        }
    }

    private func syncArchiveCatalog(bearerToken: String) async {
        let client = ArchiveCatalogHTTPClient()
        do {
            let pull = try await client.pullSessions(bearerToken: bearerToken)
            remoteCatalogSessions = pull.sessions
            applyRemoteCatalogContexts(pull.sessions)

            #if canImport(UIKit)
            let deviceName = UIDevice.current.name
            #else
            let deviceName = "iPad"
            #endif
            let dtos = localSessions.map { archive in
                ArchiveCatalogMapper.dto(
                    from: archive,
                    context: setContexts[archive.sessionID],
                    platform: .ios,
                    originDeviceName: deviceName
                )
            }
            if !dtos.isEmpty {
                _ = try await client.pushSessions(bearerToken: bearerToken, sessions: dtos)
            }

            applyDisplayedSessions()
            accountSyncMessage =
                "Library catalog synced across your devices. Audio stays on this device unless you enable backup later."
        } catch {
            accountSyncMessage =
                "Could not sync the library catalog: \(error.localizedDescription). Local archives are unchanged."
        }
    }

    private func pushArchiveCatalogIfNeeded() {
        guard let accountBearerToken else { return }
        Task { await syncArchiveCatalog(bearerToken: accountBearerToken) }
    }

    private func applyRemoteCatalogContexts(_ remoteSessions: [ArchiveCatalogSessionDTO]) {
        for remote in remoteSessions {
            guard let remoteContext = remote.setContext else { continue }
            let incoming = ArchiveCatalogMapper.setContext(from: remoteContext, sessionID: remote.sessionId)
            let existing = setContexts[remote.sessionId] ?? SetContext(sessionID: remote.sessionId)
            guard incoming.updatedAt > existing.updatedAt else { continue }
            try? setContextStore.save(incoming)
            setContexts[remote.sessionId] = incoming
        }
    }
}

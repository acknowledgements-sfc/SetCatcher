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

    public var selectedRoute: Route = .library
    public var sessions: [ArchiveMetadata] = []
    public var setContexts: [UUID: SetContext] = [:]
    public var statusMessage = "Choose recordings to import. Source files are copied, never moved."
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

    public var archiveRoot: URL { paths.defaultArchiveRoot() }

    public var audioInputs: [AudioInputDevice] {
        AudioInputDeviceCatalog.listInputs()
    }

    public init() {
        selectedInputID = AudioInputDeviceCatalog.preferredDefault()?.id
        refresh()
    }

    public func refresh() {
        do {
            try ArchiveService(archiveRoot: archiveRoot).ensureArchiveRootExists()
            sessions = try SessionLibrary(archiveRoot: archiveRoot).archivedMetadata()
            setContexts = Dictionary(
                uniqueKeysWithValues: (try setContextStore.all()).map { ($0.sessionID, $0) }
            )
        } catch {
            statusMessage = "Could not load library: \(error.localizedDescription). Tap Import to add a recording."
            sessions = []
        }
    }

    public func context(for sessionID: UUID) -> SetContext {
        setContexts[sessionID] ?? SetContext(sessionID: sessionID)
    }

    public func saveContext(_ context: SetContext) {
        do {
            try setContextStore.save(context)
            setContexts[context.sessionID] = context
            statusMessage = "Saved set details on this iPad"
        } catch {
            statusMessage = "Could not save set details: \(error.localizedDescription)"
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
            statusMessage = "Imported \(imported) recording\(imported == 1 ? "" : "s"). Sources were copied, not moved."
            selectedRoute = .library
        } else if imported > 0 {
            statusMessage = "Imported \(imported). Some failed: \(failures.joined(separator: "; "))"
        } else {
            statusMessage = "Import failed. \(failures.first ?? "Choose a different file and try again.")"
        }
    }

    public func startCapture() async {
        var granted = CaptureService.microphonePermissionGranted()
        if !granted {
            granted = await CaptureService.requestMicrophonePermission()
        }
        guard granted else {
            statusMessage = "Microphone access is off. Enable it in Settings, then try Capture again."
            return
        }

        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
        } catch {
            statusMessage = "Could not configure audio session: \(error.localizedDescription)"
            return
        }
        #endif

        guard let device = audioInputs.first(where: { $0.id == selectedInputID })
                ?? AudioInputDeviceCatalog.preferredDefault() else {
            statusMessage = "No audio input found. Plug in an interface or allow microphone access, then try again."
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
            statusMessage = "Capturing on this iPad. Stop when the set ends; the copy is archived locally."
        } catch {
            statusMessage = "Could not start capture: \(error.localizedDescription)"
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
            statusMessage = "Capture archived on this iPad. Staging was removed after a successful copy."
            selectedRoute = .library
        } catch {
            statusMessage = "Capture finished but archive failed: \(error.localizedDescription). Check Documents for a staging file."
        }
    }

    public func syncAccount(bearerToken: String?) async {
        guard let bearerToken, !bearerToken.isEmpty else {
            accountLicenseSummary = nil
            accountSyncMessage = nil
            return
        }

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
            statusMessage = "Account connected — library and import still work offline"
        } catch {
            accountLicenseSummary = accountLicenseSummary ?? "Unavailable (local features full)"
            accountSyncMessage = "Could not reach the account server. Local library is unchanged."
        }
    }
}

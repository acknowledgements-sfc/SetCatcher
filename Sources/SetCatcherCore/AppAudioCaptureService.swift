#if os(macOS)
import AVFoundation
import AppKit
import CoreAudio
import CoreGraphics
import CoreMedia
import Foundation
import ScreenCaptureKit

public enum AppAudioCaptureError: Error, Equatable, Sendable {
    case permissionDenied
    case appNotShareable(String)
    case noDisplay
    case alreadyMonitoring
    case notMonitoring
    case alreadyWriting
    case notWriting
    case engineFailed(String)
    case diskFull
    case streamStopped(String)
}

public protocol AppAudioCaptureBackend: AnyObject, Sendable {
    var backendKind: AppAudioCaptureBackendKind { get }
    var isMonitoring: Bool { get }
    var isWriting: Bool { get }
    var sourceDeviceUID: String? { get }
    var onStreamStopped: ((AppAudioCaptureError) -> Void)? { get set }
    var onInterruptedCapture: ((CaptureResult, AppAudioCaptureError) -> Void)? { get set }

    func listShareableDJApps() async throws -> [MatchedDJApp]
    func startMonitoring(bundleIdentifier: String, displayName: String, prerollSeconds: TimeInterval) async throws
    func stopMonitoring() async
    func beginRecordingFile() throws
    func endRecordingFile(discard: Bool) throws -> CaptureResult?
    func currentInputLevel() -> Float
    /// Byte size of the in-progress staging WAV while writing; nil when not recording.
    func currentStagingByteCount() -> Int64?
}

/// Chosen App Audio engine, including the bound virtual device when that path wins.
public enum AppAudioCaptureBackendSelection: Equatable, Sendable {
    case virtualInputDevice(device: AudioInputDevice, softwareID: String)
    case processAudioTap
    case screenCaptureKit

    public var kind: AppAudioCaptureBackendKind {
        switch self {
        case .virtualInputDevice: return .virtualInputDevice
        case .processAudioTap: return .processAudioTap
        case .screenCaptureKit: return .screenCaptureKit
        }
    }
}

public enum AppAudioCaptureBackendSelector {
    /// Tap vs ScreenCaptureKit only. Virtual-device selection is `preferredSelection(...)`.
    public static func preferredBackend(
        processTapSupported: Bool,
        forceScreenCaptureKit: Bool = ProcessInfo.processInfo.environment["SETCATCHER_FORCE_SCK_APP_AUDIO"] == "1"
    ) -> AppAudioCaptureBackendKind {
        if processTapSupported && !forceScreenCaptureKit {
            return .processAudioTap
        }
        return .screenCaptureKit
    }

    /// SAFETY GATE: virtual-device capture remains opt-in while the reported long-running OOM
    /// regression is investigated. Set `SETCATCHER_ENABLE_VIRTUAL_APP_AUDIO=1` only for guarded
    /// verification; the default falls back to Process Audio Tap / ScreenCaptureKit.
    public static var virtualAppAudioEnabled: Bool {
        virtualAppAudioEnabled(environment: ProcessInfo.processInfo.environment)
    }

    static func virtualAppAudioEnabled(environment: [String: String]) -> Bool {
        environment["SETCATCHER_ENABLE_VIRTUAL_APP_AUDIO"] == "1"
    }

    /// Precedence: Process Audio Tap > ScreenCaptureKit. Vendor input is attempted only after
    /// both Apple paths fail at arm time (`startMonitoring`), not during route selection.
    public static func preferredSelection(
        targetSoftware: DJSoftware?,
        inputDevices: [AudioInputDevice],
        runningSoftwareIDs: Set<String>,
        processTapSupported: Bool,
        forceScreenCaptureKit: Bool = ProcessInfo.processInfo.environment["SETCATCHER_FORCE_SCK_APP_AUDIO"] == "1",
        virtualEnabled: Bool = AppAudioCaptureBackendSelector.virtualAppAudioEnabled
    ) -> AppAudioCaptureBackendSelection {
        _ = targetSoftware
        _ = inputDevices
        _ = runningSoftwareIDs
        _ = virtualEnabled
        switch preferredBackend(
            processTapSupported: processTapSupported,
            forceScreenCaptureKit: forceScreenCaptureKit
        ) {
        case .processAudioTap:
            return .processAudioTap
        case .screenCaptureKit, .virtualInputDevice:
            return .screenCaptureKit
        }
    }

    /// Virtual bind failure still falls back to Apple paths during arm, not route selection.
    public static func fallbackAfterVirtualBindFailure(
        processTapSupported: Bool,
        forceScreenCaptureKit: Bool = ProcessInfo.processInfo.environment["SETCATCHER_FORCE_SCK_APP_AUDIO"] == "1"
    ) -> AppAudioCaptureBackendSelection {
        switch preferredBackend(
            processTapSupported: processTapSupported,
            forceScreenCaptureKit: forceScreenCaptureKit
        ) {
        case .processAudioTap:
            return .processAudioTap
        case .screenCaptureKit, .virtualInputDevice:
            return .screenCaptureKit
        }
    }

    /// After Process Tap and ScreenCaptureKit both fail, an opt-in vendor virtual device may bind.
    public static func vendorFallbackSelection(
        targetSoftware: DJSoftware?,
        inputDevices: [AudioInputDevice],
        runningSoftwareIDs: Set<String>,
        virtualEnabled: Bool = AppAudioCaptureBackendSelector.virtualAppAudioEnabled
    ) -> AppAudioCaptureBackendSelection? {
        guard virtualEnabled,
              let target = targetSoftware,
              runningSoftwareIDs.contains(target.id),
              let device = AudioInputDeviceCatalog.virtualAudioDevice(for: target, in: inputDevices)
        else { return nil }
        return .virtualInputDevice(device: device, softwareID: target.id)
    }
}

/// Facade for app-audio capture. Process Audio Tap first, then
/// ScreenCaptureKit, then opt-in vendor virtual input after both Apple paths fail.
public final class AppAudioCaptureService: @unchecked Sendable {
    public private(set) var activeBackendKind: AppAudioCaptureBackendKind = .screenCaptureKit
    public private(set) var activeVirtualDevice: AudioInputDevice?
    public private(set) var virtualBindDidFallBack = false
    public private(set) var appleAppAudioPathExhausted = false
    public private(set) var activeSourceDeviceUID: String?

    public var isMonitoring: Bool { activeBackend.isMonitoring }
    public var isWriting: Bool { activeBackend.isWriting }
    public var onStreamStopped: ((AppAudioCaptureError) -> Void)? {
        didSet { configureCallbacks() }
    }
    public var onInterruptedCapture: ((CaptureResult, AppAudioCaptureError) -> Void)? {
        didSet { configureCallbacks() }
    }

    public var captureSourceDisplayName: String {
        if activeBackendKind == .virtualInputDevice {
            return activeVirtualDevice?.name ?? AppAudioCaptureBackendKind.virtualInputDevice.displayName
        }
        return activeBackendKind.displayName
    }

    private let processTapBackend: any AppAudioCaptureBackend
    private let screenCaptureBackend: any AppAudioCaptureBackend
    private let virtualBackend: any VirtualInputAppAudioCaptureBackend
    private let microphonePermissionGranted: () -> Bool
    private var activeBackend: any AppAudioCaptureBackend

    public init(
        stagingDirectory: URL = CaptureService.defaultStagingDirectory(),
        fileManager: FileManager = .default,
        processTapBackend: (any AppAudioCaptureBackend)? = nil,
        screenCaptureBackend: (any AppAudioCaptureBackend)? = nil,
        virtualBackend: (any VirtualInputAppAudioCaptureBackend)? = nil,
        microphonePermissionGranted: @escaping () -> Bool = { CaptureService.microphonePermissionGranted() }
    ) {
        self.processTapBackend = processTapBackend ?? ProcessAudioTapCaptureService(
            stagingDirectory: stagingDirectory,
            fileManager: fileManager
        )
        self.screenCaptureBackend = screenCaptureBackend ?? ScreenCaptureKitAppAudioCaptureService(
            stagingDirectory: stagingDirectory,
            fileManager: fileManager
        )
        self.virtualBackend = virtualBackend ?? VirtualInputDeviceCaptureService(
            stagingDirectory: stagingDirectory,
            fileManager: fileManager
        )
        self.microphonePermissionGranted = microphonePermissionGranted
        let preferred = AppAudioCaptureBackendSelector.preferredBackend(
            processTapSupported: ProcessAudioTapCaptureService.isSupported
        )
        if preferred == .processAudioTap {
            self.activeBackend = self.processTapBackend
            self.activeBackendKind = .processAudioTap
        } else {
            self.activeBackend = self.screenCaptureBackend
            self.activeBackendKind = .screenCaptureKit
        }
        configureCallbacks()
    }

    public static func screenCapturePermissionGranted() -> Bool {
        ScreenCaptureKitAppAudioCaptureService.screenCapturePermissionGranted()
    }

    @discardableResult
    public static func requestScreenCapturePermission() -> Bool {
        ScreenCaptureKitAppAudioCaptureService.requestScreenCapturePermission()
    }

    public static func preferredBackendKind() -> AppAudioCaptureBackendKind {
        AppAudioCaptureBackendSelector.preferredBackend(
            processTapSupported: ProcessAudioTapCaptureService.isSupported
        )
    }

    public static func preferredSelection(
        targetSoftware: DJSoftware?,
        inputDevices: [AudioInputDevice],
        runningSoftwareIDs: Set<String>
    ) -> AppAudioCaptureBackendSelection {
        AppAudioCaptureBackendSelector.preferredSelection(
            targetSoftware: targetSoftware,
            inputDevices: inputDevices,
            runningSoftwareIDs: runningSoftwareIDs,
            processTapSupported: ProcessAudioTapCaptureService.isSupported
        )
    }

    public func listShareableDJApps() async throws -> [MatchedDJApp] {
        let processTapApps = try await processTapBackend.listShareableDJApps()
        if !processTapApps.isEmpty {
            return processTapApps
        }
        return try await screenCaptureBackend.listShareableDJApps()
    }

    public func startMonitoring(
        bundleIdentifier: String,
        displayName: String,
        prerollSeconds: TimeInterval = 1.0,
        softwareID: String? = nil,
        inputDevices: [AudioInputDevice] = [],
        runningSoftwareIDs: Set<String> = []
    ) async throws {
        virtualBindDidFallBack = false
        appleAppAudioPathExhausted = false
        activeVirtualDevice = nil
        activeSourceDeviceUID = nil
        let software = softwareID.flatMap { id in SupportedDJSoftware.all.first { $0.id == id } }

        do {
            try await startProcessTapOrScreenCapture(
                bundleIdentifier: bundleIdentifier,
                displayName: displayName,
                prerollSeconds: prerollSeconds
            )
            return
        } catch AppAudioCaptureError.permissionDenied {
            if AppAudioCaptureBackendSelector.virtualAppAudioEnabled,
               microphonePermissionGranted(),
               let selection = AppAudioCaptureBackendSelector.vendorFallbackSelection(
                   targetSoftware: software,
                   inputDevices: inputDevices,
                   runningSoftwareIDs: runningSoftwareIDs
               ), case .virtualInputDevice(let device, let boundSoftwareID) = selection {
                return try await startVendorMonitoring(
                    device: device,
                    boundSoftwareID: boundSoftwareID,
                    bundleIdentifier: bundleIdentifier,
                    displayName: displayName,
                    prerollSeconds: prerollSeconds
                )
            }
            throw AppAudioCaptureError.permissionDenied
        } catch AppAudioCaptureError.alreadyMonitoring {
            throw AppAudioCaptureError.alreadyMonitoring
        } catch {
            appleAppAudioPathExhausted = true
            print(
                "app-audio-backend: Apple paths failed (\(error.localizedDescription)); trying vendor fallback if enabled"
            )
        }

        if AppAudioCaptureBackendSelector.virtualAppAudioEnabled,
           microphonePermissionGranted(),
           let selection = AppAudioCaptureBackendSelector.vendorFallbackSelection(
               targetSoftware: software,
               inputDevices: inputDevices,
               runningSoftwareIDs: runningSoftwareIDs
           ), case .virtualInputDevice(let device, let boundSoftwareID) = selection {
            do {
                return try await startVendorMonitoring(
                    device: device,
                    boundSoftwareID: boundSoftwareID,
                    bundleIdentifier: bundleIdentifier,
                    displayName: displayName,
                    prerollSeconds: prerollSeconds
                )
            } catch AppAudioCaptureError.permissionDenied {
                throw AppAudioCaptureError.permissionDenied
            } catch AppAudioCaptureError.alreadyMonitoring {
                throw AppAudioCaptureError.alreadyMonitoring
            } catch {
                virtualBindDidFallBack = true
                print(
                    "app-audio-backend: virtualInputDevice bind failed (\(error.localizedDescription))"
                )
            }
        }

        throw AppAudioCaptureError.engineFailed(
            "SetCatcher cannot hear this DJ app yet. Finish setup permissions, then try again."
        )
    }

    private func startVendorMonitoring(
        device: AudioInputDevice,
        boundSoftwareID: String,
        bundleIdentifier: String,
        displayName: String,
        prerollSeconds: TimeInterval
    ) async throws {
        virtualBackend.bind(device: device, softwareID: boundSoftwareID)
        try await virtualBackend.startMonitoring(
            bundleIdentifier: bundleIdentifier,
            displayName: displayName,
            prerollSeconds: prerollSeconds
        )
        adopt(virtualBackend, kind: .virtualInputDevice, virtualDevice: device)
        activeSourceDeviceUID = device.id
        print(
            "app-audio-backend: virtualInputDevice device=\(device.name) uid=\(device.id) transport=\(device.transportType.archiveLabel)"
        )
    }

    public func stopMonitoring() async {
        await activeBackend.stopMonitoring()
        activeVirtualDevice = nil
        activeSourceDeviceUID = nil
    }

    public func beginRecordingFile() throws {
        try activeBackend.beginRecordingFile()
    }

    public func endRecordingFile(discard: Bool = false) throws -> CaptureResult? {
        try activeBackend.endRecordingFile(discard: discard)
    }

    public func currentInputLevel() -> Float {
        activeBackend.currentInputLevel()
    }

    public func currentStagingByteCount() -> Int64? {
        activeBackend.currentStagingByteCount()
    }

    static func isScreenCapturePermissionError(_ error: Error) -> Bool {
        ScreenCaptureKitAppAudioCaptureService.isScreenCapturePermissionError(error)
    }

    private func startProcessTapOrScreenCapture(
        bundleIdentifier: String,
        displayName: String,
        prerollSeconds: TimeInterval
    ) async throws {
        let preferred = AppAudioCaptureBackendSelector.preferredBackend(
            processTapSupported: ProcessAudioTapCaptureService.isSupported
        )
        if preferred == .processAudioTap {
            do {
                try await processTapBackend.startMonitoring(
                    bundleIdentifier: bundleIdentifier,
                    displayName: displayName,
                    prerollSeconds: prerollSeconds
                )
                adopt(processTapBackend, kind: .processAudioTap, virtualDevice: nil)
                activeSourceDeviceUID = processTapBackend.sourceDeviceUID
                print("app-audio-backend: processAudioTap")
                return
            } catch AppAudioCaptureError.permissionDenied {
                throw AppAudioCaptureError.permissionDenied
            } catch AppAudioCaptureError.alreadyMonitoring {
                throw AppAudioCaptureError.alreadyMonitoring
            } catch {
                await processTapBackend.stopMonitoring()
                do {
                    try await processTapBackend.startMonitoring(
                        bundleIdentifier: bundleIdentifier,
                        displayName: displayName,
                        prerollSeconds: prerollSeconds
                    )
                    adopt(processTapBackend, kind: .processAudioTap, virtualDevice: nil)
                    activeSourceDeviceUID = processTapBackend.sourceDeviceUID
                    print("app-audio-backend: processAudioTap (retry)")
                    return
                } catch AppAudioCaptureError.permissionDenied {
                    throw AppAudioCaptureError.permissionDenied
                } catch AppAudioCaptureError.alreadyMonitoring {
                    throw AppAudioCaptureError.alreadyMonitoring
                } catch {
                    await processTapBackend.stopMonitoring()
                }
            }
            _ = try? await screenCaptureBackend.listShareableDJApps()
            try await screenCaptureBackend.startMonitoring(
                bundleIdentifier: bundleIdentifier,
                displayName: displayName,
                prerollSeconds: prerollSeconds
            )
            adopt(screenCaptureBackend, kind: .screenCaptureKit, virtualDevice: nil)
            activeSourceDeviceUID = bundleIdentifier
            print("app-audio-backend: screenCaptureKit (process-tap fallback)")
            return
        }

        try await screenCaptureBackend.startMonitoring(
            bundleIdentifier: bundleIdentifier,
            displayName: displayName,
            prerollSeconds: prerollSeconds
        )
        adopt(screenCaptureBackend, kind: .screenCaptureKit, virtualDevice: nil)
        activeSourceDeviceUID = bundleIdentifier
        print("app-audio-backend: screenCaptureKit")
    }

    private func adopt(
        _ backend: AppAudioCaptureBackend,
        kind: AppAudioCaptureBackendKind,
        virtualDevice: AudioInputDevice?
    ) {
        activeBackend = backend
        activeBackendKind = kind
        activeVirtualDevice = virtualDevice
        configureCallbacks()
    }

    private func configureCallbacks() {
        processTapBackend.onStreamStopped = onStreamStopped
        screenCaptureBackend.onStreamStopped = onStreamStopped
        virtualBackend.onStreamStopped = onStreamStopped
        processTapBackend.onInterruptedCapture = onInterruptedCapture
        screenCaptureBackend.onInterruptedCapture = onInterruptedCapture
        virtualBackend.onInterruptedCapture = onInterruptedCapture
    }
}

public protocol VirtualInputAppAudioCaptureBackend: AppAudioCaptureBackend {
    func bind(device: AudioInputDevice, softwareID: String)
}

public final class ProcessAudioTapCaptureService: @unchecked Sendable, AppAudioCaptureBackend {
    public let backendKind: AppAudioCaptureBackendKind = .processAudioTap
    public var isMonitoring: Bool { capture.isMonitoring }
    public var isWriting: Bool { capture.isWriting }
    public var inputLevel: Float { capture.currentInputLevel() }
    public var startedAt: Date? { capture.startedAt }
    public var sourceDeviceUID: String? { aggregateDeviceUID }
    public private(set) var targetBundleIdentifier = ""
    public private(set) var targetDisplayName = ""
    public private(set) var aggregateDeviceUID: String?

    public var onStreamStopped: ((AppAudioCaptureError) -> Void)?
    public var onInterruptedCapture: ((CaptureResult, AppAudioCaptureError) -> Void)?

    private let capture: CoreAudioIOProcCapture
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateDeviceID = AudioObjectID(kAudioObjectUnknown)

    public init(stagingDirectory: URL = CaptureService.defaultStagingDirectory(), fileManager: FileManager = .default) {
        self.capture = CoreAudioIOProcCapture(
            stagingDirectory: stagingDirectory,
            fileManager: fileManager,
            queueLabel: "app.setcatcher.ProcessAudioTap.sample"
        )
    }

    public static var isSupported: Bool { true }

    public func listShareableDJApps() async throws -> [MatchedDJApp] {
        let bundleIDs = NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier)
        return DJAppProcessMatcher.matchRunning(bundleIdentifiers: bundleIDs)
    }

    public func startMonitoring(
        bundleIdentifier: String,
        displayName: String,
        prerollSeconds: TimeInterval = 1.0
    ) async throws {
        guard !isMonitoring else { throw AppAudioCaptureError.alreadyMonitoring }
        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleIdentifier }) else {
            throw AppAudioCaptureError.appNotShareable(displayName)
        }

        let tapID: AudioObjectID
        if #available(macOS 26, *) {
            tapID = try createProcessTap(bundleIdentifier: bundleIdentifier, displayName: displayName)
        } else {
            let processObjectID = try translatePIDToProcessObject(app.processIdentifier, displayName: displayName)
            tapID = try createProcessTap(
                bundleIdentifier: bundleIdentifier,
                processObjectID: processObjectID,
                displayName: displayName
            )
        }
        do {
            let tapUID = try readTapUID(tapID)
            let sourceASBD = try readTapFormat(tapID)
            let aggregateUID = "app.setcatcher.process-tap.\(UUID().uuidString)"
            let aggregateDeviceID = try createAggregateDevice(
                tapUID: tapUID,
                aggregateUID: aggregateUID,
                displayName: displayName
            )
            self.aggregateDeviceUID = aggregateUID
            self.aggregateDeviceID = aggregateDeviceID
            try capture.start(
                deviceID: aggregateDeviceID,
                sourceASBD: sourceASBD,
                prerollSeconds: prerollSeconds,
                sourceLabel: "Process Audio Tap",
                filePrefix: "process-tap",
                resultMetadata: .init(
                    deviceID: bundleIdentifier,
                    deviceName: "\(displayName) process audio",
                    captureBackend: .processAudioTap,
                    deviceTransport: nil
                )
            )
            self.tapID = tapID
            self.targetBundleIdentifier = bundleIdentifier
            self.targetDisplayName = displayName
        } catch {
            capture.stop()
            cleanupAggregate()
            destroyTap(tapID)
            throw error
        }
    }

    public func stopMonitoring() async {
        guard isMonitoring || tapID != kAudioObjectUnknown || aggregateDeviceID != kAudioObjectUnknown else { return }
        if isWriting {
            _ = try? endRecordingFile(discard: true)
        }
        capture.stop()
        cleanupAggregate()
        destroyTap(tapID)
        tapID = AudioObjectID(kAudioObjectUnknown)
        targetBundleIdentifier = ""
        targetDisplayName = ""
        aggregateDeviceUID = nil
    }

    public func beginRecordingFile() throws {
        try capture.beginRecordingFile()
    }

    public func endRecordingFile(discard: Bool = false) throws -> CaptureResult? {
        try capture.endRecordingFile(discard: discard)
    }

    public func currentInputLevel() -> Float {
        capture.currentInputLevel()
    }

    public func currentStagingByteCount() -> Int64? {
        capture.currentStagingByteCount()
    }

    private func translatePIDToProcessObject(_ pid: pid_t, displayName: String) throws -> AudioObjectID {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyTranslatePIDToProcessObject,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var processID = pid
        var processObjectID = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            UInt32(MemoryLayout<pid_t>.size),
            &processID,
            &size,
            &processObjectID
        )
        guard status == noErr, processObjectID != kAudioObjectUnknown else {
            throw AppAudioCaptureError.appNotShareable(displayName)
        }
        return processObjectID
    }

    private func createProcessTap(
        bundleIdentifier: String,
        processObjectID: AudioObjectID? = nil,
        displayName: String
    ) throws -> AudioObjectID {
        let description: CATapDescription
        if #available(macOS 26, *) {
            description = CATapDescription()
            description.name = "SetCatcher \(displayName)"
            description.bundleIDs = [bundleIdentifier]
            description.isProcessRestoreEnabled = true
            description.isPrivate = true
            description.isMixdown = true
            description.muteBehavior = CATapMuteBehavior(rawValue: 0) ?? description.muteBehavior
        } else {
            guard let processObjectID else {
                throw AppAudioCaptureError.appNotShareable(displayName)
            }
            description = CATapDescription(stereoMixdownOfProcesses: [processObjectID])
            description.name = "SetCatcher \(displayName)"
            description.isPrivate = true
            description.muteBehavior = CATapMuteBehavior(rawValue: 0) ?? description.muteBehavior
        }

        var newTapID = AudioObjectID(kAudioObjectUnknown)
        let status = AudioHardwareCreateProcessTap(description, &newTapID)
        guard status == noErr, newTapID != kAudioObjectUnknown else {
            if status == kAudioHardwareIllegalOperationError {
                throw AppAudioCaptureError.permissionDenied
            }
            throw statusError("create Process Audio Tap", status)
        }
        return newTapID
    }

    private func readTapUID(_ tapID: AudioObjectID) throws -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioTapPropertyUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var uid: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        let status = withUnsafeMutablePointer(to: &uid) { pointer in
            AudioObjectGetPropertyData(tapID, &address, 0, nil, &size, pointer)
        }
        guard status == noErr else { throw statusError("read Process Audio Tap UID", status) }
        return uid as String
    }

    private func readTapFormat(_ tapID: AudioObjectID) throws -> AudioStreamBasicDescription {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioTapPropertyFormat,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var asbd = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        let status = AudioObjectGetPropertyData(tapID, &address, 0, nil, &size, &asbd)
        guard status == noErr else { throw statusError("read Process Audio Tap format", status) }
        return asbd
    }

    private func createAggregateDevice(tapUID: String, aggregateUID: String, displayName: String) throws -> AudioObjectID {
        let tapList: [[String: Any]] = [[
            kAudioSubTapUIDKey: tapUID,
            kAudioSubTapDriftCompensationKey: true
        ]]
        let description: [String: Any] = [
            kAudioAggregateDeviceNameKey: "SetCatcher \(displayName) Tap",
            kAudioAggregateDeviceUIDKey: aggregateUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceTapListKey: tapList
        ]

        var newDeviceID = AudioObjectID(kAudioObjectUnknown)
        let status = AudioHardwareCreateAggregateDevice(description as CFDictionary, &newDeviceID)
        guard status == noErr, newDeviceID != kAudioObjectUnknown else {
            throw statusError("create Process Audio Tap aggregate device", status)
        }
        return newDeviceID
    }

    private func cleanupAggregate() {
        if aggregateDeviceID != kAudioObjectUnknown {
            _ = AudioHardwareDestroyAggregateDevice(aggregateDeviceID)
        }
        aggregateDeviceID = AudioObjectID(kAudioObjectUnknown)
    }

    private func destroyTap(_ tapID: AudioObjectID) {
        guard tapID != kAudioObjectUnknown else { return }
        _ = AudioHardwareDestroyProcessTap(tapID)
    }

    private func statusError(_ action: String, _ status: OSStatus) -> AppAudioCaptureError {
        AppAudioCaptureError.engineFailed("\(action) failed (\(status)).")
    }

}

/// Captures a single macOS app's audio via ScreenCaptureKit into staging WAVs.
public final class ScreenCaptureKitAppAudioCaptureService: NSObject, @unchecked Sendable, AppAudioCaptureBackend {
    public let backendKind: AppAudioCaptureBackendKind = .screenCaptureKit
    public private(set) var isMonitoring = false
    public private(set) var isWriting = false
    public private(set) var inputLevel: Float = 0
    public private(set) var startedAt: Date?
    public private(set) var targetBundleIdentifier = ""
    public private(set) var targetDisplayName = ""
    public var sourceDeviceUID: String? {
        targetBundleIdentifier.isEmpty ? nil : targetBundleIdentifier
    }

    /// Invoked on the sample-handler queue when ScreenCaptureKit stops the stream with an error.
    public var onStreamStopped: ((AppAudioCaptureError) -> Void)?
    public var onInterruptedCapture: ((CaptureResult, AppAudioCaptureError) -> Void)?

    private let fileManager: FileManager
    private let stagingDirectory: URL
    private let sampleHandlerQueue = DispatchQueue(label: "app.setcatcher.AppAudioCapture.sample")
    private static let sampleQueueKey = DispatchSpecificKey<UInt8>()
    private static let sampleQueueValue: UInt8 = 1
    private let levelLock = NSLock()
    private var stream: SCStream?
    private var audioFile: AVAudioFile?
    private var stagingURL: URL?
    /// Canonical 16-bit / 48 kHz write target; also the format the pre-roll ring is stored in.
    private var writeFormat: AVAudioFormat?
    /// Adapted Float32 source format of the current ScreenCaptureKit stream.
    private var sourceFormat: AVAudioFormat?
    private var converter: AVAudioConverter?
    private var lastFormatMismatchDetail: String?

    /// Ring of already-converted `writeFormat` buffers captured while watching, flushed into the
    /// file on `beginRecordingFile` so a take starts at the true first signal rather than ~half a
    /// second in (after the silence-session start hold). Only mutated on `sampleHandlerQueue`.
    private var prerollBuffers: [AVAudioPCMBuffer] = []
    private var prerollFrames: AVAudioFrameCount = 0
    private var prerollFrameBudget: AVAudioFrameCount = 0

    public init(stagingDirectory: URL = CaptureService.defaultStagingDirectory(), fileManager: FileManager = .default) {
        self.stagingDirectory = stagingDirectory
        self.fileManager = fileManager
        super.init()
        sampleHandlerQueue.setSpecific(key: Self.sampleQueueKey, value: Self.sampleQueueValue)
    }

    public static func screenCapturePermissionGranted() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    @discardableResult
    public static func requestScreenCapturePermission() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    public func listShareableDJApps() async throws -> [MatchedDJApp] {
        let content = try await fetchShareableContent()
        let bundleIDs = content.applications.compactMap(\.bundleIdentifier)
        return DJAppProcessMatcher.matchRunning(bundleIdentifiers: bundleIDs)
    }

    public func startMonitoring(
        bundleIdentifier: String,
        displayName: String,
        prerollSeconds: TimeInterval = 1.0
    ) async throws {
        guard !isMonitoring else { throw AppAudioCaptureError.alreadyMonitoring }
        if !Self.screenCapturePermissionGranted() {
            let granted = Self.requestScreenCapturePermission()
            // CGRequestScreenCaptureAccess often returns false before Settings toggles apply.
            if !granted && !Self.screenCapturePermissionGranted() {
                throw AppAudioCaptureError.permissionDenied
            }
        }

        let content = try await fetchShareableContent()

        guard let runningApp = content.applications.first(where: { $0.bundleIdentifier == bundleIdentifier }) else {
            throw AppAudioCaptureError.appNotShareable(displayName)
        }
        guard let display = content.displays.first else {
            throw AppAudioCaptureError.noDisplay
        }

        let filter = SCContentFilter(display: display, including: [runningApp], exceptingWindows: [])
        let configuration = SCStreamConfiguration()
        configuration.capturesAudio = true
        configuration.excludesCurrentProcessAudio = true
        configuration.sampleRate = Int(CaptureAudioFormat.sampleRate)
        configuration.channelCount = Int(CaptureAudioFormat.channelCount)
        configuration.width = 2
        configuration.height = 2
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        configuration.queueDepth = 8

        let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        do {
            try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: sampleHandlerQueue)
            try await stream.startCapture()
        } catch {
            throw AppAudioCaptureError.engineFailed(error.localizedDescription)
        }

        self.stream = stream
        targetBundleIdentifier = bundleIdentifier
        targetDisplayName = displayName
        isMonitoring = true
        lastFormatMismatchDetail = nil
        // Canonical write target; the pre-roll ring stores buffers already converted to this format
        // so a take can begin with the audio that played during the silence-session start hold.
        writeFormat = CaptureAudioFormat.processingFormat()
        sourceFormat = nil
        converter = nil
        sampleHandlerQueue.sync {
            prerollBuffers.removeAll()
            prerollFrames = 0
            prerollFrameBudget = AVAudioFrameCount(max(0, prerollSeconds) * CaptureAudioFormat.sampleRate)
        }
        setInputLevel(0)
    }

    public func stopMonitoring() async {
        guard isMonitoring else { return }
        if isWriting {
            _ = try? endRecordingFile(discard: true)
        }
        if let stream {
            try? await stream.stopCapture()
        }
        stream = nil
        isMonitoring = false
        targetBundleIdentifier = ""
        targetDisplayName = ""
        writeFormat = nil
        sourceFormat = nil
        converter = nil
        sampleHandlerQueue.sync {
            prerollBuffers.removeAll()
            prerollFrames = 0
        }
        setInputLevel(0)
    }

    public func beginRecordingFile() throws {
        guard isMonitoring else { throw AppAudioCaptureError.notMonitoring }
        guard !isWriting else { throw AppAudioCaptureError.alreadyWriting }

        try fileManager.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
        let url = stagingDirectory.appendingPathComponent("app-audio-\(UUID().uuidString).wav")
        let newAudioFile: AVAudioFile
        do {
            newAudioFile = try AVAudioFile(forWriting: url, settings: CaptureAudioFormat.writeSettings)
        } catch {
            let nsError = error as NSError
            if nsError.domain == NSPOSIXErrorDomain && nsError.code == Int(ENOSPC) {
                throw AppAudioCaptureError.diskFull
            }
            throw AppAudioCaptureError.engineFailed(error.localizedDescription)
        }
        // AVAudioFile.write(from:) requires the buffer format to match the file's own
        // processingFormat (Float32 deinterleaved) — it packs down to the on-disk `settings`
        // bit depth internally. The pre-roll ring and stream converter already target this format.
        let fileFormat = newAudioFile.processingFormat

        // Flush the pre-roll and flip to writing atomically on the sample-handler queue so no live
        // buffer is written before the buffered start, and no callback races the file swap.
        sampleHandlerQueue.sync {
            var flushedFrames: AVAudioFrameCount = 0
            if let writeFormat, fileFormat.isEqual(writeFormat) {
                for buffer in prerollBuffers {
                    if ScreenCaptureKitAppAudioCaptureService.writeSucceeded(buffer, to: newAudioFile) {
                        flushedFrames += buffer.frameLength
                    }
                }
            }
            prerollBuffers.removeAll()
            prerollFrames = 0
            audioFile = newAudioFile
            // Backdate the start by the flushed pre-roll so the archive timestamp lands on the
            // true first signal rather than the moment the start hold elapsed.
            let prerollDuration = Double(flushedFrames) / CaptureAudioFormat.sampleRate
            startedAt = Date().addingTimeInterval(-prerollDuration)
            isWriting = true
        }
        stagingURL = url
        lastFormatMismatchDetail = nil
    }

    private static func writeSucceeded(_ buffer: AVAudioPCMBuffer, to audioFile: AVAudioFile) -> Bool {
        CapturePCMWriter.write(buffer: buffer, to: audioFile) == nil
    }

    public func endRecordingFile(discard: Bool = false) throws -> CaptureResult? {
        guard isWriting else { throw AppAudioCaptureError.notWriting }
        return try finalizeRecordingFile(discard: discard, interrupted: false, reason: nil)
    }

    private func finalizeRecordingFile(
        discard: Bool,
        interrupted: Bool,
        reason: String?
    ) throws -> CaptureResult? {
        // Stop writing on the sample-handler queue so no in-flight callback writes to a closed file.
        // Keep `writeFormat`/`converter` so metering and the pre-roll ring keep running while armed.
        syncOnSampleHandlerQueue {
            audioFile = nil
            isWriting = false
        }
        let endedAt = Date()
        let started = startedAt ?? endedAt
        startedAt = nil
        guard let stagingURL else {
            throw AppAudioCaptureError.engineFailed("Capture staging file is missing.")
        }
        self.stagingURL = nil

        if discard {
            try? fileManager.removeItem(at: stagingURL)
            return nil
        }

        if let detail = lastFormatMismatchDetail {
            try? fileManager.removeItem(at: stagingURL)
            throw AppAudioCaptureError.engineFailed(detail)
        }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: stagingURL.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
            throw AppAudioCaptureError.engineFailed("Capture staging file is missing.")
        }

        return CaptureResult(
            stagingURL: stagingURL,
            deviceID: targetBundleIdentifier,
            deviceName: "\(targetDisplayName) app audio",
            startedAt: started,
            endedAt: endedAt,
            captureRoute: .appAudio,
            captureBackend: .screenCaptureKit,
            captureInterrupted: interrupted,
            captureInterruptionReason: reason
        )
    }

    public func currentInputLevel() -> Float {
        levelLock.lock(); defer { levelLock.unlock() }
        return inputLevel
    }

    public func currentStagingByteCount() -> Int64? {
        guard isWriting, let stagingURL else { return nil }
        return (try? stagingURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init)
    }

    private func setInputLevel(_ value: Float) {
        levelLock.lock()
        inputLevel = value
        levelLock.unlock()
    }

    private func syncOnSampleHandlerQueue(_ body: () -> Void) {
        if DispatchQueue.getSpecific(key: Self.sampleQueueKey) == Self.sampleQueueValue {
            body()
        } else {
            sampleHandlerQueue.sync(execute: body)
        }
    }

    private func fetchShareableContent() async throws -> SCShareableContent {
        do {
            return try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        } catch {
            if Self.isScreenCapturePermissionError(error) || !Self.screenCapturePermissionGranted() {
                throw AppAudioCaptureError.permissionDenied
            }
            throw AppAudioCaptureError.engineFailed(error.localizedDescription)
        }
    }

    static func isScreenCapturePermissionError(_ error: Error) -> Bool {
        let nsError = error as NSError
        let text = (nsError.localizedDescription + " " + (nsError.localizedFailureReason ?? "")).lowercased()
        if text.contains("permission") || text.contains("not authorized") || text.contains("tcc")
            || text.contains("screen capture") || text.contains("denied")
        {
            return true
        }
        // ScreenCaptureKit commonly uses SCStreamError / CGError domain codes for denied access.
        if nsError.domain.contains("ScreenCapture") || nsError.domain.contains("SCStream") {
            return nsError.code == Int(CGError.failure.rawValue) || nsError.code == -3801 || nsError.code == -3802
        }
        return false
    }

    private func handleAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard sampleBuffer.isValid, let formatDescription = sampleBuffer.formatDescription else { return }
        let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)?.pointee
        guard let asbd else { return }

        var bufferListSizeNeeded = 0
        var blockBuffer: CMBlockBuffer?
        var status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: &bufferListSizeNeeded,
            bufferListOut: nil,
            bufferListSize: 0,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: 0,
            blockBufferOut: &blockBuffer
        )
        guard status == noErr, bufferListSizeNeeded > 0 else { return }

        let raw = UnsafeMutableRawPointer.allocate(byteCount: bufferListSizeNeeded, alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { raw.deallocate() }
        let audioBufferList = raw.bindMemory(to: AudioBufferList.self, capacity: 1)
        status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: audioBufferList,
            bufferListSize: bufferListSizeNeeded,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: 0,
            blockBufferOut: &blockBuffer
        )
        guard status == noErr else { return }

        let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
        let isFloat = asbd.mFormatFlags & kAudioFormatFlagIsFloat != 0
        let isInterleaved = asbd.mFormatFlags & kAudioFormatFlagIsNonInterleaved == 0
        let sourceChannels = Int(asbd.mChannelsPerFrame)

        var meter = CaptureDSP.MeanSquareAccumulator()
        if isFloat {
            for buffer in ablPointer {
                guard let data = buffer.mData else { continue }
                let frameCount = Int(buffer.mDataByteSize) / MemoryLayout<Float>.size
                let samples = data.bindMemory(to: Float.self, capacity: frameCount)
                meter.add(samples: samples, count: frameCount)
            }
        }
        if let inputLevel = meter.inputLevel {
            setInputLevel(inputLevel)
        }

        // Convert every buffer while monitoring — not only while writing — so the pre-roll ring
        // always holds the most recent audio ready to prepend to the next take.
        guard let writeFormat else { return }

        let frameLength = AVAudioFrameCount(CMSampleBufferGetNumSamples(sampleBuffer))
        guard frameLength > 0 else { return }

        if !isFloat {
            lastFormatMismatchDetail = "App audio Capture received non-float audio buffers. Arm again, or use Input device Capture."
            return
        }

        // Rebuild converter when ScreenCaptureKit delivers a different rate/channel layout.
        let sourceRate = asbd.mSampleRate
        let sourceChannelCount = AVAudioChannelCount(max(1, sourceChannels))
        if sourceFormat == nil
            || abs(sourceRate - (sourceFormat?.sampleRate ?? 0)) > 0.5
            || sourceChannelCount != sourceFormat?.channelCount {
            guard let adaptedSource = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: sourceRate,
                channels: sourceChannelCount,
                interleaved: false
            ),
                let adaptedConverter = CaptureAudioFormat.makeConverter(from: adaptedSource, to: writeFormat)
            else {
                lastFormatMismatchDetail = "App audio Capture received an unsupported buffer format (\(Int(sourceRate)) Hz, \(sourceChannels) ch). Arm again, or use Input device Capture."
                return
            }
            self.sourceFormat = adaptedSource
            self.converter = adaptedConverter
        }

        guard let activeSource = self.sourceFormat,
              let activeConverter = self.converter,
              let pcm = AVAudioPCMBuffer(pcmFormat: activeSource, frameCapacity: frameLength)
        else { return }
        pcm.frameLength = frameLength

        let channelCount = Int(activeSource.channelCount)
        guard let floatChannels = pcm.floatChannelData else { return }

        if isInterleaved, ablPointer.count >= 1, let src = ablPointer[0].mData {
            let sourceChannelCount = max(sourceChannels, 1)
            let interleaved = src.bindMemory(to: Float.self, capacity: Int(frameLength) * sourceChannelCount)
            for channel in 0..<channelCount {
                let srcChannel = min(channel, sourceChannelCount - 1)
                CaptureDSP.copyInterleavedChannel(
                    from: interleaved,
                    sourceChannel: srcChannel,
                    sourceChannelCount: sourceChannelCount,
                    frameCount: Int(frameLength),
                    to: floatChannels[channel]
                )
            }
        } else {
            for channel in 0..<channelCount {
                let srcIndex = min(channel, ablPointer.count - 1)
                guard srcIndex >= 0, let src = ablPointer[srcIndex].mData else { continue }
                let count = min(Int(frameLength), Int(ablPointer[srcIndex].mDataByteSize) / MemoryLayout<Float>.size)
                let samples = src.bindMemory(to: Float.self, capacity: count)
                CaptureDSP.copyPlanarChannel(
                    from: samples,
                    count: count,
                    to: floatChannels[channel]
                )
            }
        }

        let conversion = CapturePCMWriter.convert(buffer: pcm, converter: activeConverter, writeFormat: writeFormat)
        if let detail = conversion.error {
            lastFormatMismatchDetail = "App audio Capture \(detail)"
            return
        }
        guard let converted = conversion.buffer else {
            lastFormatMismatchDetail = "App audio Capture could not convert to 16-bit / 48 kHz."
            return
        }

        if isWriting, let audioFile {
            if let detail = CapturePCMWriter.write(buffer: converted, to: audioFile) {
                lastFormatMismatchDetail = "App audio Capture \(detail)"
            } else {
                lastFormatMismatchDetail = nil
            }
        } else {
            appendPreroll(converted)
            lastFormatMismatchDetail = nil
        }
    }

    /// Appends a converted buffer to the pre-roll ring and trims it to the frame budget.
    /// Must run on `sampleHandlerQueue`.
    private func appendPreroll(_ buffer: AVAudioPCMBuffer) {
        guard prerollFrameBudget > 0 else { return }
        prerollBuffers.append(buffer)
        prerollFrames += buffer.frameLength
        while prerollFrames > prerollFrameBudget, prerollBuffers.count > 1 {
            let removed = prerollBuffers.removeFirst()
            prerollFrames -= min(prerollFrames, removed.frameLength)
        }
    }
}

extension ScreenCaptureKitAppAudioCaptureService: SCStreamDelegate {
    public func stream(_ stream: SCStream, didStopWithError error: Error) {
        let wasMonitoring = isMonitoring
        let wasWriting = isWriting
        let reason = error.localizedDescription
        let captureError = AppAudioCaptureError.streamStopped(reason)
        var interruptedResult: CaptureResult?
        var finalizationFailure: AppAudioCaptureError?
        if wasWriting {
            do {
                interruptedResult = try finalizeRecordingFile(
                    discard: false,
                    interrupted: true,
                    reason: reason
                )
            } catch {
                finalizationFailure = .streamStopped(
                    "Interrupted take could not be finalized: \(error.localizedDescription)"
                )
            }
        }
        isMonitoring = false
        isWriting = false
        audioFile = nil
        writeFormat = nil
        sourceFormat = nil
        converter = nil
        stagingURL = nil
        startedAt = nil
        prerollBuffers.removeAll()
        prerollFrames = 0
        setInputLevel(0)
        guard wasMonitoring || wasWriting else { return }
        if let interruptedResult {
            onInterruptedCapture?(interruptedResult, captureError)
        } else if let finalizationFailure {
            onStreamStopped?(finalizationFailure)
        } else {
            onStreamStopped?(captureError)
        }
    }
}

extension ScreenCaptureKitAppAudioCaptureService: SCStreamOutput {
    public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }
        handleAudioSampleBuffer(sampleBuffer)
    }
}
#endif

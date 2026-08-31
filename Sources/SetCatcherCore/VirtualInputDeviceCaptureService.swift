#if os(macOS)
import AppKit
import CoreAudio
import Foundation

/// App Audio backend that records a verified DJ-software virtual input directly through a
/// Core Audio device IOProc. It intentionally has no AVAudioEngine output side, avoiding the
/// unbounded clock-drift buffering that occurs when a virtual input and speakers use different
/// clocks.
public final class VirtualInputDeviceCaptureService: @unchecked Sendable, VirtualInputAppAudioCaptureBackend {
    public let backendKind: AppAudioCaptureBackendKind = .virtualInputDevice
    public var onStreamStopped: ((AppAudioCaptureError) -> Void)?
    public var onInterruptedCapture: ((CaptureResult, AppAudioCaptureError) -> Void)?

    public var isMonitoring: Bool { capture.isMonitoring }
    public var isWriting: Bool { capture.isWriting }
    public var sourceDeviceUID: String? { boundDevice?.id }

    private let capture: CoreAudioIOProcCapture
    private var boundDevice: AudioInputDevice?

    public init(
        stagingDirectory: URL = CaptureService.defaultStagingDirectory(),
        fileManager: FileManager = .default
    ) {
        self.capture = CoreAudioIOProcCapture(
            stagingDirectory: stagingDirectory,
            fileManager: fileManager,
            queueLabel: "app.setcatcher.VirtualInputDevice.sample"
        )
    }

    public func bind(device: AudioInputDevice, softwareID: String) {
        _ = softwareID
        boundDevice = device
    }

    public func listShareableDJApps() async throws -> [MatchedDJApp] {
        let bundleIDs = NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier)
        return DJAppProcessMatcher.matchRunning(bundleIdentifiers: bundleIDs)
    }

    public func startMonitoring(
        bundleIdentifier: String,
        displayName: String,
        prerollSeconds: TimeInterval
    ) async throws {
        _ = bundleIdentifier
        _ = displayName
        guard let device = boundDevice else {
            throw AppAudioCaptureError.engineFailed(
                "No virtual input device is bound for App audio Capture."
            )
        }
        guard let deviceID = AudioInputDeviceCatalog.audioDeviceID(forUID: device.id) else {
            throw unavailableDeviceError(device.name)
        }

        let sourceASBD: AudioStreamBasicDescription
        do {
            sourceASBD = try AudioInputDeviceCatalog.inputStreamFormat(for: deviceID)
        } catch {
            throw AppAudioCaptureError.engineFailed(
                "\(device.name) input format is unavailable. Open the DJ app, then Arm again, or use Process Audio Tap / folder Protection."
            )
        }

        try capture.start(
            deviceID: deviceID,
            sourceASBD: sourceASBD,
            prerollSeconds: prerollSeconds,
            sourceLabel: device.name,
            filePrefix: "virtual-input",
            resultMetadata: .init(
                deviceID: device.id,
                deviceName: device.name,
                captureBackend: .virtualInputDevice,
                deviceTransport: device.transportType
            )
        )
    }

    public func stopMonitoring() async {
        capture.stop()
        boundDevice = nil
    }

    public func beginRecordingFile() throws {
        try capture.beginRecordingFile()
    }

    public func endRecordingFile(discard: Bool) throws -> CaptureResult? {
        try capture.endRecordingFile(discard: discard)
    }

    public func currentInputLevel() -> Float {
        capture.currentInputLevel()
    }

    public func currentStagingByteCount() -> Int64? {
        capture.currentStagingByteCount()
    }

    private func unavailableDeviceError(_ name: String) -> AppAudioCaptureError {
        .engineFailed(
            "\(name) is not available as an input. Open the DJ app, then Arm again, or use Process Audio Tap / folder Protection."
        )
    }
}
#endif

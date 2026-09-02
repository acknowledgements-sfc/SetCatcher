import AVFoundation
import Foundation

/// Platform-specific binding between a catalog device and `AVAudioEngine` input.
enum CaptureInputBinding {
    static func bind(engine: AVAudioEngine, to device: AudioInputDevice) throws {
        if engine.isRunning {
            engine.stop()
        }

        #if os(macOS)
        guard let coreAudioID = AudioInputDeviceCatalog.audioDeviceID(forUID: device.id) else {
            throw CaptureServiceError.deviceMissing
        }
        do {
            try engine.inputNode.auAudioUnit.setDeviceID(coreAudioID)
        } catch {
            throw CaptureServiceError.engineFailed(
                "Could not select \(device.name): \(error.localizedDescription)"
            )
        }
        #else
        let session = AVAudioSession.sharedInstance()
        guard let port = session.availableInputs?.first(where: { $0.uid == device.id }) else {
            throw CaptureServiceError.deviceMissing
        }
        do {
            try session.setPreferredInput(port)
        } catch {
            throw CaptureServiceError.engineFailed(
                "Could not select \(device.name): \(error.localizedDescription)"
            )
        }
        #endif
    }
}

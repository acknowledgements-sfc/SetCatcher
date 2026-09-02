import Foundation

public enum AppAudioCaptureBackendKind: String, Equatable, Sendable {
    case virtualInputDevice
    case processAudioTap
    case screenCaptureKit

    public var displayName: String {
        switch self {
        case .virtualInputDevice: return "Virtual Input Device"
        case .processAudioTap: return "Process Audio Tap"
        case .screenCaptureKit: return "ScreenCaptureKit"
        }
    }

    public var archiveBackend: CaptureArchiveBackend {
        switch self {
        case .virtualInputDevice: return .virtualInputDevice
        case .processAudioTap: return .processAudioTap
        case .screenCaptureKit: return .screenCaptureKit
        }
    }
}

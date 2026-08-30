import Foundation

public enum CaptureMode: String, Codable, Equatable, Sendable, CaseIterable {
    case appAudio
    case inputDevice

    public var displayName: String {
        switch self {
        case .appAudio: return "App audio"
        case .inputDevice: return "Input device"
        }
    }
}

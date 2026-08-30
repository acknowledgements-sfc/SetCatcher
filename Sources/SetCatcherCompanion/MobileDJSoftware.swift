import Foundation
import SetCatcherCore

/// Mobile DJ adapters for SetCatcher on iPad. Standalone device — no Mac connection. Honest Manual Setup labels only.
public enum MobileDJSoftware: String, CaseIterable, Identifiable, Sendable {
    case djay
    case capture

    public var id: String {
        switch self {
        case .djay: return "djay"
        case .capture: return SupportedDJSoftware.captureAppID
        }
    }

    public var displayName: String {
        switch self {
        case .djay: return "djay"
        case .capture: return "SetCatcher Capture"
        }
    }

    public var supportLabel: String {
        switch self {
        case .djay: return "Manual Setup"
        case .capture: return "Manual Setup"
        }
    }

    public var guidance: String {
        switch self {
        case .djay:
            return "Recordings often appear under Files → On My iPad → djay. Pick those files here, or Share → Save to SetCatcher. Streaming mixes may not be recordable — if import fails, that is why."
        case .capture:
            return "Capture records this iPad’s microphone or interface input while you DJ in an app on this iPad. It does not connect to a Mac, and it does not tap another app’s audio in the background. Import recordings from Files or Share when the DJ app writes them on this iPad."
        }
    }

    public static func displayName(for appID: String) -> String {
        allCases.first { $0.id == appID }?.displayName
            ?? SupportedDJSoftware.all.first { $0.id == appID }?.displayName
            ?? appID
    }
}

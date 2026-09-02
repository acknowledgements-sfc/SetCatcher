import Foundation
import SetCatcherCore
#if canImport(UIKit)
import UIKit
#endif

/// User-visible device noun for iPhone vs iPad. Files uses “On My iPhone” / “On My iPad”.
enum CompanionDeviceCopy {
    static var deviceName: String {
        #if canImport(UIKit)
        UIDevice.current.userInterfaceIdiom == .phone ? "iPhone" : "iPad"
        #else
        "iPad"
        #endif
    }

    static var filesDJFolderHint: String {
        "Files → On My \(deviceName) → djay"
    }
}

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
            return "Recordings often appear under \(CompanionDeviceCopy.filesDJFolderHint). Pick those files here, or Share → Save to SetCatcher. Streaming mixes may not be recordable — if import fails, that is why."
        case .capture:
            return "Capture records this device’s microphone or interface input while you DJ in an app on this device. It does not connect to a Mac, and it does not tap another app’s audio in the background. Import recordings from Files or Share when the DJ app writes them on this device."
        }
    }

    public static func displayName(for appID: String) -> String {
        allCases.first { $0.id == appID }?.displayName
            ?? SupportedDJSoftware.all.first { $0.id == appID }?.displayName
            ?? appID
    }
}

import SwiftUI
import SetCatcherCore

/// Visual state for the menu bar icon + adjacent label.
/// Derived from `LiveProtectionState` — see `AppModel.menuBarState`.
enum MenuBarState: Equatable {
    case launching
    case noSource
    case detected(djAppName: String?)
    case ready(djAppName: String?)
    case armed(djAppName: String?)
    case capturing(djAppName: String?)
    case saving
    case saved
    case attentionNeeded
    case failed(String)

    static func derive(
        isLaunching: Bool,
        live: LiveProtectionState,
        djAppName: String?
    ) -> MenuBarState {
        if isLaunching { return .launching }

        switch live {
        case .capturing:
            return .capturing(djAppName: djAppName)
        case .setProtected:
            return .saved
        case .attentionNeeded:
            return .attentionNeeded
        case .saving:
            return .saving
        case .armed:
            return .armed(djAppName: djAppName)
        case .ready:
            return .ready(djAppName: djAppName)
        case .detected:
            return .detected(djAppName: djAppName)
        case .noSource:
            return .noSource
        }
    }

    /// Stable cache key for the rendered AppKit image. Associated app names affect the adjacent
    /// text label, not the icon artwork.
    var iconCacheKey: String {
        switch self {
        case .launching: return "launching"
        case .noSource: return "noSource"
        case .detected: return "detected"
        case .ready: return "ready"
        case .armed: return "armed"
        case .capturing: return "capturing"
        case .saving: return "saving"
        case .saved: return "saved"
        case .attentionNeeded: return "attention"
        case .failed: return "failed"
        }
    }

    /// Icon/status-dot color from the 8-state Live palette.
    var tint: Color? {
        switch self {
        case .launching, .noSource: return DJToken.LiveState.dormant
        case .detected: return DJToken.LiveState.detected
        case .ready: return DJToken.LiveState.ready
        case .armed: return DJToken.LiveState.armed
        case .capturing: return DJToken.LiveState.capturing
        case .saving: return DJToken.LiveState.saving
        case .saved: return DJToken.LiveState.protected
        case .attentionNeeded: return DJToken.LiveState.attention
        case .failed: return DJToken.danger
        }
    }

    /// Text rendered next to the icon in the menu bar, if any.
    var label: String? {
        switch self {
        case .launching, .noSource, .failed:
            return nil
        case .detected(let name), .ready(let name), .armed(let name), .capturing(let name):
            return name
        case .saving:
            return "Saving…"
        case .saved:
            return "Protected"
        case .attentionNeeded:
            return "Attention"
        }
    }

    var labelColor: Color {
        switch self {
        case .armed, .capturing: return .white
        case .detected: return DJToken.mutedForeground
        default: return tint ?? .primary
        }
    }

    var isFlashing: Bool { self == .launching }
    var isPulsing: Bool {
        if case .capturing = self { return true }
        return false
    }

    var accessibilityDescription: String {
        switch self {
        case .launching: return "Starting up"
        case .noSource: return "No protection source"
        case .detected(let name): return name.map { "\($0) detected" } ?? "Source detected"
        case .ready(let name): return name.map { "\($0) ready, not armed" } ?? "Ready for capture"
        case .armed(let name): return name.map { "\($0) detected, armed" } ?? "Armed"
        case .capturing(let name): return name.map { "Capturing \($0)" } ?? "Capturing"
        case .saving: return "Saving capture"
        case .saved: return "Set protected"
        case .attentionNeeded: return "Attention needed"
        case .failed(let reason): return "Capture error: \(reason)"
        }
    }
}

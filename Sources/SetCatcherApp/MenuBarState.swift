import SwiftUI
import SetCatcherCore

/// Visual state for the menu bar icon + adjacent label.
/// Derived from AppModel.captureState — see AppModel.menuBarState.
enum MenuBarState: Equatable {
    case launching
    case ready
    case armed(djAppName: String?)
    case capturing(djAppName: String?)
    case saving
    case saved
    case failed(String)

    static func derive(
        isLaunching: Bool,
        justSaved: Bool,
        phase: CapturePhase,
        djAppName: String?
    ) -> MenuBarState {
        if isLaunching { return .launching }
        if justSaved { return .saved }

        switch phase {
        case .idle, .requestingPermission, .needsScreenRecordingPermission:
            return .ready
        case .armed, .watching:
            return .armed(djAppName: djAppName)
        case .recording:
            return .capturing(djAppName: djAppName)
        case .saving:
            return .saving
        case .failed(let reason):
            return .failed(reason)
        }
    }

    var symbolName: String {
        switch self {
        case .launching: return "waveform"
        case .ready: return "waveform"
        case .armed: return "waveform.circle.fill"
        case .capturing: return "waveform.circle.fill"
        case .saving: return "arrow.down.circle.fill"
        case .saved: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }

    /// Stable cache key for the rendered AppKit image. Associated app names affect the adjacent
    /// text label, not the icon artwork.
    var iconCacheKey: String {
        switch self {
        case .launching, .ready: return "watching"
        case .armed: return "armed"
        case .capturing: return "capturing"
        case .saving: return "saving"
        case .saved: return "saved"
        case .failed: return "failed"
        }
    }

    /// Icon/status-dot color per the menu bar design handoff.
    var tint: Color? {
        switch self {
        case .launching, .ready: return DJToken.MenuBarStatus.watching
        case .armed: return DJToken.MenuBarStatus.armed
        case .capturing: return DJToken.MenuBarStatus.capturing
        case .saving, .saved: return DJToken.MenuBarStatus.saved
        case .failed: return DJToken.danger
        }
    }

    /// Text rendered next to the icon in the menu bar, if any.
    var label: String? {
        switch self {
        case .launching, .ready, .saving, .failed: return nil
        case .armed(let name): return name
        case .capturing(let name): return name
        case .saved: return "SAVED"
        }
    }

    var labelColor: Color {
        switch self {
        case .armed, .capturing: return .white
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
        case .ready: return "Ready for capture"
        case .armed(let name): return name.map { "\($0) detected, armed" } ?? "Armed"
        case .capturing(let name): return name.map { "Capturing \($0)" } ?? "Capturing"
        case .saving: return "Saving capture"
        case .saved: return "Set saved"
        case .failed(let reason): return "Capture error: \(reason)"
        }
    }
}

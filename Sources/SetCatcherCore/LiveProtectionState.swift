import Foundation

/// Live capture protection headline for the Live route and menu bar (dispatch-01).
public enum LiveProtectionState: String, Equatable, Sendable, CaseIterable {
    case noSource
    case detected
    case ready
    case armed
    case capturing
    case saving
    case setProtected
    case attentionNeeded

    /// Primary row never shows `setProtected`; completion uses toast + Last footer instead.
    public var primaryDisplay: LiveProtectionState {
        self == .setProtected ? .armed : self
    }

    public static func derive(input: LiveProtectionDeriveInput) -> LiveProtectionState {
        if input.capturePhase == .recording {
            return .capturing
        }
        if input.hasLiveAttention, !input.capturePhase.isActiveCapture {
            return .attentionNeeded
        }
        if input.justSaved {
            return .setProtected
        }
        switch input.capturePhase {
        case .saving:
            return .saving
        case .watching:
            return .armed
        case .armed:
            break
        case .idle, .requestingPermission, .needsScreenRecordingPermission:
            break
        case .recording:
            return .capturing
        case .failed:
            if input.hasLiveAttention {
                return .attentionNeeded
            }
            return input.hasSelectedSource ? .ready : .noSource
        }

        if input.hasSelectedSource, input.isWatching {
            return .armed
        }
        if input.hasSelectedSource {
            return .ready
        }
        if input.hasDetectedSource {
            return .detected
        }
        return .noSource
    }
}

public struct LiveProtectionDeriveInput: Equatable, Sendable {
    public var capturePhase: CapturePhase
    public var hasSelectedSource: Bool
    public var hasDetectedSource: Bool
    public var hasLiveAttention: Bool
    public var justSaved: Bool
    public var isWatching: Bool

    public init(
        capturePhase: CapturePhase,
        hasSelectedSource: Bool,
        hasDetectedSource: Bool,
        hasLiveAttention: Bool,
        justSaved: Bool,
        isWatching: Bool
    ) {
        self.capturePhase = capturePhase
        self.hasSelectedSource = hasSelectedSource
        self.hasDetectedSource = hasDetectedSource
        self.hasLiveAttention = hasLiveAttention
        self.justSaved = justSaved
        self.isWatching = isWatching
    }
}

private extension CapturePhase {
    var isActiveCapture: Bool {
        switch self {
        case .recording, .saving:
            return true
        case .idle, .requestingPermission, .needsScreenRecordingPermission, .armed, .watching, .failed:
            return false
        }
    }
}

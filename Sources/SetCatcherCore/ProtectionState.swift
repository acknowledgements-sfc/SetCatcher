import Foundation

/// Overall protection headline derived from scanning + folder reachability + setup (HANDOFF G2).
public enum ProtectionState: String, Equatable, Sendable, CaseIterable {
    case protected
    case needsSetup
    case scanning
    case attentionNeeded

    public var headline: String {
        switch self {
        case .protected:
            return "Protected"
        case .needsSetup:
            return "Needs Setup"
        case .scanning:
            return "Scanning"
        case .attentionNeeded:
            return "Attention Needed"
        }
    }

    public var explanation: String {
        switch self {
        case .protected:
            return "Your sets are being backed up automatically."
        case .needsSetup:
            return "Choose a recordings folder so SetCatcher can protect your sets."
        case .scanning:
            return "Checking watched folders for new recordings."
        case .attentionNeeded:
            return "A saved folder is unavailable, so new sets are not being archived."
        }
    }

    /// Priority: scanning → attentionNeeded → needsSetup → protected.
    public static func derive(
        isScanning: Bool,
        hasUnreachableFolder: Bool,
        hasConfiguredRecordingsFolder: Bool
    ) -> ProtectionState {
        if isScanning {
            return .scanning
        }
        if hasUnreachableFolder {
            return .attentionNeeded
        }
        if !hasConfiguredRecordingsFolder {
            return .needsSetup
        }
        return .protected
    }
}

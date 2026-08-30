import Foundation

/// Per-app setup tile state (HANDOFF G5). Display names are load-bearing copy.
public enum AppSetupState: String, Equatable, Sendable, CaseIterable {
    case watching
    case saving
    case recordingDetected
    case archived
    case needsFolderAccess
    case appNotFound
    case attentionNeeded
    case error

    public var displayName: String {
        switch self {
        case .watching:
            return "Watching"
        case .saving:
            return "Saving"
        case .recordingDetected:
            return "Recording Detected"
        case .archived:
            return "Archived"
        case .needsFolderAccess:
            return "Needs folder access"
        case .appNotFound:
            return "App not found"
        case .attentionNeeded:
            return "Attention Needed"
        case .error:
            return "Error"
        }
    }

    public var toneKind: String {
        switch self {
        case .watching, .archived:
            return "ok"
        case .saving:
            return "info"
        case .recordingDetected, .needsFolderAccess, .appNotFound:
            return "warn"
        case .attentionNeeded, .error:
            return "danger"
        }
    }

    /// Derive tile state from configured (bookmarked) folders only — never from probe-discovered paths.
    public static func derive(
        scanResults: [FolderScanResult],
        hasConfiguredRecordingsFolder: Bool,
        configuredFoldersReachable: Bool,
        appNotInstalledOrRunning: Bool,
        isScanning: Bool,
        hasRecentUnstableRecording: Bool
    ) -> AppSetupState {
        if scanResults.contains(where: { $0.errorDescription != nil }) {
            return .error
        }

        if scanResults.contains(where: { !$0.pendingRecordingURLs.isEmpty }) {
            return .recordingDetected
        }

        if scanResults.contains(where: { !$0.archivedSessions.isEmpty }) {
            return .archived
        }

        if !hasConfiguredRecordingsFolder {
            return appNotInstalledOrRunning ? .appNotFound : .needsFolderAccess
        }

        if !configuredFoldersReachable {
            return .attentionNeeded
        }

        if isScanning {
            return .saving
        }

        if hasRecentUnstableRecording {
            return .recordingDetected
        }

        return .watching
    }
}

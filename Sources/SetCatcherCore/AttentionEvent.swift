import Foundation

/// User-facing attention kinds for Live recovery panels (dispatch-04).
public enum AttentionKind: String, Codable, Sendable, CaseIterable {
    case folderMoved
    case folderMissing
    case permissionDenied
    case diskFull
    case saveFailed
    case screenRecording
    case sourceUnreadable
}

public extension AttentionKind {
    /// Recovery is intentionally sequential: restore a writable destination before source fixes.
    var recoveryPriority: Int {
        switch self {
        case .diskFull: return 0
        case .saveFailed: return 1
        case .permissionDenied: return 2
        case .folderMoved: return 3
        case .folderMissing: return 4
        case .screenRecording: return 5
        case .sourceUnreadable: return 6
        }
    }
}

/// One recoverable attention condition. Derived in AppModel; never persists audio or track titles.
public struct AttentionEvent: Equatable, Sendable, Identifiable {
    public var id: String
    public var kind: AttentionKind
    public var title: String
    public var body: String
    public var warning: String?
    public var reassurance: String
    public var primaryActionTitle: String
    public var secondaryActionTitles: [String]
    public var relatedAppID: String?
    /// For folderMoved: discovered destination path. For other kinds, optional context path.
    public var relatedPath: String?

    public init(
        id: String,
        kind: AttentionKind,
        title: String = "Attention Needed",
        body: String,
        warning: String? = nil,
        reassurance: String,
        primaryActionTitle: String,
        secondaryActionTitles: [String] = [],
        relatedAppID: String? = nil,
        relatedPath: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.body = body
        self.warning = warning
        self.reassurance = reassurance
        self.primaryActionTitle = primaryActionTitle
        self.secondaryActionTitles = secondaryActionTitles
        self.relatedAppID = relatedAppID
        self.relatedPath = relatedPath
    }

    public static func folderMissing(appID: String, appName: String, path: String) -> AttentionEvent {
        AttentionEvent(
            id: "folder-missing-\(appID)",
            kind: .folderMissing,
            body: "\(path) no longer exists",
            warning: "Your next set won't be protected until you choose a new folder.",
            reassurance: "Previously protected sets are safe — they're already archived.",
            primaryActionTitle: "Fix Folder",
            secondaryActionTitles: ["Open Recovery"],
            relatedAppID: appID
        )
    }

    public static func permissionDenied(appID: String, path: String) -> AttentionEvent {
        AttentionEvent(
            id: "permission-denied-\(appID)",
            kind: .permissionDenied,
            body: "SetCatcher can't read \(path)",
            warning: "New recordings can't be protected until access is granted.",
            reassurance: "macOS sometimes resets folder permissions after updates. Granting access takes about 5 seconds.",
            primaryActionTitle: "Grant access…",
            secondaryActionTitles: ["Open Recovery", "Open System Settings"],
            relatedAppID: appID
        )
    }

    public static func folderMoved(appID: String, fromPath: String, toPath: String) -> AttentionEvent {
        AttentionEvent(
            id: "folder-moved-\(appID)",
            kind: .folderMoved,
            body: "Your recording folder was moved from \(fromPath) to \(toPath)",
            warning: "Your next set won't be protected until this is resolved.",
            reassurance: "SetCatcher found your folder at the new location.",
            primaryActionTitle: "Use new location",
            secondaryActionTitles: ["Choose folder…", "Open Recovery"],
            relatedAppID: appID,
            relatedPath: toPath
        )
    }

    public static func screenRecordingDenied() -> AttentionEvent {
        AttentionEvent(
            id: "screen-recording",
            kind: .screenRecording,
            body: "Screen & System Audio Recording permission is required",
            warning: "App audio Capture can't arm until access is granted.",
            reassurance: "Folder Protection and Input device Capture still work.",
            primaryActionTitle: "Open Screen Recording Settings",
            secondaryActionTitles: ["Retry"]
        )
    }

    public static func saveFailed(reason: String, temporaryRecordingRetained: Bool = false) -> AttentionEvent {
        AttentionEvent(
            id: "save-failed",
            kind: .saveFailed,
            body: "A set could not be saved",
            warning: reason,
            reassurance: temporaryRecordingRetained
                ? "The temporary recording is retained. Source DJ app files were not moved."
                : "Source DJ app files were not moved.",
            primaryActionTitle: temporaryRecordingRetained ? "Retry Save" : "Open Live",
            secondaryActionTitles: temporaryRecordingRetained
                ? ["Save Elsewhere…", "Reveal Temporary Recording"]
                : ["Open Archive Folder"]
        )
    }

    public static func diskFull(remainingGigabytes: Double) -> AttentionEvent {
        let remaining = String(format: "%.1f", remainingGigabytes)
        return AttentionEvent(
            id: "disk-full",
            kind: .diskFull,
            body: "Low disk space — \(remaining) GB remaining",
            warning: "Capture may stop if free space runs out.",
            reassurance: "SetCatcher needs at least 2 GB free to safely capture a full set. Previously protected sets are already archived.",
            primaryActionTitle: "Open Storage Settings",
            secondaryActionTitles: ["Open Archive Folder"]
        )
    }

    public static func sourceUnreadable(sourceName: String) -> AttentionEvent {
        AttentionEvent(
            id: "source-unreadable-\(sourceName)",
            kind: .sourceUnreadable,
            body: "\(sourceName) not responding",
            warning: "SetCatcher can't read audio from this source.",
            reassurance: "This usually happens when the app closes or the audio device changes. If the source is still running, try arming again.",
            primaryActionTitle: "Retry",
            secondaryActionTitles: ["Open Capture"]
        )
    }
}

import Foundation

/// Which safety nets run when Pioneer USB input is present.
/// Folder Protection of granted folders always continues; this never deletes archives.
public enum DualRoutePosture: String, Codable, Equatable, Sendable, CaseIterable {
    case both
    case folderPrimaryInputOnDemand
    case folderOnly
    case inputOnly

    public var displayName: String {
        switch self {
        case .both:
            return "Both"
        case .folderPrimaryInputOnDemand:
            return "Folder primary, Input on-demand"
        case .folderOnly:
            return "Folder only"
        case .inputOnly:
            return "Input only"
        }
    }

    public var explanation: String {
        switch self {
        case .both:
            return "Folder Protection watches DJ-app recordings. When Pioneer USB input is present, Input Capture records automatically so forgetting Record still produces an archive. Changing this never deletes existing archives."
        case .folderPrimaryInputOnDemand:
            return "Folder Protection stays on. Input Capture auto-selects Pioneer hardware and waits for you to press Start. Changing this never deletes existing archives."
        case .folderOnly:
            return "Folder Protection stays on. Input Capture is available manually. Pioneer hardware does not auto-switch or auto-record. Changing this never deletes existing archives."
        case .inputOnly:
            return "Input Capture records Pioneer USB output automatically. Folder Protection still copies recordings if the DJ app writes them; overlapping files are shown as one set. Changing this never deletes existing archives."
        }
    }
}

public enum DualRoutePolicy {
    public static func shouldAutoSwitchToInput(
        posture: DualRoutePosture,
        pioneerPresent: Bool,
        userSuppressedAutoSwitch: Bool
    ) -> Bool {
        guard pioneerPresent, !userSuppressedAutoSwitch else { return false }
        switch posture {
        case .both, .inputOnly:
            return true
        case .folderPrimaryInputOnDemand, .folderOnly:
            return false
        }
    }

    public static func shouldUnattendedWatch(
        posture: DualRoutePosture,
        pioneerPresent: Bool,
        userDisarmedInput: Bool
    ) -> Bool {
        guard pioneerPresent, !userDisarmedInput else { return false }
        switch posture {
        case .both, .inputOnly:
            return true
        case .folderPrimaryInputOnDemand, .folderOnly:
            return false
        }
    }

    public static func shouldAutoSelectPioneer(posture: DualRoutePosture) -> Bool {
        switch posture {
        case .both, .folderPrimaryInputOnDemand, .inputOnly:
            return true
        case .folderOnly:
            return false
        }
    }

    public static func shouldFallBackToAppAudio(
        posture: DualRoutePosture,
        pioneerPresent: Bool,
        userSuppressedAutoSwitch: Bool
    ) -> Bool {
        guard !pioneerPresent, !userSuppressedAutoSwitch else { return false }
        switch posture {
        case .both, .inputOnly:
            return true
        case .folderPrimaryInputOnDemand, .folderOnly:
            return false
        }
    }
}

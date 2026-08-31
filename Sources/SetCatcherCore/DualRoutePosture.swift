import Foundation

/// Which safety nets run when a trusted DJ hardware USB feed is present.
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
            return "Folder Protection watches DJ-app recordings. When a trusted hardware USB feed is present, Input Capture records automatically so forgetting Record still produces an archive. Changing this never deletes existing archives."
        case .folderPrimaryInputOnDemand:
            return "Folder Protection stays on. Input Capture auto-selects trusted hardware and waits for you to press Start. Changing this never deletes existing archives."
        case .folderOnly:
            return "Folder Protection stays on. Input Capture is available manually. Hardware does not auto-switch or auto-record. Changing this never deletes existing archives."
        case .inputOnly:
            return "Input Capture records trusted hardware USB output automatically. Folder Protection still copies recordings if the DJ app writes them; overlapping files are shown as one set. Changing this never deletes existing archives."
        }
    }
}

public enum DualRoutePolicy {
    public static func shouldAutoSwitchToInput(
        posture: DualRoutePosture,
        hardwarePresent: Bool,
        userSuppressedAutoSwitch: Bool
    ) -> Bool {
        guard hardwarePresent, !userSuppressedAutoSwitch else { return false }
        switch posture {
        case .both, .inputOnly:
            return true
        case .folderPrimaryInputOnDemand, .folderOnly:
            return false
        }
    }

    public static func shouldUnattendedWatch(
        posture: DualRoutePosture,
        hardwarePresent: Bool,
        userDisarmedInput: Bool
    ) -> Bool {
        guard hardwarePresent, !userDisarmedInput else { return false }
        switch posture {
        case .both, .inputOnly:
            return true
        case .folderPrimaryInputOnDemand, .folderOnly:
            return false
        }
    }

    public static func shouldAutoSelectHardware(posture: DualRoutePosture) -> Bool {
        switch posture {
        case .both, .folderPrimaryInputOnDemand, .inputOnly:
            return true
        case .folderOnly:
            return false
        }
    }

    /// - Important: Prefer `shouldAutoSelectHardware`. Kept for call sites that still say Pioneer.
    public static func shouldAutoSelectPioneer(posture: DualRoutePosture) -> Bool {
        shouldAutoSelectHardware(posture: posture)
    }

    public static func shouldFallBackToAppAudio(
        posture: DualRoutePosture,
        hardwarePresent: Bool,
        userSuppressedAutoSwitch: Bool
    ) -> Bool {
        guard !hardwarePresent, !userSuppressedAutoSwitch else { return false }
        switch posture {
        case .both, .inputOnly:
            return true
        case .folderPrimaryInputOnDemand, .folderOnly:
            return false
        }
    }
}

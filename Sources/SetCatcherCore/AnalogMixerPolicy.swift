import Foundation

/// Pure policy for Analog Mixer pin + dump-folder readiness.
public enum AnalogMixerPolicy {
    /// Analog Mixer counts as configured when a rec-out is pinned or a dump folder is granted.
    public static func isConfigured(
        pinnedDeviceID: String?,
        hasDumpFolder: Bool
    ) -> Bool {
        if let pinnedDeviceID, !pinnedDeviceID.isEmpty { return true }
        return hasDumpFolder
    }

    /// Unattended Input Capture is allowed only when the selected device matches the pin.
    public static func shouldUnattendedWatch(
        pinnedDeviceID: String?,
        selectedDeviceID: String?,
        userDisarmedInput: Bool
    ) -> Bool {
        guard !userDisarmedInput else { return false }
        guard let pinnedDeviceID, !pinnedDeviceID.isEmpty else { return false }
        return pinnedDeviceID == selectedDeviceID
    }

    public static func missingPinnedDeviceMessage(deviceName: String) -> String {
        "The pinned rec-out is missing. Plug in \(deviceName), then Refresh. Everything already in your archive is safe."
    }

    public static let needsSetupMessage =
        "Analog Mixer needs a rec-out or a dump folder before SetCatcher can protect vinyl sets."

    public static func listeningSummary(deviceName: String) -> String {
        "Listening to \(deviceName). Recording starts when audio is detected; idle silence saves the take automatically."
    }
}

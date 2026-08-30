import Foundation

/// Identity and availability for the SetCatcher virtual audio driver.
///
/// The intended plugin is original SetCatcher code (`SetCatcherAudio.driver`), modeled after
/// the MIT-licensed libASPL framework. Do not copy BlackHole (GPLv3) into this tree.
/// If libASPL sources are vendored later, preserve the MIT copyright notice.
public enum SetCatcherAudioDriverIdentity {
    public static let pluginFileName = "SetCatcherAudio.driver"
    public static let deviceName = "SetCatcher Audio"
    public static let manufacturer = "SetCatcher"
    public static let bundleIdentifier = "app.setcatcher.SetCatcherAudio"

    /// Stable Core Audio device UID the driver publishes. `AudioInputDevice.id` is already
    /// the UID (`kAudioDevicePropertyDeviceUID`), so identity is an exact match on it.
    public static let deviceUID = "app.setcatcher.SetCatcherAudio:device"
    public static let deviceNameHints = ["SetCatcher Audio", "SetCatcher Audio"]

    /// Identity is the UID. A name match is accepted only as a secondary signal, and only
    /// for a virtual device — names are user-visible, localizable, and trivially spoofed by
    /// any other vendor's aggregate.
    public static func matches(_ device: AudioInputDevice) -> Bool {
        if device.id == deviceUID { return true }
        guard device.transportType == .virtual else { return false }
        return deviceNameHints.contains { hint in
            device.name.caseInsensitiveCompare(hint) == .orderedSame
        }
    }

    /// True only for an exact UID match, with no name fallback.
    public static func matchesByUID(_ device: AudioInputDevice) -> Bool {
        device.id == deviceUID
    }

    public static func matchingDevice(in devices: [AudioInputDevice]) -> AudioInputDevice? {
        devices.first(where: matches)
    }

    public static func availability(in devices: [AudioInputDevice]) -> SetCatcherAudioDriverAvailability {
        guard let device = matchingDevice(in: devices) else { return .missing }
        return .available(deviceID: device.id)
    }
}

public enum SetCatcherAudioDriverAvailability: Equatable, Sendable {
    case available(deviceID: String)
    case missing
    case permissionOrInstallNeeded
    case presentButUnusable(reason: String)

    public var isAvailable: Bool {
        if case .available = self { return true }
        return false
    }
}

public enum SetCatcherAudioDriverError: Error, Equatable, Sendable {
    case driverMissing
    case permissionOrInstallNeeded
    case appAudioUnavailable
    case verificationFailed

    public var recoveryReason: LiveCaptureRecoveryReason {
        switch self {
        case .driverMissing:
            return .driverMissing
        case .permissionOrInstallNeeded:
            return .permissionOrInstallNeeded
        case .appAudioUnavailable, .verificationFailed:
            return .appAudioUnavailable
        }
    }
}

/// Prototype client: discovery and backend selection only. No installer, no HAL plugin.
public enum SetCatcherAudioDriverClient {
    public static func availability(in devices: [AudioInputDevice]) -> SetCatcherAudioDriverAvailability {
        SetCatcherAudioDriverIdentity.availability(in: devices)
    }

    public static func recordingBackend(
        availability: SetCatcherAudioDriverAvailability
    ) -> LiveCaptureRecordingBackend {
        switch availability {
        case .available:
            return .setcatcherDriver
        case .missing, .permissionOrInstallNeeded, .presentButUnusable:
            return .none
        }
    }
}

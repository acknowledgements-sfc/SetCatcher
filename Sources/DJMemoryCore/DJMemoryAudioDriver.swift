import Foundation

/// Identity and availability for the DJMemory virtual audio driver.
///
/// The intended plugin is original DJMemory code (`DJMemoryAudio.driver`), modeled after
/// the MIT-licensed libASPL framework. Do not copy BlackHole (GPLv3) into this tree.
/// If libASPL sources are vendored later, preserve the MIT copyright notice.
public enum DJMemoryAudioDriverIdentity {
    public static let pluginFileName = "DJMemoryAudio.driver"
    public static let deviceName = "DJMemory Audio"
    public static let manufacturer = "DJMemory"
    public static let bundleIdentifier = "app.djmemory.DJMemoryAudio"

    /// Stable Core Audio device UID the driver publishes. `AudioInputDevice.id` is already
    /// the UID (`kAudioDevicePropertyDeviceUID`), so identity is an exact match on it.
    public static let deviceUID = "app.djmemory.DJMemoryAudio:device"
    public static let deviceNameHints = ["DJMemory Audio"]

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

    public static func availability(in devices: [AudioInputDevice]) -> DJMemoryAudioDriverAvailability {
        guard let device = matchingDevice(in: devices) else { return .missing }
        return .available(deviceID: device.id)
    }
}

public enum DJMemoryAudioDriverAvailability: Equatable, Sendable {
    case available(deviceID: String)
    case missing
    case permissionOrInstallNeeded
    case presentButUnusable(reason: String)

    public var isAvailable: Bool {
        if case .available = self { return true }
        return false
    }
}

public enum DJMemoryAudioDriverError: Error, Equatable, Sendable {
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
public enum DJMemoryAudioDriverClient {
    public static func availability(in devices: [AudioInputDevice]) -> DJMemoryAudioDriverAvailability {
        DJMemoryAudioDriverIdentity.availability(in: devices)
    }

    public static func recordingBackend(
        availability: DJMemoryAudioDriverAvailability
    ) -> LiveCaptureRecordingBackend {
        switch availability {
        case .available:
            return .djmemoryDriver
        case .missing, .permissionOrInstallNeeded, .presentButUnusable:
            return .none
        }
    }
}

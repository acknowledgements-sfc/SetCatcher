import CoreAudio
import Foundation

public enum AudioInputDeviceCatalogError: Error, Equatable, Sendable {
    case streamFormatUnavailable(OSStatus)
}

/// Core Audio transport type for an input device, used to decide whether a device is safe to
/// auto-select / record from. Sourced from `kAudioDevicePropertyTransportType`, which is
/// robust and localization-independent (unlike device names).
public enum AudioDeviceTransport: Equatable, Sendable {
    case builtIn
    case aggregate
    case virtual
    case pci
    case usb
    case fireWire
    case bluetooth
    case bluetoothLE
    case hdmi
    case displayPort
    case airPlay
    case avb
    case thunderbolt
    case continuityCapture
    /// Transport type was unreadable or is a value we do not model. Treated as untrusted.
    case unknown

    /// Stable label for archive/session metadata (not localized).
    public var archiveLabel: String {
        switch self {
        case .builtIn: return "builtIn"
        case .aggregate: return "aggregate"
        case .virtual: return "virtual"
        case .pci: return "pci"
        case .usb: return "usb"
        case .fireWire: return "fireWire"
        case .bluetooth: return "bluetooth"
        case .bluetoothLE: return "bluetoothLE"
        case .hdmi: return "hdmi"
        case .displayPort: return "displayPort"
        case .airPlay: return "airPlay"
        case .avb: return "avb"
        case .thunderbolt: return "thunderbolt"
        case .continuityCapture: return "continuityCapture"
        case .unknown: return "unknown"
        }
    }

    public init(rawValue: UInt32?) {
        guard let rawValue else { self = .unknown; return }
        switch rawValue {
        case kAudioDeviceTransportTypeBuiltIn: self = .builtIn
        case kAudioDeviceTransportTypeAggregate: self = .aggregate
        case kAudioDeviceTransportTypeVirtual: self = .virtual
        case kAudioDeviceTransportTypePCI: self = .pci
        case kAudioDeviceTransportTypeUSB: self = .usb
        case kAudioDeviceTransportTypeFireWire: self = .fireWire
        case kAudioDeviceTransportTypeBluetooth: self = .bluetooth
        case kAudioDeviceTransportTypeBluetoothLE: self = .bluetoothLE
        case kAudioDeviceTransportTypeHDMI: self = .hdmi
        case kAudioDeviceTransportTypeDisplayPort: self = .displayPort
        case kAudioDeviceTransportTypeAirPlay: self = .airPlay
        case kAudioDeviceTransportTypeAVB: self = .avb
        case kAudioDeviceTransportTypeThunderbolt: self = .thunderbolt
        case kAudioDeviceTransportTypeContinuityCaptureWired,
             kAudioDeviceTransportTypeContinuityCaptureWireless:
            self = .continuityCapture
        default: self = .unknown
        }
    }
}

/// Whether an input device may be used for capture, and how. Enforces the core invariant that
/// SetCatcher never silently records from an ambient/system microphone.
public enum AudioInputDeviceSafety: Equatable, Sendable {
    /// Known DJ hardware (or a verified DJ-software virtual device for the detected app).
    /// May be auto-selected AND auto-armed.
    case trustedAutoSelectable(reason: String)
    /// The user may choose this device explicitly, but it is never auto-selected.
    case manualOnly(reason: String)
    /// Never selected, armed, or recorded from — an ambient/system microphone.
    case blocked(reason: String)
}

public struct AudioInputDevice: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let manufacturer: String
    public let transportType: AudioDeviceTransport

    public init(id: String, name: String, manufacturer: String, transportType: AudioDeviceTransport = .unknown) {
        self.id = id
        self.name = name
        self.manufacturer = manufacturer
        self.transportType = transportType
    }

    public var isLikelyPioneerDJHardware: Bool {
        let haystack = "\(name) \(manufacturer)".lowercased()
        return ["djm", "xdj", "cdj", "pioneer", "alphatheta"].contains { haystack.contains($0) }
    }

    /// Trusted DJ hardware USB feed for DualRoute auto-select. Never includes unknown
    /// USB interfaces — those require an explicit Analog Mixer pin.
    public var isTrustedDJHardwareFeed: Bool {
        SupportedHardware.isTrustedHardwareFeed(self)
    }

    /// Capture-safety classification for this device. See `AudioInputDeviceCatalog.safety(for:)`.
    /// Context-free: a DJ-software virtual device is never auto-trusted here (needs a running app).
    public var safety: AudioInputDeviceSafety {
        AudioInputDeviceCatalog.safety(for: self)
    }

    public func safety(currentSoftwareIDs: Set<String>) -> AudioInputDeviceSafety {
        AudioInputDeviceCatalog.safety(for: self, currentSoftwareIDs: currentSoftwareIDs)
    }

    /// An ambient/system microphone that must never be selected, armed, or recorded from.
    public var isBlockedInput: Bool {
        if case .blocked = safety { return true }
        return false
    }

    /// Safe to auto-select and auto-arm without explicit user action.
    public var isTrustedAutoSelectable: Bool {
        if case .trustedAutoSelectable = safety { return true }
        return false
    }
}

public enum AudioInputDeviceCatalog {
    public static func listInputs() -> [AudioInputDevice] {
        let devices = coreAudioInputDevices()
        return devices.sorted { lhs, rhs in
            if lhs.isTrustedDJHardwareFeed != rhs.isTrustedDJHardwareFeed {
                return lhs.isTrustedDJHardwareFeed && !rhs.isTrustedDJHardwareFeed
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    /// Classifies whether a device may be used for capture. The block list uses Core Audio
    /// transport type (not device names) so it is robust across locales and renamed devices.
    ///
    /// Blocked ambient/system mics: built-in, Bluetooth (AirPods/headsets), and Continuity
    /// Camera / iPhone mics. Trusted: known Pioneer DJ hardware (PR2 also trusts a verified
    /// DJ-software virtual device for the currently detected app). Everything else — unknown
    /// USB interfaces, aggregate devices, unreadable transport — is `manualOnly`: usable only
    /// when the user picks it explicitly, never auto-selected.
    ///
    /// Known limitation: a USB webcam microphone presents as `.usb` and is indistinguishable
    /// from a real audio interface here, so it lands in `manualOnly` rather than `blocked`.
    public static func safety(
        for device: AudioInputDevice,
        currentSoftwareIDs: Set<String> = []
    ) -> AudioInputDeviceSafety {
        switch device.transportType {
        case .builtIn:
            return .blocked(reason: "Built-in microphone")
        case .bluetooth, .bluetoothLE:
            return .blocked(reason: "Bluetooth microphone")
        case .continuityCapture:
            return .blocked(reason: "iPhone / Continuity Camera microphone")
        default:
            break
        }
        if device.isTrustedDJHardwareFeed {
            let reason: String
            if let profile = SupportedHardware.profile(matching: device) {
                switch profile.vendor {
                case .pioneer:
                    reason = "Pioneer DJ hardware"
                case .denon:
                    reason = "Denon DJ hardware"
                case .rane:
                    reason = "Rane DJ hardware"
                case .genericMixer:
                    reason = "Pinned mixer rec-out"
                }
            } else if device.isLikelyPioneerDJHardware {
                reason = "Pioneer DJ hardware"
            } else {
                reason = "DJ hardware"
            }
            return .trustedAutoSelectable(reason: reason)
        }
        if let software = matchingVirtualSoftware(for: device, currentSoftwareIDs: currentSoftwareIDs) {
            return .trustedAutoSelectable(reason: "\(software.displayName) virtual audio device")
        }
        return .manualOnly(reason: "Unrecognized input — choose it explicitly to use it")
    }

    /// True only when the device is a verified virtual loopback for `software`:
    /// input-capable, Core Audio transport `.virtual`, and name/manufacturer contains a hint.
    /// `"Serato"` alone must not match — a branded controller is not the virtual mix device.
    public static func matchesDJSoftwareVirtualAudioDevice(
        _ device: AudioInputDevice,
        for software: DJSoftware
    ) -> Bool {
        guard device.transportType == .virtual else { return false }
        guard !software.virtualAudioDeviceNameHints.isEmpty else { return false }
        return software.virtualAudioDeviceNameHints.contains { hint in
            hintMatchesVirtualDevice(hint, device: device)
        }
    }

    public static func virtualAudioDevice(
        for software: DJSoftware,
        in devices: [AudioInputDevice]
    ) -> AudioInputDevice? {
        let matches = devices.filter { matchesDJSoftwareVirtualAudioDevice($0, for: software) }
        let named = matches.first { device in
            software.virtualAudioDeviceNameHints.contains {
                device.name.localizedCaseInsensitiveContains($0)
            }
        }
        return named ?? matches.first
    }

    /// The auto-selection default: Pioneer hardware first, then a verified virtual device
    /// for a currently running/selected DJ app. Never falls back to an arbitrary first
    /// device — an unrecognized or blocked input must never be silently auto-selected.
    public static func preferredDefault(
        from devices: [AudioInputDevice] = listInputs(),
        currentSoftwareIDs: Set<String> = []
    ) -> AudioInputDevice? {
        let trusted = devices.filter { device in
            if case .trustedAutoSelectable = safety(for: device, currentSoftwareIDs: currentSoftwareIDs) {
                return true
            }
            return false
        }
        return trusted.first(where: \.isTrustedDJHardwareFeed) ?? trusted.first
    }

    /// Devices the user may pick in the input picker: everything except blocked ambient mics.
    public static func selectableInputs(from devices: [AudioInputDevice] = listInputs()) -> [AudioInputDevice] {
        devices.filter { !$0.isBlockedInput }
    }

    /// Core Audio object ID for a device UID, or nil when it is not an input that currently exists.
    public static func audioDeviceID(forUID uid: String) -> AudioDeviceID? {
        guard !uid.isEmpty else { return nil }
        return hardwareDeviceIDs().first { deviceID in
            inputChannelCount(deviceID) > 0
                && cfStringProperty(deviceID, kAudioDevicePropertyDeviceUID) == uid
        }
    }

    /// Input channel count for a device UID, or `0` when the device is missing or has no inputs.
    /// USB connection alone is not enough — a device with no input channels cannot be captured.
    public static func inputChannelCount(forUID uid: String) -> Int {
        guard let deviceID = audioDeviceID(forUID: uid) else { return 0 }
        return inputChannelCount(deviceID)
    }

    /// Whether the current input stream can be recorded (sample rate and at least one channel).
    public static func isSupportedCaptureFormat(forUID uid: String) -> Bool {
        guard let deviceID = audioDeviceID(forUID: uid),
              let format = try? inputStreamFormat(for: deviceID)
        else { return false }
        return isSupportedCaptureFormat(format)
    }

    public static func isSupportedCaptureFormat(_ format: AudioStreamBasicDescription) -> Bool {
        format.mSampleRate > 0 && format.mChannelsPerFrame >= 1
    }

    /// Current input-scope stream format for a Core Audio device.
    public static func inputStreamFormat(
        for deviceID: AudioDeviceID
    ) throws -> AudioStreamBasicDescription {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamFormat,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var format = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        let status = AudioObjectGetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            &size,
            &format
        )
        guard status == noErr else {
            throw AudioInputDeviceCatalogError.streamFormatUnavailable(status)
        }
        return format
    }

    private static func matchingVirtualSoftware(
        for device: AudioInputDevice,
        currentSoftwareIDs: Set<String>
    ) -> DJSoftware? {
        guard !currentSoftwareIDs.isEmpty else { return nil }
        return SupportedDJSoftware.all.first { software in
            currentSoftwareIDs.contains(software.id)
                && matchesDJSoftwareVirtualAudioDevice(device, for: software)
        }
    }

    /// Hint must appear as a substring of name or manufacturer. A hint of
    /// `"Serato Virtual Audio"` therefore does not match a device whose only
    /// Serato-like token is manufacturer `"Serato"`.
    private static func hintMatchesVirtualDevice(_ hint: String, device: AudioInputDevice) -> Bool {
        let needle = hint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return false }
        return device.name.localizedCaseInsensitiveContains(needle)
            || device.manufacturer.localizedCaseInsensitiveContains(needle)
    }

    private static func coreAudioInputDevices() -> [AudioInputDevice] {
        hardwareDeviceIDs().compactMap { deviceID in
            guard inputChannelCount(deviceID) > 0 else { return nil }
            let uid = cfStringProperty(deviceID, kAudioDevicePropertyDeviceUID)
            guard !uid.isEmpty else { return nil }
            let name = cfStringProperty(deviceID, kAudioObjectPropertyName)
            let manufacturer = cfStringProperty(deviceID, kAudioObjectPropertyManufacturer)
            let transport = AudioDeviceTransport(rawValue: transportType(deviceID))
            return AudioInputDevice(id: uid, name: name, manufacturer: manufacturer, transportType: transport)
        }
    }

    private static func transportType(_ deviceID: AudioDeviceID) -> UInt32? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var transport: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &transport)
        guard status == noErr else { return nil }
        return transport
    }

    private static func hardwareDeviceIDs() -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        let systemObject = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyDataSize(systemObject, &address, 0, nil, &dataSize) == noErr,
              dataSize > 0
        else { return [] }

        let count = Int(dataSize) / MemoryLayout<AudioObjectID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(systemObject, &address, 0, nil, &dataSize, &ids) == noErr else {
            return []
        }
        return ids
    }

    private static func inputChannelCount(_ deviceID: AudioDeviceID) -> Int {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &dataSize) == noErr,
              dataSize > 0
        else { return 0 }

        let raw = UnsafeMutableRawPointer.allocate(
            byteCount: Int(dataSize),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { raw.deallocate() }
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, raw) == noErr else {
            return 0
        }
        let list = raw.assumingMemoryBound(to: AudioBufferList.self)
        return UnsafeMutableAudioBufferListPointer(list).reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    private static func cfStringProperty(
        _ deviceID: AudioDeviceID,
        _ selector: AudioObjectPropertySelector
    ) -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        var value: Unmanaged<CFString>?
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &value)
        guard status == noErr, let value else { return "" }
        return value.takeRetainedValue() as String
    }
}

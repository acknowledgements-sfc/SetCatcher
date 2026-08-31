import Foundation

public enum HardwareVendor: String, Codable, Sendable {
    case pioneer
    case denon
    case rane
    case genericMixer
}

public enum HardwareClass: String, Codable, Sendable {
    case mixer
    case allInOne
    case player
}

public struct HardwareProfile: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let vendor: HardwareVendor
    public let hardwareClass: HardwareClass
    public let captureHint: String
    public let usbRecFolderHint: String?
    public let needsMixerForMaster: Bool
    /// Extra lowercase substrings matched against Core Audio name + manufacturer.
    public let matchHints: [String]

    public init(
        id: String,
        displayName: String,
        vendor: HardwareVendor = .pioneer,
        hardwareClass: HardwareClass,
        captureHint: String,
        usbRecFolderHint: String?,
        needsMixerForMaster: Bool,
        matchHints: [String] = []
    ) {
        self.id = id
        self.displayName = displayName
        self.vendor = vendor
        self.hardwareClass = hardwareClass
        self.captureHint = captureHint
        self.usbRecFolderHint = usbRecFolderHint
        self.needsMixerForMaster = needsMixerForMaster
        self.matchHints = matchHints
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        displayName = try c.decode(String.self, forKey: .displayName)
        vendor = try c.decodeIfPresent(HardwareVendor.self, forKey: .vendor) ?? .pioneer
        hardwareClass = try c.decode(HardwareClass.self, forKey: .hardwareClass)
        captureHint = try c.decode(String.self, forKey: .captureHint)
        usbRecFolderHint = try c.decodeIfPresent(String.self, forKey: .usbRecFolderHint)
        needsMixerForMaster = try c.decode(Bool.self, forKey: .needsMixerForMaster)
        matchHints = try c.decodeIfPresent([String].self, forKey: .matchHints) ?? []
    }

    /// True when this unit can expose a USB master / REC OUT feed to the Mac.
    /// Players never can; USB presence of a CDJ is not a capturable mix.
    public var canProvideUSBMasterFeed: Bool {
        !needsMixerForMaster && (hardwareClass == .mixer || hardwareClass == .allInOne)
    }

    /// One-line caption for the hardware adapter list.
    public var adapterListCaption: String {
        if needsMixerForMaster {
            return "needs mixer for master"
        }
        switch hardwareClass {
        case .mixer:
            return "USB Capture"
        case .player:
            return "needs mixer for master"
        case .allInOne:
            if id == "xdj-xz" {
                return "laptop + USB / Input Capture"
            }
            if vendor == .denon {
                return "USB Sessions / Input Capture"
            }
            return "USB MASTER REC"
        }
    }
}

public enum SupportedHardware {
    public static let pioneerUSBRecFolderName = "PIONEERREC"
    public static let denonSessionsFolderName = "Sessions"

    public static let all: [HardwareProfile] = [
        HardwareProfile(id: "xdj-rx2", displayName: "XDJ-RX2", vendor: .pioneer, hardwareClass: .allInOne, captureHint: "Prefer MASTER REC to USB (PIONEERREC). Use Capture when this unit or a DJM appears as a Core Audio input.", usbRecFolderHint: pioneerUSBRecFolderName, needsMixerForMaster: false),
        HardwareProfile(id: "xdj-rx3", displayName: "XDJ-RX3", vendor: .pioneer, hardwareClass: .allInOne, captureHint: "MASTER REC writes WAV files to PIONEERREC on USB port 2.", usbRecFolderHint: pioneerUSBRecFolderName, needsMixerForMaster: false),
        HardwareProfile(id: "xdj-xz", displayName: "XDJ-XZ", vendor: .pioneer, hardwareClass: .allInOne, captureHint: "Laptop + USB: Folder Protection copies Serato or rekordbox recordings; Input Capture records the XZ USB output if Record was forgotten. USB MASTER REC (PIONEERREC) is a Manual Setup fallback when the Mac is out of the audio path.", usbRecFolderHint: pioneerUSBRecFolderName, needsMixerForMaster: false),
        HardwareProfile(id: "xdj-az", displayName: "XDJ-AZ", vendor: .pioneer, hardwareClass: .allInOne, captureHint: "Archive MASTER REC from PIONEERREC, or Capture via DJM USB input.", usbRecFolderHint: pioneerUSBRecFolderName, needsMixerForMaster: false),
        HardwareProfile(id: "xdj-1000", displayName: "XDJ-1000", vendor: .pioneer, hardwareClass: .player, captureHint: "A player, not an all-in-one: it outputs its own deck audio, not the mixer's master. Capture the DJM/mixer feed for the full set.", usbRecFolderHint: nil, needsMixerForMaster: true),
        HardwareProfile(id: "cdj-2000", displayName: "CDJ-2000", vendor: .pioneer, hardwareClass: .player, captureHint: "CDJs do not record the master mix. SetCatcher can protect only what reaches the Mac. Route USB through this laptop or a DJM, or grant a PIONEERREC folder. A mixer that never reaches the Mac is Manual Setup.", usbRecFolderHint: nil, needsMixerForMaster: true),
        HardwareProfile(id: "cdj-2000nxs", displayName: "CDJ-2000NXS", vendor: .pioneer, hardwareClass: .player, captureHint: "CDJs do not record the master mix. SetCatcher can protect only what reaches the Mac. Route USB through this laptop or a DJM, or grant a PIONEERREC folder. A mixer that never reaches the Mac is Manual Setup.", usbRecFolderHint: nil, needsMixerForMaster: true),
        HardwareProfile(id: "cdj-3000", displayName: "CDJ-3000", vendor: .pioneer, hardwareClass: .player, captureHint: "CDJs do not record the master mix. SetCatcher can protect only what reaches the Mac. Route USB through this laptop or a DJM, or grant a PIONEERREC folder. A mixer that never reaches the Mac is Manual Setup.", usbRecFolderHint: nil, needsMixerForMaster: true),
        HardwareProfile(id: "djm-900", displayName: "DJM-900", vendor: .pioneer, hardwareClass: .mixer, captureHint: "Install Pioneer DJM USB driver. Assign MIX (REC OUT), then select the DJM in Capture.", usbRecFolderHint: nil, needsMixerForMaster: false),
        HardwareProfile(id: "djm-v10", displayName: "DJM-V10", vendor: .pioneer, hardwareClass: .mixer, captureHint: "Install Pioneer DJM-V10 USB driver. Assign MIX (REC OUT), then select in Capture.", usbRecFolderHint: nil, needsMixerForMaster: false),
        HardwareProfile(id: "djm-v10lf", displayName: "DJM-V10LF", vendor: .pioneer, hardwareClass: .mixer, captureHint: "Install Pioneer DJM-V10LF USB driver. Assign MIX (REC OUT), then select in Capture.", usbRecFolderHint: nil, needsMixerForMaster: false),
        HardwareProfile(id: "prime-4", displayName: "PRIME 4", vendor: .denon, hardwareClass: .allInOne, captureHint: "Standalone Engine OS writes WAV to Sessions on USB/SD. Grant that folder for Folder Protection. USB Input Capture only after Core Audio identity is measured.", usbRecFolderHint: denonSessionsFolderName, needsMixerForMaster: false, matchHints: ["prime 4"]),
        HardwareProfile(id: "prime-4-plus", displayName: "PRIME 4+", vendor: .denon, hardwareClass: .allInOne, captureHint: "Engine OS Sessions on USB/SD. Grant Sessions for Folder Protection.", usbRecFolderHint: denonSessionsFolderName, needsMixerForMaster: false, matchHints: ["prime 4+", "prime 4 plus"]),
        HardwareProfile(id: "sc-live-4", displayName: "SC LIVE 4", vendor: .denon, hardwareClass: .allInOne, captureHint: "Engine OS Sessions on USB/SD. Grant Sessions for Folder Protection.", usbRecFolderHint: denonSessionsFolderName, needsMixerForMaster: false, matchHints: ["sc live 4", "sc live", "sclive"]),
        HardwareProfile(id: "sc6000", displayName: "SC6000", vendor: .denon, hardwareClass: .player, captureHint: "Players do not record the master mix alone. Grant Sessions from a Prime/SC Live all-in-one, or Capture a mixer USB / Analog Mixer rec-out.", usbRecFolderHint: denonSessionsFolderName, needsMixerForMaster: true, matchHints: ["sc6000", "sc 6000"]),
        HardwareProfile(id: "seventy", displayName: "Seventy", vendor: .rane, hardwareClass: .mixer, captureHint: "Serato is the primary path. USB Input Capture needs a measured program pair (not DVS control tone). Session Out uses Analog Mixer pin.", usbRecFolderHint: nil, needsMixerForMaster: false, matchHints: ["rane seventy", "seventy"]),
        HardwareProfile(id: "seventy-two", displayName: "Seventy-Two", vendor: .rane, hardwareClass: .mixer, captureHint: "Serato is the primary path. USB program pair Manual Setup until live-mapped. Session Out uses Analog Mixer pin.", usbRecFolderHint: nil, needsMixerForMaster: false, matchHints: ["seventy-two", "seventy two", "rane seventy-two"]),
        HardwareProfile(id: "analog-rec-out", displayName: "Analog Mixer Rec Out", vendor: .genericMixer, hardwareClass: .mixer, captureHint: "Pin this Mac's interface that carries mixer REC OUT / SESSION OUT. Never auto-selected — the pin is the trust grant.", usbRecFolderHint: nil, needsMixerForMaster: false, matchHints: [])
    ]

    public static func profile(id: String) -> HardwareProfile? {
        all.first { $0.id == id }
    }

    public static func profiles(vendor: HardwareVendor) -> [HardwareProfile] {
        all.filter { $0.vendor == vendor }
    }

    /// Match a Core Audio input to a known profile. Longer names / hints win so
    /// `CDJ-2000NXS` does not collapse to `CDJ-2000`.
    public static func profile(matching device: AudioInputDevice) -> HardwareProfile? {
        let haystack = "\(device.name) \(device.manufacturer)".lowercased()
        return all
            .sorted { lhs, rhs in
                let lhsScore = max(lhs.displayName.count, lhs.matchHints.map(\.count).max() ?? 0)
                let rhsScore = max(rhs.displayName.count, rhs.matchHints.map(\.count).max() ?? 0)
                return lhsScore > rhsScore
            }
            .first { profile in
                if haystack.contains(profile.displayName.lowercased()) {
                    return true
                }
                return profile.matchHints.contains { haystack.contains($0) }
            }
    }

    /// Trusted DJ hardware feed for DualRoute / auto-select. Pioneer legacy substrings remain;
    /// Denon / Rane only when a catalog profile matches. Unknown USB (Focusrite, etc.) never matches.
    public static func isTrustedHardwareFeed(_ device: AudioInputDevice) -> Bool {
        if let matched = profile(matching: device) {
            // Generic analog pin is never auto-trusted — user must Choose rec-out.
            return matched.vendor != .genericMixer
        }
        let haystack = "\(device.name) \(device.manufacturer)".lowercased()
        return ["djm", "xdj", "cdj", "pioneer", "alphatheta"].contains { haystack.contains($0) }
    }
}

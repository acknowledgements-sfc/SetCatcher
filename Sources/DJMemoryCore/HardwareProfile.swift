import Foundation

public enum HardwareClass: String, Codable, Sendable {
    case mixer
    case allInOne
    case player
}

public struct HardwareProfile: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let hardwareClass: HardwareClass
    public let captureHint: String
    public let usbRecFolderHint: String?
    public let needsMixerForMaster: Bool

    public init(id: String, displayName: String, hardwareClass: HardwareClass, captureHint: String, usbRecFolderHint: String?, needsMixerForMaster: Bool) {
        self.id = id
        self.displayName = displayName
        self.hardwareClass = hardwareClass
        self.captureHint = captureHint
        self.usbRecFolderHint = usbRecFolderHint
        self.needsMixerForMaster = needsMixerForMaster
    }

    /// True when this unit can expose a USB master / REC OUT feed to the Mac.
    /// Players never can; USB presence of a CDJ is not a capturable mix.
    public var canProvideUSBMasterFeed: Bool {
        !needsMixerForMaster && (hardwareClass == .mixer || hardwareClass == .allInOne)
    }

    /// One-line caption for the Pioneer Hardware adapter list.
    /// XDJ-XZ is laptop + USB Input Capture; MASTER REC is the fallback, not the verified path.
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
            return "USB MASTER REC"
        }
    }
}

public enum SupportedHardware {
    public static let pioneerUSBRecFolderName = "PIONEERREC"

    public static let all: [HardwareProfile] = [
        HardwareProfile(id: "xdj-rx2", displayName: "XDJ-RX2", hardwareClass: .allInOne, captureHint: "Prefer MASTER REC to USB (PIONEERREC). Use Capture when this unit or a DJM appears as a Core Audio input.", usbRecFolderHint: pioneerUSBRecFolderName, needsMixerForMaster: false),
        HardwareProfile(id: "xdj-rx3", displayName: "XDJ-RX3", hardwareClass: .allInOne, captureHint: "MASTER REC writes WAV files to PIONEERREC on USB port 2.", usbRecFolderHint: pioneerUSBRecFolderName, needsMixerForMaster: false),
        HardwareProfile(id: "xdj-xz", displayName: "XDJ-XZ", hardwareClass: .allInOne, captureHint: "Laptop + USB: Folder Protection copies Serato or rekordbox recordings; Input Capture records the XZ USB output if Record was forgotten. USB MASTER REC (PIONEERREC) is a Manual Setup fallback when the Mac is out of the audio path.", usbRecFolderHint: pioneerUSBRecFolderName, needsMixerForMaster: false),
        HardwareProfile(id: "xdj-az", displayName: "XDJ-AZ", hardwareClass: .allInOne, captureHint: "Archive MASTER REC from PIONEERREC, or Capture via DJM USB input.", usbRecFolderHint: pioneerUSBRecFolderName, needsMixerForMaster: false),
        HardwareProfile(id: "xdj-1000", displayName: "XDJ-1000", hardwareClass: .player, captureHint: "A player, not an all-in-one: it outputs its own deck audio, not the mixer's master. Capture the DJM/mixer feed for the full set.", usbRecFolderHint: nil, needsMixerForMaster: true),
        HardwareProfile(id: "cdj-2000", displayName: "CDJ-2000", hardwareClass: .player, captureHint: "CDJs do not record the master mix. SetCatcher can protect only what reaches the Mac. Route USB through this laptop or a DJM, or grant a PIONEERREC folder. A mixer that never reaches the Mac is Manual Setup.", usbRecFolderHint: nil, needsMixerForMaster: true),
        HardwareProfile(id: "cdj-2000nxs", displayName: "CDJ-2000NXS", hardwareClass: .player, captureHint: "CDJs do not record the master mix. SetCatcher can protect only what reaches the Mac. Route USB through this laptop or a DJM, or grant a PIONEERREC folder. A mixer that never reaches the Mac is Manual Setup.", usbRecFolderHint: nil, needsMixerForMaster: true),
        HardwareProfile(id: "cdj-3000", displayName: "CDJ-3000", hardwareClass: .player, captureHint: "CDJs do not record the master mix. SetCatcher can protect only what reaches the Mac. Route USB through this laptop or a DJM, or grant a PIONEERREC folder. A mixer that never reaches the Mac is Manual Setup.", usbRecFolderHint: nil, needsMixerForMaster: true),
        HardwareProfile(id: "djm-900", displayName: "DJM-900", hardwareClass: .mixer, captureHint: "Install Pioneer DJM USB driver. Assign MIX (REC OUT), then select the DJM in Capture.", usbRecFolderHint: nil, needsMixerForMaster: false),
        HardwareProfile(id: "djm-v10", displayName: "DJM-V10", hardwareClass: .mixer, captureHint: "Install Pioneer DJM-V10 USB driver. Assign MIX (REC OUT), then select in Capture.", usbRecFolderHint: nil, needsMixerForMaster: false),
        HardwareProfile(id: "djm-v10lf", displayName: "DJM-V10LF", hardwareClass: .mixer, captureHint: "Install Pioneer DJM-V10LF USB driver. Assign MIX (REC OUT), then select in Capture.", usbRecFolderHint: nil, needsMixerForMaster: false)
    ]

    public static func profile(id: String) -> HardwareProfile? {
        all.first { $0.id == id }
    }

    /// Match a Core Audio input to a known profile. Longer names win so
    /// `CDJ-2000NXS` does not collapse to `CDJ-2000`.
    public static func profile(matching device: AudioInputDevice) -> HardwareProfile? {
        let haystack = "\(device.name) \(device.manufacturer)".lowercased()
        return all
            .sorted { $0.displayName.count > $1.displayName.count }
            .first { profile in
                haystack.contains(profile.displayName.lowercased())
            }
    }
}

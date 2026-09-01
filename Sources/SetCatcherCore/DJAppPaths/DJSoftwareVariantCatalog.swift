import Foundation

public enum DJSoftwareVariantCatalog {
    /// Traktor installations older than this floor are excluded from variant detection.
    public static let traktorMinimumVersionComponents = [3, 8, 0]

    public static func variantLabel(
        familyID: String,
        bundleIdentifier: String,
        shortVersion: String?
    ) -> String {
        switch familyID {
        case "serato":
            return seratoLabel(bundleIdentifier: bundleIdentifier, shortVersion: shortVersion)
        case "rekordbox":
            return rekordboxLabel(shortVersion: shortVersion)
        case "djay":
            return djayLabel(bundleIdentifier: bundleIdentifier)
        case "traktor":
            return traktorLabel(bundleIdentifier: bundleIdentifier, shortVersion: shortVersion)
        case "virtualdj":
            return virtualDJLabel(shortVersion: shortVersion)
        case "denon-engine":
            return denonEngineLabel(shortVersion: shortVersion)
        default:
            if let software = SupportedDJSoftware.all.first(where: { $0.id == familyID }) {
                return software.displayName
            }
            return familyID
        }
    }

    public static func isSupportedTraktorInstallation(bundleIdentifier: String, shortVersion: String?) -> Bool {
        guard bundleIdentifier == "com.native-instruments.Traktor"
            || bundleIdentifier == "com.native-instruments.tmnt"
        else {
            return false
        }

        guard let shortVersion, let components = parseVersionComponents(shortVersion) else {
            return bundleIdentifier == "com.native-instruments.tmnt"
        }

        return compareVersion(components, traktorMinimumVersionComponents) >= 0
    }

    private static func seratoLabel(bundleIdentifier: String, shortVersion: String?) -> String {
        let edition = bundleIdentifier == "com.serato.dj" ? "Lite" : "Pro"
        let major = majorVersion(from: shortVersion) ?? "?"
        return "Serato DJ \(edition) \(major)"
    }

    private static func rekordboxLabel(shortVersion: String?) -> String {
        let major = majorVersion(from: shortVersion) ?? "?"
        return "rekordbox \(major)"
    }

    private static func djayLabel(bundleIdentifier: String) -> String {
        switch bundleIdentifier {
        case "com.algoriddim.direct.djay-pro-2-mac":
            return "djay Pro 2"
        case "com.algoriddim.djay-pro-mac":
            return "djay Pro"
        case "com.algoriddim.djay-iphone-free-mac":
            return "djay 2"
        case "com.algoriddim.djay-iphone-free":
            return "djay"
        default:
            return "djay"
        }
    }

    private static func traktorLabel(bundleIdentifier: String, shortVersion: String?) -> String {
        let product = bundleIdentifier == "com.native-instruments.tmnt" ? "Traktor DJ 2" : "Traktor Pro"
        if let shortVersion, !shortVersion.isEmpty {
            return "\(product) \(shortVersion)"
        }
        return product
    }

    private static func virtualDJLabel(shortVersion: String?) -> String {
        let major = majorVersion(from: shortVersion) ?? "?"
        return "VirtualDJ \(major)"
    }

    private static func denonEngineLabel(shortVersion: String?) -> String {
        if let shortVersion, !shortVersion.isEmpty {
            return "Engine DJ \(shortVersion)"
        }
        return "Engine DJ"
    }

    private static func majorVersion(from shortVersion: String?) -> String? {
        guard let shortVersion else { return nil }
        let head = shortVersion.split(whereSeparator: { $0 == "." || $0 == " " || $0 == "(" }).first
        return head.map(String.init)
    }

    private static func parseVersionComponents(_ value: String) -> [Int]? {
        let digits = value.split(whereSeparator: { !$0.isNumber })
        let components = digits.prefix(3).compactMap { Int($0) }
        guard !components.isEmpty else { return nil }
        return components
    }

    private static func compareVersion(_ lhs: [Int], _ rhs: [Int]) -> Int {
        let count = max(lhs.count, rhs.count)
        for index in 0..<count {
            let left = index < lhs.count ? lhs[index] : 0
            let right = index < rhs.count ? rhs[index] : 0
            if left != right {
                return left < right ? -1 : 1
            }
        }
        return 0
    }
}

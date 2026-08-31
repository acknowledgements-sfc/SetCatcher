import Foundation

public struct MatchedDJApp: Equatable, Identifiable, Sendable {
    public let software: DJSoftware
    public let matchedBundleIdentifier: String

    public var id: String { software.id }

    public init(software: DJSoftware, matchedBundleIdentifier: String) {
        self.software = software
        self.matchedBundleIdentifier = matchedBundleIdentifier
    }
}

public enum DJAppProcessMatcher {
    /// Desktop DJ engines eligible for app-audio capture (excludes Capture / Pioneer Hardware stubs).
    public static var capturableSoftware: [DJSoftware] {
        SupportedDJSoftware.all.filter { software in
            software.id != SupportedDJSoftware.captureAppID
                && !SupportedDJSoftware.hardwareAdapterAppIDs.contains(software.id)
                && !software.bundleIdentifiers.isEmpty
        }
    }

    public static func match(bundleIdentifier: String) -> DJSoftware? {
        capturableSoftware.first { $0.bundleIdentifiers.contains(bundleIdentifier) }
    }

    public static func matchRunning(bundleIdentifiers: [String]) -> [MatchedDJApp] {
        var seenSoftwareIDs = Set<String>()
        var matches: [MatchedDJApp] = []
        for bundleID in bundleIdentifiers {
            guard let software = match(bundleIdentifier: bundleID) else { continue }
            guard seenSoftwareIDs.insert(software.id).inserted else { continue }
            matches.append(MatchedDJApp(software: software, matchedBundleIdentifier: bundleID))
        }
        return matches.sorted { $0.software.displayName.localizedCaseInsensitiveCompare($1.software.displayName) == .orderedAscending }
    }

    public static func firstMatch(bundleIdentifiers: [String]) -> MatchedDJApp? {
        matchRunning(bundleIdentifiers: bundleIdentifiers).first
    }
}

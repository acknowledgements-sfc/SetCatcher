import Foundation

public enum DJPathKind: String, Codable, Sendable, CaseIterable {
    case recordings
    case tempRecordings
    case history
    case library
    case sessions
    case pluginDrop

    public var displayName: String {
        switch self {
        case .recordings:
            return "Recordings"
        case .tempRecordings:
            return "Temp recordings"
        case .history:
            return "History"
        case .library:
            return "Library"
        case .sessions:
            return "Sessions"
        case .pluginDrop:
            return "Plugin drop"
        }
    }
}

public enum DJPathSource: String, Codable, Sendable {
    case userPreference
    case catalogDefault
    case filesystemProbe
}

public struct DiscoveredDJPath: Codable, Equatable, Sendable {
    public let kind: DJPathKind
    public let url: URL
    public let source: DJPathSource
    public let note: String?

    public init(kind: DJPathKind, url: URL, source: DJPathSource, note: String? = nil) {
        self.kind = kind
        self.url = url
        self.source = source
        self.note = note
    }
}

public struct DJSoftwareInstallation: Codable, Equatable, Sendable, Identifiable {
    public let familyID: String
    public let variantLabel: String
    public let bundleIdentifier: String
    public let bundleVersion: String?
    public let appURL: URL
    public let isRunning: Bool
    public let discoveredPaths: [DiscoveredDJPath]

    public var id: String { "\(familyID)|\(bundleIdentifier)|\(appURL.path)" }

    public init(
        familyID: String,
        variantLabel: String,
        bundleIdentifier: String,
        bundleVersion: String?,
        appURL: URL,
        isRunning: Bool,
        discoveredPaths: [DiscoveredDJPath]
    ) {
        self.familyID = familyID
        self.variantLabel = variantLabel
        self.bundleIdentifier = bundleIdentifier
        self.bundleVersion = bundleVersion
        self.appURL = appURL
        self.isRunning = isRunning
        self.discoveredPaths = discoveredPaths
    }

    public func paths(ofKind kind: DJPathKind) -> [URL] {
        discoveredPaths.filter { $0.kind == kind }.map(\.url)
    }

    public func bestPath(ofKind kind: DJPathKind) -> DiscoveredDJPath? {
        discoveredPaths
            .filter { $0.kind == kind }
            .sorted { lhs, rhs in
                sourceRank(lhs.source) < sourceRank(rhs.source)
            }
            .first
    }

    private func sourceRank(_ source: DJPathSource) -> Int {
        switch source {
        case .userPreference:
            return 0
        case .catalogDefault:
            return 1
        case .filesystemProbe:
            return 2
        }
    }
}

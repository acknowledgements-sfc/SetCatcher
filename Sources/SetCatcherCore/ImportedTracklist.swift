import Foundation

public enum ImportedTracklistKind: String, Codable, Equatable, Sendable {
    case setHistory
    case collection

    public var isMatchableToRecording: Bool {
        self == .setHistory
    }
}

public struct ImportedTracklist: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let appID: String
    public let sourceURL: URL
    public let kind: ImportedTracklistKind
    public let tracks: [TrackPlay]
    public let importedAt: Date

    public init(
        id: UUID = UUID(),
        appID: String,
        sourceURL: URL,
        kind: ImportedTracklistKind = .setHistory,
        tracks: [TrackPlay],
        importedAt: Date = Date()
    ) {
        self.id = id
        self.appID = appID
        self.sourceURL = sourceURL
        self.kind = kind
        self.tracks = tracks
        self.importedAt = importedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case appID
        case sourceURL
        case kind
        case tracks
        case importedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        appID = try container.decode(String.self, forKey: .appID)
        sourceURL = try container.decode(URL.self, forKey: .sourceURL)
        kind = try container.decodeIfPresent(ImportedTracklistKind.self, forKey: .kind)
            ?? Self.defaultKind(appID: appID, sourceURL: sourceURL)
        tracks = try container.decode([TrackPlay].self, forKey: .tracks)
        importedAt = try container.decode(Date.self, forKey: .importedAt)
    }

    private static func defaultKind(appID: String, sourceURL: URL) -> ImportedTracklistKind {
        if appID == "rekordbox", sourceURL.pathExtension.localizedCaseInsensitiveCompare("xml") == .orderedSame {
            return .collection
        }

        return .setHistory
    }
}

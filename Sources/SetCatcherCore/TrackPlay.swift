import Foundation

public struct TrackPlay: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let title: String
    public let artist: String
    public let startTime: String?
    public let source: String
    public let confidence: Double
    /// Calendar day of the matched set (archive `detectedAt`), when known.
    public let playedOn: Date?

    public init(
        id: UUID = UUID(),
        title: String,
        artist: String,
        startTime: String?,
        source: String,
        confidence: Double,
        playedOn: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.startTime = startTime
        self.source = source
        self.confidence = confidence
        self.playedOn = playedOn
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, artist, startTime, source, confidence, playedOn
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        artist = try container.decode(String.self, forKey: .artist)
        startTime = try container.decodeIfPresent(String.self, forKey: .startTime)
        source = try container.decode(String.self, forKey: .source)
        confidence = try container.decode(Double.self, forKey: .confidence)
        playedOn = try container.decodeIfPresent(Date.self, forKey: .playedOn)
    }

    public func stampingPlayedOn(_ date: Date?) -> TrackPlay {
        TrackPlay(
            id: id,
            title: title,
            artist: artist,
            startTime: startTime,
            source: source,
            confidence: confidence,
            playedOn: date
        )
    }
}

extension ImportedTracklist {
    public func stampingPlayedOn(_ date: Date?) -> ImportedTracklist {
        ImportedTracklist(
            id: id,
            appID: appID,
            sourceURL: sourceURL,
            kind: kind,
            tracks: tracks.map { $0.stampingPlayedOn(date) },
            importedAt: importedAt
        )
    }
}

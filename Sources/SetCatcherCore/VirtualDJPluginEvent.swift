import Foundation

/// Event contract emitted by the VirtualDJ native `.bundle` plugin (M14,
/// Artifact A). The plugin appends newline-delimited JSON (JSONL) into a local
/// drop folder; SetCatcher (Artifact B) watches that folder and imports each file
/// as an `ImportedTracklist`. The frozen `v:1` schema is specified in
/// `docs/m14-vdj-plugin-spec.md` §5 — keep this model in sync with that doc.
///
/// One JSON object per line. Unknown fields are ignored so the schema can grow
/// without breaking older app builds.
public struct VirtualDJPluginEvent: Decodable, Equatable, Sendable {
    public enum EventType: String, Decodable, Sendable {
        case sessionStart = "session_start"
        case trackLoad = "track_load"
        case trackPlay = "track_play"
        case sessionEnd = "session_end"
    }

    public let version: Int
    public let type: EventType
    public let timestamp: String?
    public let session: String?
    public let app: String?
    public let deck: Int?
    public let artist: String?
    public let title: String?
    public let elapsed: Double?

    private enum CodingKeys: String, CodingKey {
        case version = "v"
        case type
        case timestamp = "ts"
        case session
        case app
        case deck
        case artist
        case title
        case elapsed
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        type = try container.decode(EventType.self, forKey: .type)
        timestamp = try container.decodeIfPresent(String.self, forKey: .timestamp)
        session = try container.decodeIfPresent(String.self, forKey: .session)
        app = try container.decodeIfPresent(String.self, forKey: .app)
        deck = try container.decodeIfPresent(Int.self, forKey: .deck)
        artist = try container.decodeIfPresent(String.self, forKey: .artist)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        elapsed = try container.decodeIfPresent(Double.self, forKey: .elapsed)
    }
}

/// Parses the plugin drop-folder JSONL into `TrackPlay` rows per the M14 spec
/// (`docs/m14-vdj-plugin-spec.md` §7). Native `track_play` events are trusted
/// deck-engine metadata, so imported tracks carry high confidence.
public struct JSONLTracklistParser: TracklistParser {
    /// Highest schema major version this reader understands. A line declaring a
    /// higher `v` means the file was written by a newer plugin; reject rather
    /// than silently import a partial/misread set (spec §5, §7).
    public static let supportedVersion = 1

    /// `track_play` events come straight from the deck engine, not fuzzy text.
    public static let confidence: Double = 0.95

    /// Source tag stamped onto every imported `TrackPlay` (spec §7).
    public static let source = "virtualdj-plugin"

    public init() {}

    public func parse(data: Data, sourceName: String = JSONLTracklistParser.source) throws -> [TrackPlay] {
        guard let text = String(data: data, encoding: .utf8) else {
            throw TracklistParserError.unreadableText
        }

        let decoder = JSONDecoder()
        var tracks: [TrackPlay] = []
        // (deck, artist, title) of the last emitted play, to collapse re-cue
        // repeats of the same track on the same deck (spec §4 de-dup rule).
        var lastEmittedKey: String?

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, let lineData = line.data(using: .utf8) else { continue }

            // A truncated final line (crash during flush) or stray non-JSON is
            // tolerated — skip it rather than failing the whole import (spec §5).
            guard let event = try? decoder.decode(VirtualDJPluginEvent.self, from: lineData) else { continue }

            // A well-formed line from a newer schema major version means we may
            // misread this file; reject it outright (spec §5, §7).
            if event.version > Self.supportedVersion {
                throw TracklistParserError.unsupportedVersion(event.version)
            }

            guard event.type == .trackPlay else { continue }

            let title = (event.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let artist = (event.artist ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty || !artist.isEmpty else { continue }

            let key = "\(event.deck.map(String.init) ?? "-")\u{1}\(artist)\u{1}\(title)"
            if key == lastEmittedKey { continue }
            lastEmittedKey = key

            tracks.append(
                TrackPlay(
                    title: StringDecoding.decodedEntities(title),
                    artist: StringDecoding.decodedEntities(artist),
                    startTime: event.timestamp,
                    source: Self.source,
                    confidence: Self.confidence
                )
            )
        }

        return tracks
    }
}

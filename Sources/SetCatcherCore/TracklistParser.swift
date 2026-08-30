import Foundation

public enum TracklistParserError: Error, Equatable {
    case unreadableText
    /// A JSONL drop file declared a schema major version newer than this build
    /// understands (M14 plugin contract).
    case unsupportedVersion(Int)
}

public protocol TracklistParser {
    func parse(data: Data, sourceName: String) throws -> [TrackPlay]
}

public struct DelimitedTracklistParser: TracklistParser {
    public init() {}

    public func parse(data: Data, sourceName: String) throws -> [TrackPlay] {
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .macOSRoman) else {
            throw TracklistParserError.unreadableText
        }

        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let firstLine = lines.first else {
            return []
        }

        let delimiter = detectDelimiter(in: firstLine)
        let rows = lines.map { parseLine($0, delimiter: delimiter) }
        let header = normalizedHeader(from: rows.first ?? [])
        let dataRows = header.isEmpty ? rows : Array(rows.dropFirst())

        return dataRows.compactMap { row in
            trackPlay(from: row, header: header, sourceName: sourceName)
        }
    }

    private func detectDelimiter(in line: String) -> Character {
        let candidates: [Character] = [",", "\t", ";"]
        return candidates.max { lhs, rhs in
            line.filter { $0 == lhs }.count < line.filter { $0 == rhs }.count
        } ?? ","
    }

    private func normalizedHeader(from row: [String]) -> [String: Int] {
        let normalized = row.map { $0.lowercased().replacingOccurrences(of: " ", with: "") }
        let knownHeaderTerms = ["artist", "title", "track", "song", "start", "time", "playedat", "name"]

        guard normalized.contains(where: { value in knownHeaderTerms.contains { value.contains($0) } }) else {
            return [:]
        }

        return Dictionary(uniqueKeysWithValues: normalized.enumerated().map { ($0.element, $0.offset) })
    }

    private func trackPlay(from row: [String], header: [String: Int], sourceName: String) -> TrackPlay? {
        let artist = value(from: row, header: header, keys: ["artist", "artists"]) ?? (header.isEmpty ? fallback(row: row, index: 0) : nil)
        let title = value(from: row, header: header, keys: ["title", "track", "song", "name"]) ?? fallback(row: row, index: header.isEmpty ? 1 : 0)
        let startTime = value(from: row, header: header, keys: ["starttime", "time", "playedat"]) ?? inferredStartTime(from: row)

        guard let title, !title.isEmpty else {
            return nil
        }

        return TrackPlay(
            title: StringDecoding.decodedEntities(title),
            artist: StringDecoding.decodedEntities(artist ?? ""),
            startTime: startTime,
            source: sourceName,
            confidence: header.isEmpty ? 0.55 : 0.85
        )
    }

    private func value(from row: [String], header: [String: Int], keys: [String]) -> String? {
        for key in keys {
            if let match = header.first(where: { $0.key.contains(key) }), row.indices.contains(match.value) {
                let value = row[match.value].trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty { return value }
            }
        }

        return nil
    }

    private func fallback(row: [String], index: Int) -> String? {
        guard row.indices.contains(index) else { return nil }
        let value = row[index].trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func inferredStartTime(from row: [String]) -> String? {
        row.first { value in
            value.range(of: #"^\d{1,2}:\d{2}(:\d{2})?$"#, options: .regularExpression) != nil
        }
    }

    private func parseLine(_ line: String, delimiter: Character) -> [String] {
        var values: [String] = []
        var current = ""
        var isQuoted = false

        for character in line {
            if character == "\"" {
                isQuoted.toggle()
            } else if character == delimiter && !isQuoted {
                values.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                current = ""
            } else {
                current.append(character)
            }
        }

        values.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
        return values
    }
}

public struct SeratoHistoryParser: TracklistParser {
    private let parser: DelimitedTracklistParser

    public init(parser: DelimitedTracklistParser = DelimitedTracklistParser()) {
        self.parser = parser
    }

    public func parse(data: Data, sourceName: String = "Serato History") throws -> [TrackPlay] {
        try parser.parse(data: data, sourceName: sourceName).filter { track in
            !isSessionSummaryRow(track)
        }
    }

    private func isSessionSummaryRow(_ track: TrackPlay) -> Bool {
        guard track.artist.isEmpty else { return false }

        let dateLikeTitle = track.title.range(
            of: #"^\d{1,2}/\d{1,2}/\d{2,4}$"#,
            options: .regularExpression
        ) != nil

        let dateLikeStart = track.startTime?.contains(",") == true

        return dateLikeTitle && dateLikeStart
    }
}

public final class RekordboxXMLParser: NSObject, TracklistParser, XMLParserDelegate {
    private var tracks: [TrackPlay] = []
    private var sourceName = "rekordbox XML"

    public override init() {}

    public func parse(data: Data, sourceName: String = "rekordbox XML") throws -> [TrackPlay] {
        self.tracks = []
        self.sourceName = sourceName

        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()

        return tracks
    }

    public func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        guard elementName.uppercased() == "TRACK" else { return }

        let title = attributeDict["Name"] ?? attributeDict["TrackName"] ?? attributeDict["Title"]
        let artist = attributeDict["Artist"] ?? attributeDict["ArtistName"] ?? ""

        guard let title, !title.isEmpty else { return }

        tracks.append(
            TrackPlay(
                title: StringDecoding.decodedEntities(title),
                artist: StringDecoding.decodedEntities(artist),
                startTime: nil,
                source: sourceName,
                confidence: 0.8
            )
        )
    }
}

public final class TraktorNMLParser: NSObject, TracklistParser, XMLParserDelegate {
    private var tracks: [TrackPlay] = []
    private var sourceName = "Traktor NML"

    public override init() {}

    public func parse(data: Data, sourceName: String = "Traktor NML") throws -> [TrackPlay] {
        self.tracks = []
        self.sourceName = sourceName

        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()

        return tracks
    }

    public func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        guard elementName.uppercased() == "ENTRY" else { return }

        let title = value(from: attributeDict, keys: ["TITLE", "Title", "Name", "NAME"])
        let artist = value(from: attributeDict, keys: ["ARTIST", "Artist"]) ?? ""
        let startTime = value(from: attributeDict, keys: ["STARTTIME", "START_TIME", "PLAYTIME", "TIME"])

        guard let title, !title.isEmpty else { return }

        tracks.append(
            TrackPlay(
                title: StringDecoding.decodedEntities(title),
                artist: StringDecoding.decodedEntities(artist),
                startTime: startTime,
                source: sourceName,
                confidence: 0.75
            )
        )
    }

    private func value(from attributes: [String: String], keys: [String]) -> String? {
        for key in keys {
            if let value = attributes[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
                return value
            }
        }

        return nil
    }
}

public struct VirtualDJHistoryParser: TracklistParser {
    private let delimitedParser: DelimitedTracklistParser
    private let databaseParser: VirtualDJDatabaseParser
    private let pluginEventParser: JSONLTracklistParser

    public init(
        delimitedParser: DelimitedTracklistParser = DelimitedTracklistParser(),
        databaseParser: VirtualDJDatabaseParser = VirtualDJDatabaseParser(),
        pluginEventParser: JSONLTracklistParser = JSONLTracklistParser()
    ) {
        self.delimitedParser = delimitedParser
        self.databaseParser = databaseParser
        self.pluginEventParser = pluginEventParser
    }

    public func parse(data: Data, sourceName: String = "VirtualDJ History") throws -> [TrackPlay] {
        let extensionName = (sourceName as NSString).pathExtension.lowercased()

        // Native plugin drop-folder events (M14, spec §7).
        if extensionName == "jsonl" {
            return try pluginEventParser.parse(data: data, sourceName: sourceName)
        }

        if ["xml", "vdjfolder"].contains(extensionName) {
            let databaseTracks = try databaseParser.parse(data: data, sourceName: sourceName)
            if !databaseTracks.isEmpty {
                return databaseTracks
            }
        }

        if shouldParseAsM3U(data: data, sourceName: sourceName),
           let m3uTracks = try? parseM3U(data: data, sourceName: sourceName),
           !m3uTracks.isEmpty {
            return m3uTracks
        }

        return try delimitedParser.parse(data: data, sourceName: sourceName)
    }

    private func shouldParseAsM3U(data: Data, sourceName: String) -> Bool {
        let extensionName = (sourceName as NSString).pathExtension.lowercased()
        if ["m3u", "m3u8"].contains(extensionName) {
            return true
        }

        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .macOSRoman) else {
            return false
        }

        return text
            .components(separatedBy: .newlines)
            .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .localizedCaseInsensitiveCompare("#EXTM3U") == .orderedSame
    }

    private func parseM3U(data: Data, sourceName: String) throws -> [TrackPlay] {
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .macOSRoman) else {
            throw TracklistParserError.unreadableText
        }

        var pendingTitle: String?
        var pendingArtist: String?
        var tracks: [TrackPlay] = []

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            if line.hasPrefix("#EXTINF:") {
                let info = line.components(separatedBy: ",").dropFirst().joined(separator: ",")
                let parts = info.components(separatedBy: " - ")
                if parts.count >= 2 {
                    pendingArtist = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines)
                    pendingTitle = parts.dropFirst().joined(separator: " - ").trimmingCharacters(in: .whitespacesAndNewlines)
                } else {
                    pendingTitle = info.trimmingCharacters(in: .whitespacesAndNewlines)
                    pendingArtist = ""
                }
            } else if !line.hasPrefix("#") {
                let fallbackTitle = URL(fileURLWithPath: line).deletingPathExtension().lastPathComponent
                let title = pendingTitle?.isEmpty == false ? pendingTitle ?? fallbackTitle : fallbackTitle
                tracks.append(
                    TrackPlay(
                        title: StringDecoding.decodedEntities(title),
                        artist: StringDecoding.decodedEntities(pendingArtist ?? ""),
                        startTime: nil,
                        source: sourceName,
                        confidence: pendingTitle == nil ? 0.55 : 0.8
                    )
                )
                pendingTitle = nil
                pendingArtist = nil
            }
        }

        return tracks
    }
}

public final class VirtualDJDatabaseParser: NSObject, TracklistParser, XMLParserDelegate {
    private var tracks: [TrackPlay] = []
    private var sourceName = "VirtualDJ Database"

    public override init() {}

    public func parse(data: Data, sourceName: String = "VirtualDJ Database") throws -> [TrackPlay] {
        self.tracks = []
        self.sourceName = sourceName

        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()

        return tracks
    }

    public func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        guard ["SONG", "TRACK"].contains(elementName.uppercased()) else { return }

        let title = value(from: attributeDict, keys: ["Title", "TITLE", "Name", "NAME"])
            ?? titleFromFilePath(value(from: attributeDict, keys: ["FilePath", "FILEPATH", "Path", "PATH"]))
        let artist = value(from: attributeDict, keys: ["Author", "AUTHOR", "Artist", "ARTIST"]) ?? ""
        let startTime = value(from: attributeDict, keys: ["StartTime", "STARTTIME", "Time", "TIME"])

        guard let title, !title.isEmpty else { return }

        tracks.append(
            TrackPlay(
                title: StringDecoding.decodedEntities(title),
                artist: StringDecoding.decodedEntities(artist),
                startTime: startTime,
                source: sourceName,
                confidence: 0.75
            )
        )
    }

    private func value(from attributes: [String: String], keys: [String]) -> String? {
        for key in keys {
            if let value = attributes[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
                return value
            }
        }

        return nil
    }

    private func titleFromFilePath(_ filePath: String?) -> String? {
        guard let filePath, !filePath.isEmpty else { return nil }
        return URL(fileURLWithPath: filePath).deletingPathExtension().lastPathComponent
    }
}

import Foundation

private func normalizedTrackComponent(_ value: String) -> String {
    value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
}

public struct TrackPlayCount: Equatable, Identifiable, Sendable {
    public let title: String
    public let artist: String
    public let playCount: Int
    public let lastEventName: String

    /// Stable identity for an aggregated track across refreshes and ranking changes.
    /// Artist and title are the aggregation key used by `topTracks`.
    public var id: String {
        "\(normalizedTrackComponent(artist))\u{1F}\(normalizedTrackComponent(title))"
    }

    public init(title: String, artist: String, playCount: Int, lastEventName: String) {
        self.title = title
        self.artist = artist
        self.playCount = playCount
        self.lastEventName = lastEventName
    }
}

public struct VenueCount: Equatable, Sendable {
    public let name: String
    public let city: String
    public let setCount: Int

    public init(name: String, city: String, setCount: Int) {
        self.name = name
        self.city = city
        self.setCount = setCount
    }
}

public struct TagCount: Equatable, Sendable {
    public let display: String
    public let count: Int

    public init(display: String, count: Int) {
        self.display = display
        self.count = count
    }
}

public enum CrossSetAggregation {
    public static func topTracks(
        from tracklists: [ImportedTracklist],
        eventNameForTracklistID: [UUID: String] = [:],
        limit: Int = 8
    ) -> [TrackPlayCount] {
        struct Acc {
            var title: String
            var artist: String
            var count: Int
            var lastEventName: String
        }

        var map: [String: Acc] = [:]
        for list in tracklists where list.kind == .setHistory {
            let event = eventNameForTracklistID[list.id] ?? ""
            for track in list.tracks {
                let key = "\(normalizedTrackComponent(track.artist))|\(normalizedTrackComponent(track.title))"
                if var existing = map[key] {
                    existing.count += 1
                    if !event.isEmpty {
                        existing.lastEventName = event
                    }
                    map[key] = existing
                } else {
                    map[key] = Acc(title: track.title, artist: track.artist, count: 1, lastEventName: event)
                }
            }
        }

        return map.values
            .map { TrackPlayCount(title: $0.title, artist: $0.artist, playCount: $0.count, lastEventName: $0.lastEventName) }
            .sorted {
                if $0.playCount != $1.playCount { return $0.playCount > $1.playCount }
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
            .prefix(limit)
            .map { $0 }
    }

    public static func venues(from contexts: [SetContext], limit: Int = 6) -> [VenueCount] {
        struct Acc {
            var name: String
            var city: String
            var count: Int
        }
        var map: [String: Acc] = [:]
        for context in contexts {
            let name = context.venue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            let city = context.city.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = "\(name.lowercased())|\(city.lowercased())"
            if var existing = map[key] {
                existing.count += 1
                map[key] = existing
            } else {
                map[key] = Acc(name: name, city: city, count: 1)
            }
        }
        return map.values
            .map { VenueCount(name: $0.name, city: $0.city, setCount: $0.count) }
            .sorted {
                if $0.setCount != $1.setCount { return $0.setCount > $1.setCount }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            .prefix(limit)
            .map { $0 }
    }

    public static func tags(from contexts: [SetContext]) -> [TagCount] {
        struct Acc {
            var display: String
            var count: Int
        }
        var map: [String: Acc] = [:]
        for context in contexts {
            let parts = context.tags.split(separator: ",", omittingEmptySubsequences: false)
            for part in parts {
                let display = part.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !display.isEmpty else { continue }
                let key = display.lowercased()
                if var existing = map[key] {
                    existing.count += 1
                    map[key] = existing
                } else {
                    map[key] = Acc(display: display, count: 1)
                }
            }
        }
        return map.values
            .map { TagCount(display: $0.display, count: $0.count) }
            .sorted {
                if $0.count != $1.count { return $0.count > $1.count }
                return $0.display.localizedCaseInsensitiveCompare($1.display) == .orderedAscending
            }
    }
}

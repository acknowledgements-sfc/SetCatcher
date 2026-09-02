import Foundation

public enum LibrarySessionSort: String, CaseIterable, Equatable, Hashable, Sendable {
    case newestFirst
    case nameAscending
}

public enum LibrarySourceFilter: Equatable, Hashable, Sendable {
    case all
    case app(String)
    case pioneerHardware
}

public struct LibrarySessionSearch {
    public init() {}

    public func filter(
        _ summaries: [LibrarySessionSummary],
        query: String,
        dateFilter: LibraryDateFilter = .all,
        sourceFilter: LibrarySourceFilter = .all,
        sort: LibrarySessionSort = .newestFirst,
        appDisplayName: (String) -> String,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> [LibrarySessionSummary] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = summaries.filter { summary in
            guard dateFilter.contains(summary.archive.detectedAt, calendar: calendar, now: now) else {
                return false
            }
            guard sourceFilterMatches(summary, filter: sourceFilter) else { return false }
            guard !normalizedQuery.isEmpty else { return true }
            return searchableText(for: summary, appDisplayName: appDisplayName)
                .localizedCaseInsensitiveContains(normalizedQuery)
        }
        return sorted(filtered, by: sort)
    }

    private func sourceFilterMatches(
        _ summary: LibrarySessionSummary,
        filter: LibrarySourceFilter
    ) -> Bool {
        switch filter {
        case .all:
            return true
        case .app(let appID):
            return summary.archive.djAppID == appID
                || summary.archive.sourceAppID == appID
                || summary.hardwareBackup?.djAppID == appID
                || summary.hardwareBackup?.sourceAppID == appID
        case .pioneerHardware:
            return isPioneerHardware(summary.archive)
                || summary.hardwareBackup.map(isPioneerHardware) == true
        }
    }

    private func isPioneerHardware(_ archive: ArchiveMetadata) -> Bool {
        archive.sourceAppID == SupportedDJSoftware.pioneerHardwareAppID
            || archive.captureRoute == .inputDevice
    }

    private func sorted(
        _ summaries: [LibrarySessionSummary],
        by sort: LibrarySessionSort
    ) -> [LibrarySessionSummary] {
        summaries.sorted { lhs, rhs in
            switch sort {
            case .newestFirst:
                if lhs.performanceDate != rhs.performanceDate {
                    return lhs.performanceDate > rhs.performanceDate
                }
            case .nameAscending:
                let comparison = lhs.archive.originalFilename.localizedCaseInsensitiveCompare(
                    rhs.archive.originalFilename
                )
                if comparison != .orderedSame {
                    return comparison == .orderedAscending
                }
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    public func filterTracklists(
        _ tracklists: [ImportedTracklist],
        query: String,
        dateFilter: LibraryDateFilter = .all,
        matchedSetDates: [UUID: Date] = [:],
        appDisplayName: (String) -> String,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> [ImportedTracklist] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return tracklists.filter { tracklist in
            guard tracklistPassesDateFilter(
                tracklist,
                dateFilter: dateFilter,
                matchedSetDate: matchedSetDates[tracklist.id],
                calendar: calendar,
                now: now
            ) else { return false }

            guard !normalizedQuery.isEmpty else { return true }
            return tracklist.sourceURL.lastPathComponent.localizedCaseInsensitiveContains(normalizedQuery)
                || appDisplayName(tracklist.appID).localizedCaseInsensitiveContains(normalizedQuery)
        }
    }

    public func tracklistPassesDateFilter(
        _ tracklist: ImportedTracklist,
        dateFilter: LibraryDateFilter,
        matchedSetDate: Date?,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> Bool {
        if case .all = dateFilter { return true }
        if dateFilter.contains(tracklist.importedAt, calendar: calendar, now: now) {
            return true
        }
        if let matchedSetDate, dateFilter.contains(matchedSetDate, calendar: calendar, now: now) {
            return true
        }
        return tracklist.tracks.contains { track in
            guard let playedOn = track.playedOn else { return false }
            return dateFilter.contains(playedOn, calendar: calendar, now: now)
        }
    }

    private func searchableText(
        for summary: LibrarySessionSummary,
        appDisplayName: (String) -> String
    ) -> String {
        var values = [
            summary.archive.originalFilename,
            summary.archive.sourceAppID,
            summary.archive.djAppID,
            appDisplayName(summary.archive.sourceAppID),
            appDisplayName(summary.archive.djAppID),
            summary.archive.captureLaneLabel ?? "",
            summary.archive.sourcePath,
            summary.archive.archivePath,
            summary.context.eventName,
            summary.context.venue,
            summary.context.city,
            summary.context.tags,
            summary.context.notes
        ]

        if let matchedTracklist = summary.matchedTracklist {
            values.append(matchedTracklist.sourceURL.lastPathComponent)
            values.append(contentsOf: matchedTracklist.tracks.flatMap { [$0.artist, $0.title, $0.startTime ?? ""] })
        }

        return values.joined(separator: "\n")
    }
}

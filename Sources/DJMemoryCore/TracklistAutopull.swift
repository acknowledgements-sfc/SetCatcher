import Foundation

public enum TracklistAutopullResult: Equatable {
    case attached(ImportedTracklist)
    case notFound
    case failed(String)
}

/// Soft-fail autopull of a nearby history export after a recording is archived.
public struct TracklistAutopull {
    public init() {}

    /// App IDs whose history folders should be searched for an export near this session.
    public static func historyAppIDs(
        sourceAppID: String,
        selectedTargetAppID: String?,
        historyAccesses: [FolderAccess]
    ) -> [String] {
        if !LibrarySessionMatcher.hardwareCaptureAppIDs.contains(sourceAppID) {
            return [sourceAppID]
        }
        if let selectedTargetAppID {
            return [selectedTargetAppID]
        }
        var ids: [String] = []
        for software in SupportedDJSoftware.all {
            let hasDefaults = !software.defaultHistoryPaths.isEmpty
            let hasBookmark = historyAccesses.contains { $0.appID == software.id && $0.kind == .history }
            if hasDefaults || hasBookmark {
                ids.append(software.id)
            }
        }
        return ids
    }

    public static func parser(forHistoryAppID appID: String) -> TracklistParser {
        switch appID {
        case "serato":
            return SeratoHistoryParser()
        case "rekordbox":
            return RekordboxXMLParser()
        case "traktor":
            return TraktorNMLParser()
        case "virtualdj":
            return VirtualDJHistoryParser()
        default:
            return DelimitedTracklistParser()
        }
    }

    public static func tracklistKind(appID: String, sourceURL: URL) -> ImportedTracklistKind {
        if appID == "rekordbox", sourceURL.pathExtension.localizedCaseInsensitiveCompare("xml") == .orderedSame {
            return .collection
        }
        return .setHistory
    }

    public func attempt(
        session: RecordingSession,
        historyAppIDs: [String],
        historyAccesses: [FolderAccess],
        folderAccessStore: FolderAccessStore,
        importedTracklistStore: ImportedTracklistStore,
        activityLogStore: ActivityLogStore,
        setContextStore: SetContextStore,
        archives: [ArchiveMetadata],
        importedTracklists: [ImportedTracklist],
        setContexts: [SetContext],
        historyMatchWindowSeconds: TimeInterval = LibrarySessionMatcher.captureMatchWindowSeconds
    ) throws -> TracklistAutopullResult {
        guard !historyAppIDs.isEmpty else {
            try? activityLogStore.append(ActivityEvent(
                kind: .importTracklist,
                message: "No history export found to attach",
                detail: session.sourceURL.lastPathComponent
            ))
            return .notFound
        }

        let ingest = HistoryFolderIngest()
        let resolver = PathResolver()
        let referenceDate = session.completedAt ?? session.detectedAt
        var stoppers: [() -> Void] = []
        defer { stoppers.forEach { $0() } }

        var imported: ImportedTracklist?
        var lastFailure: String?

        for appID in historyAppIDs {
            let software = SupportedDJSoftware.all.first { $0.id == appID }
            let accessesForApp = historyAccesses.filter { $0.appID == appID && $0.kind == .history }
            var bookmarked: [URL] = []
            for access in accessesForApp {
                guard let bookmarkData = access.bookmarkData else {
                    bookmarked.append(folderAccessStore.resolve(access))
                    continue
                }
                do {
                    let scoped = try SecurityScopedAccess.beginScopedAccess(bookmarkData: bookmarkData)
                    stoppers.append(scoped.stop)
                    bookmarked.append(scoped.url)
                } catch {
                    continue
                }
            }

            let directories = ingest.historyDirectoryURLs(
                for: appID,
                defaultHistoryPaths: software?.defaultHistoryPaths ?? [],
                bookmarkedHistoryURLs: bookmarked,
                pathResolver: resolver
            )
            guard let candidate = ingest.bestCandidate(
                in: directories,
                near: referenceDate,
                windowSeconds: historyMatchWindowSeconds
            ) else {
                continue
            }

            do {
                let data = try Data(contentsOf: candidate.url)
                let parser = Self.parser(forHistoryAppID: appID)
                let tracks = try parser.parse(data: data, sourceName: candidate.url.lastPathComponent)
                var tracklist = ImportedTracklist(
                    appID: appID,
                    sourceURL: candidate.url,
                    kind: Self.tracklistKind(appID: appID, sourceURL: candidate.url),
                    tracks: tracks,
                    importedAt: candidate.modificationDate
                )
                guard tracklist.kind.isMatchableToRecording else { continue }
                tracklist = tracklist.stampingPlayedOn(Calendar.current.startOfDay(for: session.detectedAt))
                try importedTracklistStore.save(tracklist)
                imported = tracklist
                try activityLogStore.append(ActivityEvent(
                    kind: .importTracklist,
                    message: "Autopulled \(tracks.count) tracks",
                    detail: candidate.url.lastPathComponent
                ))
                break
            } catch {
                lastFailure = "\(candidate.url.lastPathComponent): \(error.localizedDescription)"
                try? activityLogStore.append(ActivityEvent(
                    kind: .error,
                    message: "History autopull failed",
                    detail: lastFailure
                ))
            }
        }

        guard let imported else {
            try? activityLogStore.append(ActivityEvent(
                kind: .importTracklist,
                message: "No history export found to attach",
                detail: session.sourceURL.lastPathComponent
            ))
            if let lastFailure {
                return .failed(lastFailure)
            }
            return .notFound
        }

        // Attachment is owned by LibrarySessionMatcher (live, time-nearest, and
        // upgradeable). We deliberately do NOT pin `manualTracklistID` here: that
        // field means "the user chose this" and must stay sacred so a later,
        // closer export can upgrade an auto-match while never overriding a human.
        return .attached(imported)
    }
}

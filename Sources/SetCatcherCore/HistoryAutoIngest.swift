import Foundation

/// Continuously keeps the imported-tracklist store fresh so that late-written
/// history exports still get attached to recent recordings.
///
/// Where ``TracklistAutopull`` fires once, right after a single archive, and
/// pulls the single best candidate for that one session, ``HistoryAutoIngest``
/// sweeps every watched history folder and ingests *every* export that lands
/// within the match window of *any* recent archive. Attachment itself is left
/// to ``LibrarySessionMatcher`` (live, time-nearest, upgradeable) — this service
/// only guarantees the export is in the store.
///
/// The sweep is idempotent: an export already ingested at or after the file's
/// current modification date is skipped, so FSEvents bursts, the backstop poll,
/// and the launch catch-up sweep can all call it freely without duplicating or
/// churning work. An export whose file grew since last ingest (history appended
/// mid-set) is re-ingested, replacing the stored copy in place.
public struct HistoryAutoIngest {
    public struct Result: Equatable {
        /// Tracklists newly imported or refreshed this sweep.
        public let ingested: [ImportedTracklist]

        public init(ingested: [ImportedTracklist]) {
            self.ingested = ingested
        }

        public var isEmpty: Bool { ingested.isEmpty }
    }

    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// Reference dates the ingest is allowed to pull near — typically the
    /// `detectedAt`/`completedAt` of recent archives. A candidate export is only
    /// ingested if it falls within `windowSeconds` of at least one of these.
    public struct ArchiveReference: Equatable, Sendable {
        public let date: Date

        public init(date: Date) {
            self.date = date
        }
    }

    /// Sweep the given history app IDs, ingesting fresh in-window exports.
    ///
    /// - Parameters:
    ///   - historyAppIDs: app IDs whose history folders to scan.
    ///   - historyAccesses: `.history` folder grants (bookmarked or resolvable).
    ///   - references: archive reference dates the ingest may pull near.
    ///   - existing: tracklists already in the store (for idempotency checks).
    ///   - windowSeconds: max distance between an export's mod-date and any reference.
    @discardableResult
    public func sweep(
        historyAppIDs: [String],
        historyAccesses: [FolderAccess],
        folderAccessStore: FolderAccessStore,
        importedTracklistStore: ImportedTracklistStore,
        activityLogStore: ActivityLogStore?,
        references: [ArchiveReference],
        existing: [ImportedTracklist],
        windowSeconds: TimeInterval = LibrarySessionMatcher.captureMatchWindowSeconds
    ) -> Result {
        guard !historyAppIDs.isEmpty, !references.isEmpty else {
            return Result(ingested: [])
        }

        let ingest = HistoryFolderIngest(fileManager: fileManager)
        let resolver = PathResolver()
        var stoppers: [() -> Void] = []
        defer { stoppers.forEach { $0() } }

        var ingested: [ImportedTracklist] = []

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

            for candidate in ingest.candidateFiles(in: directories) {
                guard Self.isWithinWindow(candidate.modificationDate, of: references, windowSeconds: windowSeconds) else {
                    continue
                }
                // Idempotency: skip if we already ingested this file at/after its
                // current mod-date. Re-ingest only when the file grew since.
                if let priorImport = existing.first(where: {
                    $0.appID == appID && $0.sourceURL.standardizedFileURL == candidate.url.standardizedFileURL
                }), priorImport.importedAt >= candidate.modificationDate {
                    continue
                }
                if ingested.contains(where: {
                    $0.appID == appID && $0.sourceURL.standardizedFileURL == candidate.url.standardizedFileURL
                }) {
                    continue
                }

                do {
                    let data = try Data(contentsOf: candidate.url)
                    let parser = TracklistAutopull.parser(forHistoryAppID: appID)
                    let tracks = try parser.parse(data: data, sourceName: candidate.url.lastPathComponent)
                    // Stamp importedAt with the export's own modification date
                    // (≈ when the set ended) rather than wall-clock ingest time.
                    // This keeps idempotency a clean mod-date-vs-mod-date compare
                    // and makes the matcher's time-nearest attach more accurate.
                    let tracklist = ImportedTracklist(
                        appID: appID,
                        sourceURL: candidate.url,
                        kind: TracklistAutopull.tracklistKind(appID: appID, sourceURL: candidate.url),
                        tracks: tracks,
                        importedAt: candidate.modificationDate
                    )
                    guard tracklist.kind.isMatchableToRecording else { continue }
                    try importedTracklistStore.save(tracklist)
                    ingested.append(tracklist)
                    try? activityLogStore?.append(ActivityEvent(
                        kind: .importTracklist,
                        message: "Auto-ingested \(tracks.count) tracks",
                        detail: candidate.url.lastPathComponent
                    ))
                } catch {
                    try? activityLogStore?.append(ActivityEvent(
                        kind: .error,
                        message: "History auto-ingest failed",
                        detail: "\(candidate.url.lastPathComponent): \(error.localizedDescription)"
                    ))
                }
            }
        }

        return Result(ingested: ingested)
    }

    static func isWithinWindow(
        _ date: Date,
        of references: [ArchiveReference],
        windowSeconds: TimeInterval
    ) -> Bool {
        references.contains { abs($0.date.timeIntervalSince(date)) <= windowSeconds }
    }
}

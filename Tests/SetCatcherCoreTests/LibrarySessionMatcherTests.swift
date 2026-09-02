import XCTest
@testable import SetCatcherCore

final class LibrarySessionMatcherTests: XCTestCase {
    func testSummariesMatchTracklistByAppID() {
        let archive = ArchiveMetadata(
            session: RecordingSession(
                sourceAppID: "serato",
                detectedAt: Date(timeIntervalSince1970: 100),
                sourceURL: URL(fileURLWithPath: "/tmp/source.wav")
            ),
            originalFilename: "source.wav"
        )
        let tracklist = ImportedTracklist(
            appID: "serato",
            sourceURL: URL(fileURLWithPath: "/tmp/history.csv"),
            tracks: [
                TrackPlay(title: "Track", artist: "Artist", startTime: nil, source: "history.csv", confidence: 0.9)
            ],
            importedAt: Date(timeIntervalSince1970: 120)
        )

        let summaries = LibrarySessionMatcher().summaries(archives: [archive], importedTracklists: [tracklist])

        XCTAssertEqual(summaries.first?.trackCount, 1)
        XCTAssertEqual(summaries.first?.matchedTracklist?.sourceURL.lastPathComponent, "history.csv")
    }

    func testSummariesDoNotMatchCollectionImports() {
        let archive = ArchiveMetadata(
            session: RecordingSession(
                sourceAppID: "rekordbox",
                detectedAt: Date(timeIntervalSince1970: 100),
                sourceURL: URL(fileURLWithPath: "/tmp/source.wav")
            ),
            originalFilename: "source.wav"
        )
        let tracklist = ImportedTracklist(
            appID: "rekordbox",
            sourceURL: URL(fileURLWithPath: "/tmp/rekordbox.xml"),
            kind: .collection,
            tracks: [
                TrackPlay(title: "Track", artist: "Artist", startTime: nil, source: "rekordbox.xml", confidence: 0.9)
            ],
            importedAt: Date(timeIntervalSince1970: 120)
        )

        let summaries = LibrarySessionMatcher().summaries(archives: [archive], importedTracklists: [tracklist])

        XCTAssertEqual(summaries.first?.trackCount, 0)
        XCTAssertNil(summaries.first?.matchedTracklist)
    }

    func testSummariesDoNotMatchDifferentAppID() {
        let archive = ArchiveMetadata(
            session: RecordingSession(
                sourceAppID: "serato",
                detectedAt: Date(timeIntervalSince1970: 100),
                sourceURL: URL(fileURLWithPath: "/tmp/source.wav")
            ),
            originalFilename: "source.wav"
        )
        let tracklist = ImportedTracklist(
            appID: "rekordbox",
            sourceURL: URL(fileURLWithPath: "/tmp/rekordbox.xml"),
            tracks: [
                TrackPlay(title: "Track", artist: "Artist", startTime: nil, source: "rekordbox.xml", confidence: 0.9)
            ],
            importedAt: Date(timeIntervalSince1970: 120)
        )

        let summaries = LibrarySessionMatcher().summaries(archives: [archive], importedTracklists: [tracklist])

        XCTAssertNil(summaries.first?.matchedTracklist)
    }

    func testAutomaticAppMatchRejectsHistoryOutsideWindow() {
        let archive = ArchiveMetadata(
            session: RecordingSession(
                sourceAppID: "serato",
                detectedAt: Date(timeIntervalSince1970: 100),
                completedAt: Date(timeIntervalSince1970: 200),
                sourceURL: URL(fileURLWithPath: "/tmp/source.wav")
            ),
            originalFilename: "source.wav"
        )
        let distant = ImportedTracklist(
            appID: "serato",
            sourceURL: URL(fileURLWithPath: "/tmp/distant.csv"),
            tracks: [TrackPlay(title: "Wrong", artist: "Artist", startTime: nil, source: "distant.csv", confidence: 1)],
            importedAt: Date(timeIntervalSince1970: 200 + LibrarySessionMatcher.captureMatchWindowSeconds + 1)
        )

        let summary = LibrarySessionMatcher().summaries(
            archives: [archive],
            importedTracklists: [distant]
        ).first

        XCTAssertNil(summary?.matchedTracklist)
        XCTAssertEqual(summary?.tracklistMatchOrigin, TracklistMatchOrigin.none)
    }

    func testManualMatchRemainsAuthoritativeOutsideAutomaticWindow() {
        let archive = ArchiveMetadata(
            session: RecordingSession(
                sourceAppID: "serato",
                detectedAt: Date(timeIntervalSince1970: 100),
                completedAt: Date(timeIntervalSince1970: 200),
                sourceURL: URL(fileURLWithPath: "/tmp/source.wav")
            ),
            originalFilename: "source.wav"
        )
        let manual = ImportedTracklist(
            appID: "serato",
            sourceURL: URL(fileURLWithPath: "/tmp/manual.csv"),
            tracks: [TrackPlay(title: "Chosen", artist: "Artist", startTime: nil, source: "manual.csv", confidence: 1)],
            importedAt: Date(timeIntervalSince1970: 200 + LibrarySessionMatcher.captureMatchWindowSeconds + 1)
        )
        let context = SetContext(sessionID: archive.id, manualTracklistID: manual.id)

        let summary = LibrarySessionMatcher().summaries(
            archives: [archive],
            importedTracklists: [manual],
            setContexts: [context]
        ).first

        XCTAssertEqual(summary?.matchedTracklist?.id, manual.id)
        XCTAssertEqual(summary?.tracklistMatchOrigin, .manual)
    }

    func testInvalidManualSelectionDoesNotFallBackToAutomaticMatch() {
        let archive = makeArchive(sourceAppID: "serato", detectedAt: 100)
        let automatic = makeTracklist(appID: "serato", filename: "automatic.csv", importedAt: 101)
        let context = SetContext(sessionID: archive.id, manualTracklistID: UUID())

        let summary = LibrarySessionMatcher().summaries(
            archives: [archive],
            importedTracklists: [automatic],
            setContexts: [context]
        ).first

        XCTAssertNil(summary?.matchedTracklist)
        XCTAssertEqual(summary?.tracklistMatchOrigin, TracklistMatchOrigin.none)
    }

    func testManualCollectionSelectionDoesNotFallBackToAutomaticMatch() {
        let archive = makeArchive(sourceAppID: "serato", detectedAt: 100)
        let automatic = makeTracklist(appID: "serato", filename: "automatic.csv", importedAt: 101)
        let collection = makeTracklist(
            appID: "serato",
            filename: "collection.xml",
            importedAt: 102,
            kind: .collection
        )
        let context = SetContext(sessionID: archive.id, manualTracklistID: collection.id)

        let summary = LibrarySessionMatcher().summaries(
            archives: [archive],
            importedTracklists: [automatic, collection],
            setContexts: [context]
        ).first

        XCTAssertNil(summary?.matchedTracklist)
        XCTAssertEqual(summary?.tracklistMatchOrigin, TracklistMatchOrigin.none)
    }

    func testAutomaticMatchIncludesExactTimeWindowBoundary() {
        let archive = makeArchive(sourceAppID: "serato", detectedAt: 1_000)
        let boundary = makeTracklist(
            appID: "serato",
            filename: "boundary.csv",
            importedAt: 1_000 + LibrarySessionMatcher.captureMatchWindowSeconds
        )

        let summary = LibrarySessionMatcher().summaries(
            archives: [archive],
            importedTracklists: [boundary]
        ).first

        XCTAssertEqual(summary?.matchedTracklist?.id, boundary.id)
    }

    func testAutomaticMatchRejectsBeforeNegativeTimeWindowBoundary() {
        let reference = LibrarySessionMatcher.captureMatchWindowSeconds + 1_000
        let archive = makeArchive(sourceAppID: "serato", detectedAt: reference)
        let outside = makeTracklist(
            appID: "serato",
            filename: "outside.csv",
            importedAt: reference - LibrarySessionMatcher.captureMatchWindowSeconds - 1
        )

        let summary = LibrarySessionMatcher().summaries(
            archives: [archive],
            importedTracklists: [outside]
        ).first

        XCTAssertNil(summary?.matchedTracklist)
    }

    func testCompletedDateTakesPrecedenceOverDetectedDate() {
        let archive = makeArchive(sourceAppID: "serato", detectedAt: 100, completedAt: 10_000)
        let nearDetection = makeTracklist(appID: "serato", filename: "detected.csv", importedAt: 101)
        let nearCompletion = makeTracklist(appID: "serato", filename: "completed.csv", importedAt: 10_001)

        let summary = LibrarySessionMatcher().summaries(
            archives: [archive],
            importedTracklists: [nearDetection, nearCompletion]
        ).first

        XCTAssertEqual(summary?.matchedTracklist?.id, nearCompletion.id)
    }

    func testHardwareCaptureMatchesAnyMatchableAppWithinWindow() {
        let archive = ArchiveMetadata(
            session: RecordingSession(
                sourceAppID: SupportedDJSoftware.captureAppID,
                detectedAt: Date(timeIntervalSince1970: 1000),
                sourceURL: URL(fileURLWithPath: "/tmp/capture.wav")
            ),
            originalFilename: "capture.wav"
        )
        // A Serato export (not rekordbox) played through hardware Capture.
        let serato = ImportedTracklist(
            appID: "serato",
            sourceURL: URL(fileURLWithPath: "/tmp/serato.csv"),
            tracks: [TrackPlay(title: "T", artist: "A", startTime: nil, source: "serato.csv", confidence: 0.9)],
            importedAt: Date(timeIntervalSince1970: 1100)
        )

        let summaries = LibrarySessionMatcher().summaries(archives: [archive], importedTracklists: [serato])

        XCTAssertEqual(summaries.first?.matchedTracklist?.sourceURL.lastPathComponent, "serato.csv")
    }

    func testAppAudioCaptureWithCompanionMatchesOnlyThatApp() {
        let archive = ArchiveMetadata(
            sessionID: UUID(),
            sourceAppID: SupportedDJSoftware.captureAppID,
            detectedAt: Date(timeIntervalSince1970: 1000),
            completedAt: Date(timeIntervalSince1970: 2000),
            sourcePath: "/tmp/capture.wav",
            archivePath: "/archive/capture.wav",
            fileSize: 1,
            originalFilename: "capture.wav",
            durationSeconds: 1000,
            ingestionKind: .capture,
            companionAppID: "serato",
            captureRoute: .appAudio
        )
        let serato = makeTracklist(appID: "serato", filename: "serato.csv", importedAt: 1100)
        let traktor = makeTracklist(appID: "traktor", filename: "traktor.nml", importedAt: 1050)

        let summary = LibrarySessionMatcher().summaries(
            archives: [archive],
            importedTracklists: [serato, traktor]
        ).first

        XCTAssertEqual(summary?.matchedTracklist?.id, serato.id)
    }

    func testHardwareCaptureUpgradesToCloserExport() {
        let archive = ArchiveMetadata(
            session: RecordingSession(
                sourceAppID: SupportedDJSoftware.captureAppID,
                detectedAt: Date(timeIntervalSince1970: 1000),
                sourceURL: URL(fileURLWithPath: "/tmp/capture.wav")
            ),
            originalFilename: "capture.wav"
        )
        let farther = ImportedTracklist(
            appID: "serato",
            sourceURL: URL(fileURLWithPath: "/tmp/early.csv"),
            tracks: [TrackPlay(title: "T", artist: "A", startTime: nil, source: "early.csv", confidence: 0.9)],
            importedAt: Date(timeIntervalSince1970: 500)
        )
        let closer = ImportedTracklist(
            appID: "traktor",
            sourceURL: URL(fileURLWithPath: "/tmp/late.nml"),
            tracks: [TrackPlay(title: "T", artist: "A", startTime: nil, source: "late.nml", confidence: 0.9)],
            importedAt: Date(timeIntervalSince1970: 1050)
        )

        let summaries = LibrarySessionMatcher().summaries(
            archives: [archive],
            importedTracklists: [farther, closer]
        )

        XCTAssertEqual(summaries.first?.matchedTracklist?.sourceURL.lastPathComponent, "late.nml")
    }

    func testHardwareCaptureChoosesNearestExportRegardlessOfInputOrder() {
        let archive = makeArchive(sourceAppID: SupportedDJSoftware.captureAppID, detectedAt: 1_000)
        let closer = makeTracklist(appID: "virtualdj", filename: "closer.json", importedAt: 990)
        let farther = makeTracklist(appID: "traktor", filename: "farther.nml", importedAt: 800)
        let matcher = LibrarySessionMatcher()

        let forward = matcher.summaries(
            archives: [archive],
            importedTracklists: [closer, farther]
        ).first
        let reversed = matcher.summaries(
            archives: [archive],
            importedTracklists: [farther, closer]
        ).first

        XCTAssertEqual(forward?.matchedTracklist?.id, closer.id)
        XCTAssertEqual(reversed?.matchedTracklist?.id, closer.id)
    }

    func testPioneerHardwareCaptureMatchesAnyMatchableApp() {
        let archive = makeArchive(
            sourceAppID: SupportedDJSoftware.pioneerHardwareAppID,
            detectedAt: 1_000
        )
        let traktor = makeTracklist(appID: "traktor", filename: "history.nml", importedAt: 1_050)

        let summary = LibrarySessionMatcher().summaries(
            archives: [archive],
            importedTracklists: [traktor]
        ).first

        XCTAssertEqual(summary?.matchedTracklist?.id, traktor.id)
    }

    func testHardwareCaptureExcludesCollectionsAndOutOfWindowExports() {
        let archive = makeArchive(sourceAppID: SupportedDJSoftware.captureAppID, detectedAt: 1_000)
        let collection = makeTracklist(
            appID: "rekordbox",
            filename: "collection.xml",
            importedAt: 1_001,
            kind: .collection
        )
        let distantHistory = makeTracklist(
            appID: "serato",
            filename: "distant.csv",
            importedAt: 1_000 + LibrarySessionMatcher.captureMatchWindowSeconds + 1
        )

        let summary = LibrarySessionMatcher().summaries(
            archives: [archive],
            importedTracklists: [collection, distantHistory]
        ).first

        XCTAssertNil(summary?.matchedTracklist)
    }

    func testManualTracklistContextOverridesNearestAutomaticMatch() {
        let archive = ArchiveMetadata(
            session: RecordingSession(
                sourceAppID: "serato",
                detectedAt: Date(timeIntervalSince1970: 100),
                sourceURL: URL(fileURLWithPath: "/tmp/source.wav")
            ),
            originalFilename: "source.wav"
        )
        let automaticTracklist = ImportedTracklist(
            id: UUID(),
            appID: "serato",
            sourceURL: URL(fileURLWithPath: "/tmp/automatic.csv"),
            tracks: [
                TrackPlay(title: "Automatic", artist: "Artist", startTime: nil, source: "automatic.csv", confidence: 0.9)
            ],
            importedAt: Date(timeIntervalSince1970: 101)
        )
        let manualTracklist = ImportedTracklist(
            id: UUID(),
            appID: "serato",
            sourceURL: URL(fileURLWithPath: "/tmp/manual.csv"),
            tracks: [
                TrackPlay(title: "Manual", artist: "Artist", startTime: nil, source: "manual.csv", confidence: 0.9)
            ],
            importedAt: Date(timeIntervalSince1970: 300)
        )
        let context = SetContext(sessionID: archive.id, manualTracklistID: manualTracklist.id)

        let summaries = LibrarySessionMatcher().summaries(
            archives: [archive],
            importedTracklists: [automaticTracklist, manualTracklist],
            setContexts: [context]
        )

        XCTAssertEqual(summaries.first?.matchedTracklist?.sourceURL.lastPathComponent, "manual.csv")
    }

    func testCaptureArchiveMatchesRekordboxTracklistWithinWindow() {
        let archive = ArchiveMetadata(
            session: RecordingSession(sourceAppID: SupportedDJSoftware.captureAppID, detectedAt: Date(timeIntervalSince1970: 1000), sourceURL: URL(fileURLWithPath: "/SetCatcherCapture/DJM/set.wav")),
            originalFilename: "set.wav"
        )
        let tracklist = ImportedTracklist(appID: "rekordbox", sourceURL: URL(fileURLWithPath: "/tmp/history.txt"), tracks: [TrackPlay(title: "Track", artist: "Artist", startTime: nil, source: "history.txt", confidence: 0.9)], importedAt: Date(timeIntervalSince1970: 1200))
        let summaries = LibrarySessionMatcher().summaries(archives: [archive], importedTracklists: [tracklist])
        XCTAssertEqual(summaries.first?.matchedTracklist?.appID, "rekordbox")
    }

    func testSeratoSessionResearchDetectsFilename() {
        XCTAssertTrue(SeratoSessionResearch.looksLikeSessionFilename("live.session"))
        XCTAssertFalse(SeratoSessionResearch.looksLikeSessionFilename("history.csv"))
    }

    private func makeArchive(
        sourceAppID: String,
        detectedAt: TimeInterval,
        completedAt: TimeInterval? = nil
    ) -> ArchiveMetadata {
        ArchiveMetadata(
            session: RecordingSession(
                sourceAppID: sourceAppID,
                detectedAt: Date(timeIntervalSince1970: detectedAt),
                completedAt: completedAt.map(Date.init(timeIntervalSince1970:)),
                sourceURL: URL(fileURLWithPath: "/tmp/\(UUID().uuidString).wav")
            ),
            originalFilename: "source.wav"
        )
    }

    private func makeTracklist(
        appID: String,
        filename: String,
        importedAt: TimeInterval,
        kind: ImportedTracklistKind = .setHistory
    ) -> ImportedTracklist {
        ImportedTracklist(
            appID: appID,
            sourceURL: URL(fileURLWithPath: "/tmp/\(filename)"),
            kind: kind,
            tracks: [
                TrackPlay(
                    title: "Track",
                    artist: "Artist",
                    startTime: nil,
                    source: filename,
                    confidence: 1
                )
            ],
            importedAt: Date(timeIntervalSince1970: importedAt)
        )
    }
}

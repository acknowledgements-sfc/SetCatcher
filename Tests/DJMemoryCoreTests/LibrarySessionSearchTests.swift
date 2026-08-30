import XCTest
@testable import DJMemoryCore

final class LibrarySessionSearchTests: XCTestCase {
    func testFilterMatchesArchiveAndContextFields() {
        let summary = LibrarySessionSummary(
            archive: archive(filename: "2026-08-06 2230 - Serato DJ Pro - Set.wav"),
            matchedTracklist: nil,
            context: SetContext(
                sessionID: UUID(),
                eventName: "Warehouse Set",
                venue: "Room 2",
                city: "San Francisco",
                tags: "house late",
                notes: "Peak hour"
            )
        )
        let other = LibrarySessionSummary(
            archive: archive(filename: "Practice.wav", appID: "rekordbox"),
            matchedTracklist: nil
        )

        let results = LibrarySessionSearch().filter(
            [summary, other],
            query: "room 2",
            appDisplayName: appDisplayName(for:)
        )

        XCTAssertEqual(results.map(\.archive.originalFilename), [summary.archive.originalFilename])
    }

    func testFilterMatchesAppAndTracklistFields() {
        let tracklist = ImportedTracklist(
            appID: "serato",
            sourceURL: URL(fileURLWithPath: "/Exports/private-history.csv"),
            tracks: [
                TrackPlay(title: "Night Drive", artist: "Avery", startTime: "23:10", source: "private-history.csv", confidence: 1.0)
            ]
        )
        let summary = LibrarySessionSummary(
            archive: archive(filename: "Set.wav"),
            matchedTracklist: tracklist
        )

        let appResults = LibrarySessionSearch().filter(
            [summary],
            query: "Serato DJ Pro",
            appDisplayName: appDisplayName(for:)
        )
        let trackResults = LibrarySessionSearch().filter(
            [summary],
            query: "Night Drive",
            appDisplayName: appDisplayName(for:)
        )

        XCTAssertEqual(appResults.count, 1)
        XCTAssertEqual(trackResults.count, 1)
    }

    func testBlankQueryReturnsAllSummaries() {
        let summaries = [
            LibrarySessionSummary(archive: archive(filename: "One.wav"), matchedTracklist: nil),
            LibrarySessionSummary(archive: archive(filename: "Two.wav"), matchedTracklist: nil)
        ]

        let results = LibrarySessionSearch().filter(
            summaries,
            query: " ",
            appDisplayName: appDisplayName(for:)
        )

        XCTAssertEqual(Set(results.map(\.id)), Set(summaries.map(\.id)))
    }

    func testDateFilterUsesDetectedAt() {
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 9, hour: 12))!
        let today = LibrarySessionSummary(
            archive: archive(filename: "Today.wav", detectedAt: now),
            matchedTracklist: nil
        )
        let older = LibrarySessionSummary(
            archive: archive(
                filename: "Older.wav",
                detectedAt: calendar.date(byAdding: .day, value: -3, to: now)!
            ),
            matchedTracklist: nil
        )

        let filtered = LibrarySessionSearch().filter(
            [today, older],
            query: "",
            dateFilter: .today,
            appDisplayName: appDisplayName(for:),
            calendar: calendar,
            now: now
        )

        XCTAssertEqual(filtered.map(\.archive.originalFilename), ["Today.wav"])
    }

    func testSortFilterAndSearchCompose() {
        let newestSerato = LibrarySessionSummary(
            archive: archive(filename: "Zulu.wav", appID: "serato", detectedAt: Date(timeIntervalSince1970: 300)),
            matchedTracklist: nil,
            context: SetContext(sessionID: UUID(), venue: "Room 2")
        )
        let olderSerato = LibrarySessionSummary(
            archive: archive(filename: "Alpha.wav", appID: "serato", detectedAt: Date(timeIntervalSince1970: 200)),
            matchedTracklist: nil,
            context: SetContext(sessionID: UUID(), venue: "Room 2")
        )
        let rekordbox = LibrarySessionSummary(
            archive: archive(filename: "Beta.wav", appID: "rekordbox", detectedAt: Date(timeIntervalSince1970: 400)),
            matchedTracklist: nil,
            context: SetContext(sessionID: UUID(), venue: "Room 2")
        )

        let results = LibrarySessionSearch().filter(
            [newestSerato, olderSerato, rekordbox],
            query: "Room 2",
            sourceFilter: .app("serato"),
            sort: .nameAscending,
            appDisplayName: appDisplayName(for:)
        )

        XCTAssertEqual(results.map(\.archive.originalFilename), ["Alpha.wav", "Zulu.wav"])
    }

    func testPioneerFilterIncludesStandaloneInputAndLinkedBackup() {
        let inputCapture = archive(
            filename: "Input.wav",
            appID: SupportedDJSoftware.captureAppID,
            detectedAt: Date(timeIntervalSince1970: 300),
            captureRoute: .inputDevice
        )
        let primary = archive(filename: "Serato.wav", detectedAt: Date(timeIntervalSince1970: 200))
        let backup = archive(
            filename: "Backup.wav",
            appID: SupportedDJSoftware.captureAppID,
            detectedAt: Date(timeIntervalSince1970: 190),
            captureRoute: .inputDevice
        )
        let summaries = [
            LibrarySessionSummary(archive: inputCapture, matchedTracklist: nil),
            LibrarySessionSummary(archive: primary, matchedTracklist: nil, hardwareBackup: backup)
        ]

        let results = LibrarySessionSearch().filter(
            summaries,
            query: "",
            sourceFilter: .pioneerHardware,
            appDisplayName: appDisplayName(for:)
        )

        XCTAssertEqual(Set(results.map(\.archive.originalFilename)), Set(["Input.wav", "Serato.wav"]))
    }

    func testNewestFirstUsesPerformanceDateIncludingHardwareBackup() {
        let laterPrimaryWithEarlierBackup = LibrarySessionSummary(
            archive: archive(filename: "Linked.wav", detectedAt: Date(timeIntervalSince1970: 300)),
            matchedTracklist: nil,
            hardwareBackup: archive(
                filename: "Hardware.wav",
                appID: SupportedDJSoftware.captureAppID,
                detectedAt: Date(timeIntervalSince1970: 100),
                captureRoute: .inputDevice
            )
        )
        let standalone = LibrarySessionSummary(
            archive: archive(filename: "Standalone.wav", detectedAt: Date(timeIntervalSince1970: 200)),
            matchedTracklist: nil
        )

        let results = LibrarySessionSearch().filter(
            [laterPrimaryWithEarlierBackup, standalone],
            query: "",
            sort: .newestFirst,
            appDisplayName: appDisplayName(for:)
        )

        XCTAssertEqual(results.map(\.archive.originalFilename), ["Standalone.wav", "Linked.wav"])
    }

    func testNameAscendingIsCaseInsensitiveAndUsesIDForEqualNames() {
        let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let first = LibrarySessionSummary(
            archive: archive(filename: "ALPHA.wav"),
            matchedTracklist: nil,
            id: firstID
        )
        let second = LibrarySessionSummary(
            archive: archive(filename: "alpha.wav"),
            matchedTracklist: nil,
            id: secondID
        )
        let third = LibrarySessionSummary(
            archive: archive(filename: "Beta.wav"),
            matchedTracklist: nil
        )

        let results = LibrarySessionSearch().filter(
            [third, second, first],
            query: "",
            sort: .nameAscending,
            appDisplayName: appDisplayName(for:)
        )

        XCTAssertEqual(results.map(\.archive.originalFilename), ["ALPHA.wav", "alpha.wav", "Beta.wav"])
    }

    func testAppFilterMatchesPrimaryAndHardwareBackupAndRejectsUnknownSource() {
        let primaryMatch = LibrarySessionSummary(
            archive: archive(filename: "Rekordbox.wav", appID: "rekordbox"),
            matchedTracklist: nil
        )
        let backupMatch = LibrarySessionSummary(
            archive: archive(filename: "Serato.wav", appID: "serato"),
            matchedTracklist: nil,
            hardwareBackup: archive(filename: "Backup.wav", appID: "rekordbox")
        )
        let nonMatch = LibrarySessionSummary(
            archive: archive(filename: "Other.wav", appID: "serato"),
            matchedTracklist: nil
        )
        let summaries = [nonMatch, backupMatch, primaryMatch]

        let rekordbox = LibrarySessionSearch().filter(
            summaries,
            query: "",
            sourceFilter: .app("rekordbox"),
            appDisplayName: appDisplayName(for:)
        )
        let unknown = LibrarySessionSearch().filter(
            summaries,
            query: "",
            sourceFilter: .app("unknown"),
            appDisplayName: appDisplayName(for:)
        )

        XCTAssertEqual(Set(rekordbox.map(\.archive.originalFilename)), Set(["Rekordbox.wav", "Serato.wav"]))
        XCTAssertTrue(unknown.isEmpty)
    }

    func testQueryDateSourceAndNewestSortCompose() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 29, hour: 12))!
        let newest = LibrarySessionSummary(
            archive: archive(filename: "Newest.wav", detectedAt: now.addingTimeInterval(-60)),
            matchedTracklist: nil,
            context: SetContext(sessionID: UUID(), eventName: "Warehouse Session")
        )
        let earlier = LibrarySessionSummary(
            archive: archive(filename: "Earlier.wav", detectedAt: now.addingTimeInterval(-120)),
            matchedTracklist: nil,
            context: SetContext(sessionID: UUID(), eventName: "Warehouse Session")
        )
        let wrongSource = LibrarySessionSummary(
            archive: archive(filename: "Rekordbox.wav", appID: "rekordbox", detectedAt: now),
            matchedTracklist: nil,
            context: SetContext(sessionID: UUID(), eventName: "Warehouse Session")
        )
        let wrongDate = LibrarySessionSummary(
            archive: archive(
                filename: "Old.wav",
                detectedAt: calendar.date(byAdding: .day, value: -2, to: now)!
            ),
            matchedTracklist: nil,
            context: SetContext(sessionID: UUID(), eventName: "Warehouse Session")
        )

        let results = LibrarySessionSearch().filter(
            [earlier, wrongSource, wrongDate, newest],
            query: "  WAREHOUSE  ",
            dateFilter: .today,
            sourceFilter: .app("serato"),
            sort: .newestFirst,
            appDisplayName: appDisplayName(for:),
            calendar: calendar,
            now: now
        )

        XCTAssertEqual(results.map(\.archive.originalFilename), ["Newest.wav", "Earlier.wav"])
    }

    func testEmptyInputAndNoMatchReturnEmptyResults() {
        let search = LibrarySessionSearch()
        XCTAssertTrue(search.filter([], query: "anything", appDisplayName: appDisplayName(for:)).isEmpty)

        let noMatch = search.filter(
            [LibrarySessionSummary(archive: archive(filename: "Set.wav"), matchedTracklist: nil)],
            query: "not present",
            appDisplayName: appDisplayName(for:)
        )
        XCTAssertTrue(noMatch.isEmpty)
    }

    func testTracklistFilterSearchesFilenameAndAppCaseInsensitively() {
        let serato = tracklist(filename: "Warehouse-History.csv", appID: "serato")
        let rekordbox = tracklist(filename: "Club.xml", appID: "rekordbox")
        let search = LibrarySessionSearch()

        let filenameResults = search.filterTracklists(
            [serato, rekordbox],
            query: "  warehouse  ",
            appDisplayName: appDisplayName(for:)
        )
        let appResults = search.filterTracklists(
            [serato, rekordbox],
            query: "SERATO DJ PRO",
            appDisplayName: appDisplayName(for:)
        )

        XCTAssertEqual(filenameResults.map(\.id), [serato.id])
        XCTAssertEqual(appResults.map(\.id), [serato.id])
    }

    func testTracklistDateFilterAcceptsImportMatchedSetAndPlayedOnDates() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 29, hour: 12))!
        let old = calendar.date(byAdding: .day, value: -7, to: now)!
        let importedToday = tracklist(filename: "Imported.csv", importedAt: now)
        let matchedToday = tracklist(filename: "Matched.csv", importedAt: old)
        let playedToday = tracklist(filename: "Played.csv", importedAt: old, playedOn: now)
        let oldOnly = tracklist(filename: "Old.csv", importedAt: old, playedOn: old)

        let results = LibrarySessionSearch().filterTracklists(
            [importedToday, matchedToday, playedToday, oldOnly],
            query: "",
            dateFilter: .today,
            matchedSetDates: [matchedToday.id: now],
            appDisplayName: appDisplayName(for:),
            calendar: calendar,
            now: now
        )

        XCTAssertEqual(Set(results.map(\.id)), Set([importedToday.id, matchedToday.id, playedToday.id]))
    }

    private func archive(
        filename: String,
        appID: String = "serato",
        detectedAt: Date = Date(timeIntervalSince1970: 100),
        captureRoute: CaptureArchiveRoute? = nil
    ) -> ArchiveMetadata {
        let id = UUID()
        return ArchiveMetadata(
            sessionID: id,
            sourceAppID: appID,
            detectedAt: detectedAt,
            completedAt: detectedAt.addingTimeInterval(20),
            sourcePath: "/Source/\(filename)",
            archivePath: "/Archive/\(filename)",
            fileSize: 100,
            originalFilename: filename,
            durationSeconds: 60,
            captureRoute: captureRoute
        )
    }

    private func appDisplayName(for appID: String) -> String {
        switch appID {
        case "serato":
            return "Serato DJ Pro"
        case "rekordbox":
            return "rekordbox"
        default:
            return appID
        }
    }

    private func tracklist(
        filename: String,
        appID: String = "serato",
        importedAt: Date = Date(timeIntervalSince1970: 100),
        playedOn: Date? = nil
    ) -> ImportedTracklist {
        ImportedTracklist(
            appID: appID,
            sourceURL: URL(fileURLWithPath: "/Exports/\(filename)"),
            tracks: [
                TrackPlay(
                    title: "Track",
                    artist: "Artist",
                    startTime: "23:00",
                    source: filename,
                    confidence: 1,
                    playedOn: playedOn
                )
            ],
            importedAt: importedAt
        )
    }
}

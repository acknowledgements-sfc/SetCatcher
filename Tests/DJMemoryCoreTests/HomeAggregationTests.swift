import XCTest
@testable import DJMemoryCore

final class DJProfileStoreTests: XCTestCase {
    func testEmptyProfileHasNoInitials() {
        XCTAssertNil(DJProfile().initials)
        XCTAssertNil(DJProfile().firstName)
    }

    func testInitialsFromDisplayName() {
        XCTAssertEqual(DJProfile(displayName: "Ada Lovelace").initials, "AL")
        XCTAssertEqual(DJProfile(displayName: "Prince").initials, "P")
        XCTAssertEqual(DJProfile(displayName: "Ada Lovelace").firstName, "Ada")
    }

    func testLegacyEmptyJSONDecodes() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("profile.json")
        try Data("{}".utf8).write(to: url)
        let profile = try DJProfileStore(storageURL: url).load()
        XCTAssertNil(profile.displayName)
    }
}

final class LibraryStatisticsTests: XCTestCase {
    func testEmptyLibrary() {
        let stats = LibraryStatisticsCalculator.calculate(archives: [], summaries: [])
        XCTAssertEqual(stats.totalDurationSeconds, 0)
        XCTAssertEqual(stats.totalFileSize, 0)
        XCTAssertEqual(stats.setsThisMonth, 0)
        XCTAssertEqual(stats.unmatchedCount, 0)
        XCTAssertNil(stats.consecutiveWeeksRunning)
    }

    func testSumsAndUnmatched() {
        let a = ArchiveMetadata(
            sessionID: UUID(),
            sourceAppID: "serato",
            detectedAt: Date(),
            completedAt: nil,
            sourcePath: "/a",
            archivePath: "/A",
            fileSize: 100,
            originalFilename: "a.wav",
            durationSeconds: 60,
            sourceFingerprint: "1"
        )
        let b = ArchiveMetadata(
            sessionID: UUID(),
            sourceAppID: "serato",
            detectedAt: Date(),
            completedAt: nil,
            sourcePath: "/b",
            archivePath: "/B",
            fileSize: 50,
            originalFilename: "b.wav",
            durationSeconds: nil,
            sourceFingerprint: "2"
        )
        let summaries = [
            LibrarySessionSummary(archive: a, matchedTracklist: nil),
            LibrarySessionSummary(archive: b, matchedTracklist: ImportedTracklist(appID: "serato", sourceURL: URL(fileURLWithPath: "/t.csv"), tracks: []))
        ]
        let stats = LibraryStatisticsCalculator.calculate(archives: [a, b], summaries: summaries)
        XCTAssertEqual(stats.totalDurationSeconds, 60)
        XCTAssertEqual(stats.totalFileSize, 150)
        XCTAssertEqual(stats.unmatchedCount, 1)
        XCTAssertEqual(stats.setsThisMonth, 2)
    }
}

final class CrossSetAggregationTests: XCTestCase {
    func testTrackPlayCountIdentityIsStableAndNormalized() {
        let first = TrackPlayCount(title: "  Track A ", artist: "Artist X", playCount: 1, lastEventName: "Set 1")
        let equivalent = TrackPlayCount(title: "track a", artist: " artist x ", playCount: 4, lastEventName: "Set 2")
        let different = TrackPlayCount(title: "Track B", artist: "Artist X", playCount: 1, lastEventName: "Set 1")

        XCTAssertEqual(first.id, equivalent.id)
        XCTAssertNotEqual(first.id, different.id)
    }

    func testCollectionImportsExcluded() {
        let history = ImportedTracklist(
            appID: "serato",
            sourceURL: URL(fileURLWithPath: "/h.csv"),
            kind: .setHistory,
            tracks: [TrackPlay(title: "A", artist: "X", startTime: nil, source: "t", confidence: 1)]
        )
        let collection = ImportedTracklist(
            appID: "rekordbox",
            sourceURL: URL(fileURLWithPath: "/c.xml"),
            kind: .collection,
            tracks: [
                TrackPlay(title: "A", artist: "X", startTime: nil, source: "t", confidence: 1),
                TrackPlay(title: "B", artist: "Y", startTime: nil, source: "t", confidence: 1)
            ]
        )
        let top = CrossSetAggregation.topTracks(from: [history, collection])
        XCTAssertEqual(top.count, 1)
        XCTAssertEqual(top[0].title, "A")
        XCTAssertEqual(top[0].playCount, 1)
    }

    func testTopTracksAggregateEquivalentArtistAndTitle() {
        let history = ImportedTracklist(
            appID: "serato",
            sourceURL: URL(fileURLWithPath: "/h.csv"),
            kind: .setHistory,
            tracks: [
                TrackPlay(title: "Track A", artist: "Artist X", startTime: nil, source: "t", confidence: 1),
                TrackPlay(title: " track a ", artist: "artist x", startTime: nil, source: "t", confidence: 1)
            ]
        )

        let top = CrossSetAggregation.topTracks(from: [history])

        XCTAssertEqual(top.count, 1)
        XCTAssertEqual(top[0].playCount, 2)
        XCTAssertEqual(top[0].id, TrackPlayCount(title: "Track A", artist: "Artist X", playCount: 2, lastEventName: "").id)
    }

    func testTopTracksSortIsDeterministicByPlayCountThenTitle() {
        let history = ImportedTracklist(
            appID: "serato",
            sourceURL: URL(fileURLWithPath: "/h.csv"),
            kind: .setHistory,
            tracks: [
                TrackPlay(title: "Beta", artist: "A", startTime: nil, source: "t", confidence: 1),
                TrackPlay(title: "Alpha", artist: "A", startTime: nil, source: "t", confidence: 1),
                TrackPlay(title: "Beta", artist: "A", startTime: nil, source: "t", confidence: 1),
                TrackPlay(title: "Gamma", artist: "A", startTime: nil, source: "t", confidence: 1),
                TrackPlay(title: "Alpha", artist: "A", startTime: nil, source: "t", confidence: 1),
                TrackPlay(title: "Alpha", artist: "A", startTime: nil, source: "t", confidence: 1)
            ]
        )

        let top = CrossSetAggregation.topTracks(from: [history], limit: 8)
        XCTAssertEqual(top.map(\.title), ["Alpha", "Beta", "Gamma"])
        XCTAssertEqual(top.map(\.playCount), [3, 2, 1])
        // Same inputs → same order (stable ranking for ForEach identity).
        let again = CrossSetAggregation.topTracks(from: [history], limit: 8)
        XCTAssertEqual(again.map(\.id), top.map(\.id))
        XCTAssertEqual(again.map(\.playCount), top.map(\.playCount))
    }

    func testMixedCaseTags() {
        let contexts = [
            SetContext(sessionID: UUID(), tags: "Techno, House"),
            SetContext(sessionID: UUID(), tags: "techno, Disco")
        ]
        let tags = CrossSetAggregation.tags(from: contexts)
        XCTAssertEqual(tags.first { $0.display.lowercased() == "techno" }?.count, 2)
        XCTAssertEqual(tags.first { $0.display.lowercased() == "techno" }?.display, "Techno")
    }

    func testVenuesSkipEmpty() {
        let contexts = [
            SetContext(sessionID: UUID(), venue: "Fabric", city: "London"),
            SetContext(sessionID: UUID(), venue: "", city: "London"),
            SetContext(sessionID: UUID(), venue: "Fabric", city: "London")
        ]
        let venues = CrossSetAggregation.venues(from: contexts)
        XCTAssertEqual(venues.count, 1)
        XCTAssertEqual(venues[0].setCount, 2)
    }
}

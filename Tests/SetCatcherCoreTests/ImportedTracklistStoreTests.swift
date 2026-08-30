import XCTest
@testable import SetCatcherCore

final class ImportedTracklistStoreTests: XCTestCase {
    private var tempRoot: URL!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("SetCatcherTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempRoot)
        tempRoot = nil
    }

    func testSavePersistsImportedTracklist() throws {
        let store = ImportedTracklistStore(storageURL: tempRoot.appendingPathComponent("tracklists.json"))
        let track = TrackPlay(title: "Good Life", artist: "Inner City", startTime: "00:00", source: "test.csv", confidence: 0.9)
        let tracklist = ImportedTracklist(
            appID: "serato",
            sourceURL: URL(fileURLWithPath: "/tmp/test.csv"),
            tracks: [track]
        )

        try store.save(tracklist)

        let imported = try store.all()
        XCTAssertEqual(imported.count, 1)
        XCTAssertEqual(imported.first?.tracks.first?.title, "Good Life")
        XCTAssertEqual(imported.first?.kind, .setHistory)
    }

    func testSaveReplacesSameAppAndSource() throws {
        let store = ImportedTracklistStore(storageURL: tempRoot.appendingPathComponent("tracklists.json"))
        let sourceURL = URL(fileURLWithPath: "/tmp/test.csv")
        let first = ImportedTracklist(appID: "serato", sourceURL: sourceURL, tracks: [])
        let second = ImportedTracklist(appID: "serato", sourceURL: sourceURL, tracks: [
            TrackPlay(title: "Show Me Love", artist: "Robin S", startTime: nil, source: "test.csv", confidence: 0.9)
        ])

        try store.save(first)
        try store.save(second)

        let imported = try store.all()
        XCTAssertEqual(imported.count, 1)
        XCTAssertEqual(imported.first?.tracks.first?.title, "Show Me Love")
    }

    func testRemoveDeletesImportedTracklistByID() throws {
        let store = ImportedTracklistStore(storageURL: tempRoot.appendingPathComponent("tracklists.json"))
        let tracklist = ImportedTracklist(appID: "serato", sourceURL: URL(fileURLWithPath: "/tmp/test.csv"), tracks: [])

        try store.save(tracklist)
        try store.remove(id: tracklist.id)

        XCTAssertTrue(try store.all().isEmpty)
    }

    func testDecodeLegacyImportDefaultsToSetHistory() throws {
        let store = ImportedTracklistStore(storageURL: tempRoot.appendingPathComponent("tracklists.json"))
        let json = """
        [
          {
            "appID" : "serato",
            "id" : "00000000-0000-0000-0000-000000000001",
            "importedAt" : "2026-08-06T12:00:00Z",
            "sourceURL" : "file:///tmp/test.csv",
            "tracks" : []
          }
        ]
        """
        try Data(json.utf8).write(to: store.storageURL)

        let imported = try store.all()

        XCTAssertEqual(imported.first?.kind, .setHistory)
    }

    func testDecodeLegacyRekordboxXMLImportDefaultsToCollection() throws {
        let store = ImportedTracklistStore(storageURL: tempRoot.appendingPathComponent("tracklists.json"))
        let json = """
        [
          {
            "appID" : "rekordbox",
            "id" : "00000000-0000-0000-0000-000000000002",
            "importedAt" : "2026-08-06T12:00:00Z",
            "sourceURL" : "file:///tmp/rekordbox.xml",
            "tracks" : []
          }
        ]
        """
        try Data(json.utf8).write(to: store.storageURL)

        let imported = try store.all()

        XCTAssertEqual(imported.first?.kind, .collection)
    }
}

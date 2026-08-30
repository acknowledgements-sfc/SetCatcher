import XCTest
@testable import SetCatcherCore

final class HistoryAutoIngestTests: XCTestCase {
    private var tempRoot: URL!

    override func setUp() {
        super.setUp()
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("setcatcher-history-ingest-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempRoot)
        tempRoot = nil
        super.tearDown()
    }

    private func stores() -> (FolderAccessStore, ImportedTracklistStore, ActivityLogStore) {
        (
            FolderAccessStore(storageURL: tempRoot.appendingPathComponent("folder-access.json")),
            ImportedTracklistStore(storageURL: tempRoot.appendingPathComponent("tracklists.json")),
            ActivityLogStore(storageURL: tempRoot.appendingPathComponent("activity.json"))
        )
    }

    private func writeHistory(_ name: String, modifiedAt: Date) throws -> URL {
        let dir = tempRoot.appendingPathComponent("djay-history", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent(name)
        let csv = """
        artist,title,start time
        Inner City,Good Life,00:00
        Robin S,Show Me Love,04:12
        """
        try Data(csv.utf8).write(to: file)
        try FileManager.default.setAttributes([.modificationDate: modifiedAt], ofItemAtPath: file.path)
        return file
    }

    private func historyAccess() -> FolderAccess {
        FolderAccess(
            appID: "djay",
            kind: .history,
            url: tempRoot.appendingPathComponent("djay-history", isDirectory: true),
            bookmarkData: nil
        )
    }

    func testIngestsInWindowExport() throws {
        let reference = Date(timeIntervalSince1970: 1_700_000_000)
        _ = try writeHistory("export.csv", modifiedAt: reference.addingTimeInterval(30))
        let (folderStore, tracklistStore, activityStore) = stores()

        let result = HistoryAutoIngest().sweep(
            historyAppIDs: ["djay"],
            historyAccesses: [historyAccess()],
            folderAccessStore: folderStore,
            importedTracklistStore: tracklistStore,
            activityLogStore: activityStore,
            references: [.init(date: reference)],
            existing: [],
            windowSeconds: 300
        )

        XCTAssertEqual(result.ingested.count, 1)
        XCTAssertEqual(result.ingested.first?.tracks.count, 2)
        XCTAssertEqual(try tracklistStore.all().count, 1)
    }

    func testSkipsExportOutsideWindow() throws {
        let reference = Date(timeIntervalSince1970: 1_700_000_000)
        _ = try writeHistory("export.csv", modifiedAt: reference.addingTimeInterval(10_000))
        let (folderStore, tracklistStore, activityStore) = stores()

        let result = HistoryAutoIngest().sweep(
            historyAppIDs: ["djay"],
            historyAccesses: [historyAccess()],
            folderAccessStore: folderStore,
            importedTracklistStore: tracklistStore,
            activityLogStore: activityStore,
            references: [.init(date: reference)],
            existing: [],
            windowSeconds: 300
        )

        XCTAssertTrue(result.isEmpty)
        XCTAssertEqual(try tracklistStore.all().count, 0)
    }

    func testIdempotentWhenFileUnchanged() throws {
        let reference = Date(timeIntervalSince1970: 1_700_000_000)
        _ = try writeHistory("export.csv", modifiedAt: reference.addingTimeInterval(30))
        let (folderStore, tracklistStore, activityStore) = stores()

        let first = HistoryAutoIngest().sweep(
            historyAppIDs: ["djay"],
            historyAccesses: [historyAccess()],
            folderAccessStore: folderStore,
            importedTracklistStore: tracklistStore,
            activityLogStore: activityStore,
            references: [.init(date: reference)],
            existing: [],
            windowSeconds: 300
        )
        XCTAssertEqual(first.ingested.count, 1)

        // Second sweep sees the already-stored copy and skips it.
        let second = HistoryAutoIngest().sweep(
            historyAppIDs: ["djay"],
            historyAccesses: [historyAccess()],
            folderAccessStore: folderStore,
            importedTracklistStore: tracklistStore,
            activityLogStore: activityStore,
            references: [.init(date: reference)],
            existing: try tracklistStore.all(),
            windowSeconds: 300
        )
        XCTAssertTrue(second.isEmpty)
        XCTAssertEqual(try tracklistStore.all().count, 1)
    }

    func testReingestsWhenFileGrows() throws {
        let reference = Date(timeIntervalSince1970: 1_700_000_000)
        let file = try writeHistory("export.csv", modifiedAt: reference.addingTimeInterval(30))
        let (folderStore, tracklistStore, activityStore) = stores()

        _ = HistoryAutoIngest().sweep(
            historyAppIDs: ["djay"],
            historyAccesses: [historyAccess()],
            folderAccessStore: folderStore,
            importedTracklistStore: tracklistStore,
            activityLogStore: activityStore,
            references: [.init(date: reference)],
            existing: [],
            windowSeconds: 300
        )
        let existing = try tracklistStore.all()

        // History appended mid-set: file mod-date advances past the stored import.
        try FileManager.default.setAttributes(
            [.modificationDate: reference.addingTimeInterval(120)],
            ofItemAtPath: file.path
        )
        let second = HistoryAutoIngest().sweep(
            historyAppIDs: ["djay"],
            historyAccesses: [historyAccess()],
            folderAccessStore: folderStore,
            importedTracklistStore: tracklistStore,
            activityLogStore: activityStore,
            references: [.init(date: reference)],
            existing: existing,
            windowSeconds: 300
        )
        XCTAssertEqual(second.ingested.count, 1)
        // Replaced in place, not duplicated.
        XCTAssertEqual(try tracklistStore.all().count, 1)
    }

    func testNoReferencesIngestsNothing() throws {
        _ = try writeHistory("export.csv", modifiedAt: Date())
        let (folderStore, tracklistStore, activityStore) = stores()

        let result = HistoryAutoIngest().sweep(
            historyAppIDs: ["djay"],
            historyAccesses: [historyAccess()],
            folderAccessStore: folderStore,
            importedTracklistStore: tracklistStore,
            activityLogStore: activityStore,
            references: [],
            existing: [],
            windowSeconds: 300
        )
        XCTAssertTrue(result.isEmpty)
    }
}

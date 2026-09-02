import XCTest
@testable import SetCatcherCore

final class TracklistAutopullTests: XCTestCase {
    private var tempRoot: URL!

    override func setUp() {
        super.setUp()
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("setcatcher-autopull-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempRoot)
        tempRoot = nil
        super.tearDown()
    }

    func testEmptyHistoryAppIDsReturnsNotFound() throws {
        let session = RecordingSession(
            sourceAppID: "serato",
            sourceURL: tempRoot.appendingPathComponent("set.wav")
        )
        let folderStore = FolderAccessStore(storageURL: tempRoot.appendingPathComponent("folder-access.json"))
        let tracklistStore = ImportedTracklistStore(storageURL: tempRoot.appendingPathComponent("tracklists.json"))
        let activityStore = ActivityLogStore(storageURL: tempRoot.appendingPathComponent("activity.json"))
        let contextStore = SetContextStore(storageURL: tempRoot.appendingPathComponent("contexts.json"))

        let result = try TracklistAutopull().attempt(
            session: session,
            historyAppIDs: [],
            historyAccesses: [],
            folderAccessStore: folderStore,
            importedTracklistStore: tracklistStore,
            activityLogStore: activityStore,
            setContextStore: contextStore,
            archives: [],
            importedTracklists: [],
            setContexts: []
        )

        XCTAssertEqual(result, .notFound)
    }

    func testHistoryAppIDsReturnsSourceForDJApp() {
        let ids = TracklistAutopull.historyAppIDs(
            sourceAppID: "serato",
            selectedTargetAppID: "rekordbox",
            historyAccesses: []
        )
        XCTAssertEqual(ids, ["serato"])
    }

    func testHistoryAppIDsUsesCompanionAppIDForAppAudioCapture() {
        let ids = TracklistAutopull.historyAppIDs(
            sourceAppID: SupportedDJSoftware.captureAppID,
            companionAppID: "serato",
            selectedTargetAppID: "rekordbox",
            historyAccesses: []
        )
        XCTAssertEqual(ids, ["serato"])
    }

    func testHistoryAppIDsUsesSelectedTargetForHardwareCapture() {
        let ids = TracklistAutopull.historyAppIDs(
            sourceAppID: SupportedDJSoftware.captureAppID,
            selectedTargetAppID: "traktor",
            historyAccesses: []
        )
        XCTAssertEqual(ids, ["traktor"])
    }

    func testHistoryAppIDsFallsBackToDefaultsAndBookmarksForHardware() {
        let bookmarkAccess = FolderAccess(
            appID: "djay",
            kind: .history,
            url: tempRoot.appendingPathComponent("djay-history", isDirectory: true),
            bookmarkData: nil
        )
        let ids = TracklistAutopull.historyAppIDs(
            sourceAppID: SupportedDJSoftware.pioneerHardwareAppID,
            selectedTargetAppID: nil,
            historyAccesses: [bookmarkAccess]
        )
        XCTAssertTrue(ids.contains("serato"))
        XCTAssertTrue(ids.contains("virtualdj"))
        XCTAssertTrue(ids.contains("traktor"))
        XCTAssertTrue(ids.contains("djay"))
        XCTAssertFalse(ids.contains(SupportedDJSoftware.captureAppID))
    }

    func testAttemptHonorsCustomHistoryMatchWindow() throws {
        let historyDir = tempRoot.appendingPathComponent("djay-history", isDirectory: true)
        try FileManager.default.createDirectory(at: historyDir, withIntermediateDirectories: true)
        let historyFile = historyDir.appendingPathComponent("export.csv")
        let csv = """
        artist,title,start time
        Inner City,Good Life,00:00
        Robin S,Show Me Love,04:12
        """
        try Data(csv.utf8).write(to: historyFile)

        let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)
        let window: TimeInterval = 5
        let session = RecordingSession(
            sourceAppID: "djay",
            detectedAt: referenceDate,
            completedAt: referenceDate,
            sourceURL: tempRoot.appendingPathComponent("set.wav")
        )
        let historyAccess = FolderAccess(
            appID: "djay",
            kind: .history,
            url: historyDir,
            bookmarkData: nil
        )
        let folderStore = FolderAccessStore(storageURL: tempRoot.appendingPathComponent("folder-access.json"))
        let tracklistStore = ImportedTracklistStore(storageURL: tempRoot.appendingPathComponent("tracklists.json"))
        let activityStore = ActivityLogStore(storageURL: tempRoot.appendingPathComponent("activity.json"))
        let contextStore = SetContextStore(storageURL: tempRoot.appendingPathComponent("contexts.json"))

        try FileManager.default.setAttributes(
            [.modificationDate: referenceDate.addingTimeInterval(2)],
            ofItemAtPath: historyFile.path
        )
        let inside = try TracklistAutopull().attempt(
            session: session,
            historyAppIDs: ["djay"],
            historyAccesses: [historyAccess],
            folderAccessStore: folderStore,
            importedTracklistStore: tracklistStore,
            activityLogStore: activityStore,
            setContextStore: contextStore,
            archives: [],
            importedTracklists: [],
            setContexts: [],
            historyMatchWindowSeconds: window
        )
        guard case .attached = inside else {
            XCTFail("expected .attached inside the window, got \(inside)")
            return
        }

        try FileManager.default.setAttributes(
            [.modificationDate: referenceDate.addingTimeInterval(6)],
            ofItemAtPath: historyFile.path
        )
        let outside = try TracklistAutopull().attempt(
            session: session,
            historyAppIDs: ["djay"],
            historyAccesses: [historyAccess],
            folderAccessStore: folderStore,
            importedTracklistStore: tracklistStore,
            activityLogStore: activityStore,
            setContextStore: contextStore,
            archives: [],
            importedTracklists: [],
            setContexts: [],
            historyMatchWindowSeconds: window
        )
        XCTAssertEqual(outside, .notFound)
    }
}

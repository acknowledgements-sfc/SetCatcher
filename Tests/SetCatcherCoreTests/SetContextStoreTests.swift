import XCTest
@testable import SetCatcherCore

final class SetContextStoreTests: XCTestCase {
    func testSaveAndLoadSetContext() throws {
        let storageURL = temporaryStorageURL()
        let store = SetContextStore(storageURL: storageURL)
        let sessionID = UUID()
        let tracklistID = UUID()

        try store.save(SetContext(
            sessionID: sessionID,
            eventName: "Warehouse Set",
            venue: "Room 2",
            city: "San Francisco",
            tags: "house,late",
            notes: "Great crowd",
            manualTracklistID: tracklistID,
            updatedAt: Date(timeIntervalSince1970: 100)
        ))

        let loaded = try store.context(for: sessionID)

        XCTAssertEqual(loaded.eventName, "Warehouse Set")
        XCTAssertEqual(loaded.venue, "Room 2")
        XCTAssertEqual(loaded.city, "San Francisco")
        XCTAssertEqual(loaded.tags, "house,late")
        XCTAssertEqual(loaded.notes, "Great crowd")
        XCTAssertEqual(loaded.manualTracklistID, tracklistID)
    }

    func testContextForUnknownSessionReturnsEmptyContext() throws {
        let store = SetContextStore(storageURL: temporaryStorageURL())
        let sessionID = UUID()

        let context = try store.context(for: sessionID)

        XCTAssertEqual(context.sessionID, sessionID)
        XCTAssertEqual(context.eventName, "")
        XCTAssertNil(context.manualTracklistID)
    }

    private func temporaryStorageURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("set-contexts.json")
    }
}

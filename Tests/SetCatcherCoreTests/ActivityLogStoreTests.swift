import XCTest
@testable import SetCatcherCore

final class ActivityLogStoreTests: XCTestCase {
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

    func testAppendStoresNewestFirst() throws {
        let store = ActivityLogStore(storageURL: tempRoot.appendingPathComponent("activity.json"))

        try store.append(ActivityEvent(kind: .scan, message: "Older", createdAt: Date(timeIntervalSince1970: 1)))
        try store.append(ActivityEvent(kind: .scan, message: "Newer", createdAt: Date(timeIntervalSince1970: 2)))

        let events = try store.all()
        XCTAssertEqual(events.map(\.message), ["Newer", "Older"])
    }

    func testAppendHonorsLimit() throws {
        let store = ActivityLogStore(storageURL: tempRoot.appendingPathComponent("activity.json"), limit: 1)

        try store.append(ActivityEvent(kind: .scan, message: "Older", createdAt: Date(timeIntervalSince1970: 1)))
        try store.append(ActivityEvent(kind: .scan, message: "Newer", createdAt: Date(timeIntervalSince1970: 2)))

        XCTAssertEqual(try store.all().map(\.message), ["Newer"])
    }
}

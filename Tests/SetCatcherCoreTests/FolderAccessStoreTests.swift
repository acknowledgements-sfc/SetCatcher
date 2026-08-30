import XCTest
@testable import SetCatcherCore

final class FolderAccessStoreTests: XCTestCase {
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

    func testSaveReplacesFolderForSameAppAndKind() throws {
        let store = FolderAccessStore(storageURL: tempRoot.appendingPathComponent("folder-access.json"))
        let first = FolderAccess(appID: "rekordbox", kind: .recordings, url: URL(fileURLWithPath: "/tmp/one"), bookmarkData: nil)
        let second = FolderAccess(appID: "rekordbox", kind: .recordings, url: URL(fileURLWithPath: "/tmp/two"), bookmarkData: nil)

        try store.save(first)
        try store.save(second)

        let records = try store.all()
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.url.path, "/tmp/two")
    }

    func testRemoveDeletesFolderForAppAndKind() throws {
        let store = FolderAccessStore(storageURL: tempRoot.appendingPathComponent("folder-access.json"))
        let access = FolderAccess(appID: "serato", kind: .recordings, url: URL(fileURLWithPath: "/tmp/serato"), bookmarkData: nil)

        try store.save(access)
        try store.remove(appID: "serato", kind: .recordings)

        XCTAssertTrue(try store.all().isEmpty)
    }

    func testIsReachableWhenDirectoryExists() throws {
        let store = FolderAccessStore(storageURL: tempRoot.appendingPathComponent("folder-access.json"))
        let folder = tempRoot.appendingPathComponent("recordings", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let access = FolderAccess(appID: "serato", kind: .recordings, url: folder, bookmarkData: nil)

        XCTAssertTrue(store.isReachable(access))
    }

    func testIsReachableWhenDirectoryMissing() throws {
        let store = FolderAccessStore(storageURL: tempRoot.appendingPathComponent("folder-access.json"))
        let missing = tempRoot.appendingPathComponent("gone", isDirectory: true)
        let access = FolderAccess(appID: "serato", kind: .recordings, url: missing, bookmarkData: nil)

        XCTAssertFalse(store.isReachable(access))
    }

    func testResolutionMarksMissingDirectoryUnreachable() throws {
        let store = FolderAccessStore(storageURL: tempRoot.appendingPathComponent("folder-access.json"))
        let missing = tempRoot.appendingPathComponent("gone", isDirectory: true)
        let access = FolderAccess(appID: "serato", kind: .recordings, url: missing, bookmarkData: nil)

        XCTAssertEqual(store.resolution(for: access), .unreachable(missing))
        XCTAssertFalse(store.resolution(for: access).isUsable)
    }

    func testSecurityScopedBookmarkResolvesExistingDirectory() throws {
        let store = FolderAccessStore(storageURL: tempRoot.appendingPathComponent("folder-access.json"))
        let folder = tempRoot.appendingPathComponent("recordings", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let bookmark = try store.makeBookmarkData(for: folder)
        let access = FolderAccess(appID: "serato", kind: .recordings, url: folder, bookmarkData: bookmark)

        XCTAssertTrue(store.isReachable(access))
        if case .reachable(let url) = store.resolution(for: access) {
            XCTAssertEqual(url.resolvingSymlinksInPath().path, folder.resolvingSymlinksInPath().path)
        } else {
            XCTFail("Expected reachable resolution, got \(store.resolution(for: access))")
        }
    }
}

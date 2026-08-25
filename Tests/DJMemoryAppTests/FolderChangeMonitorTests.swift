import XCTest
import DJMemoryCore
@testable import DJMemoryApp

final class FolderChangeMonitorTests: XCTestCase {
    private var tempRoot: URL!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("DJMemoryAppTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempRoot)
        tempRoot = nil
    }

    func testFolderChangeTriggersCallback() throws {
        let monitor = FolderChangeMonitor()
        let expectation = expectation(description: "folder changed")

        monitor.start(
            requests: [FolderScanRequest(appID: "serato", folderURL: tempRoot)]
        ) {
            expectation.fulfill()
        }

        let sourceURL = tempRoot.appendingPathComponent("set.wav")
        try Data("audio".utf8).write(to: sourceURL)

        wait(for: [expectation], timeout: 3)
        monitor.stop()
    }

    func testDuplicateRequestsOnlyTriggerOneMonitor() throws {
        let monitor = FolderChangeMonitor()
        let expectation = expectation(description: "folder changed once")
        expectation.expectedFulfillmentCount = 1
        expectation.assertForOverFulfill = true

        let request = FolderScanRequest(appID: "serato", folderURL: tempRoot)
        monitor.start(requests: [request, request]) {
            expectation.fulfill()
        }

        let sourceURL = tempRoot.appendingPathComponent("set.wav")
        try Data("audio".utf8).write(to: sourceURL)

        wait(for: [expectation], timeout: 3)
        monitor.stop()
    }

    /// Regression: `start()` used to build a `WatchedFolder` per request — opening a descriptor
    /// and resuming a DispatchSource — *before* comparing against the already-watched set, then
    /// discard them on the unchanged path without cancelling. Repeated calls (one per `refresh()`)
    /// leaked an fd and a live event source each time, and the orphaned sources kept firing.
    func testRepeatedStartWithUnchangedRequestsDoesNotLeakDescriptors() throws {
        let monitor = FolderChangeMonitor()
        let request = FolderScanRequest(appID: "serato", folderURL: tempRoot)

        monitor.start(requests: [request]) {}
        XCTAssertEqual(monitor.activeWatchCount, 1)
        let baseline = Self.openDescriptorCount()

        for _ in 0..<25 {
            monitor.start(requests: [request]) {}
        }

        XCTAssertEqual(monitor.activeWatchCount, 1, "unchanged requests must not add watchers")
        // Allow a little slack for unrelated test-runner I/O; the leak grew by one per call.
        XCTAssertLessThanOrEqual(
            Self.openDescriptorCount() - baseline,
            5,
            "repeated start() with unchanged requests leaked file descriptors"
        )

        monitor.stop()
        XCTAssertEqual(monitor.activeWatchCount, 0)
    }

    func testStartWithChangedRequestsReplacesWatchers() throws {
        let monitor = FolderChangeMonitor()
        let other = tempRoot.appendingPathComponent("second", isDirectory: true)
        try FileManager.default.createDirectory(at: other, withIntermediateDirectories: true)

        monitor.start(requests: [FolderScanRequest(appID: "serato", folderURL: tempRoot)]) {}
        XCTAssertEqual(monitor.activeWatchCount, 1)

        monitor.start(requests: [
            FolderScanRequest(appID: "serato", folderURL: tempRoot),
            FolderScanRequest(appID: "rekordbox", folderURL: other),
        ]) {}
        XCTAssertEqual(monitor.activeWatchCount, 2, "a changed folder set must rebuild watchers")

        monitor.stop()
    }

    /// Number of descriptors open to this process, used to detect watcher leaks.
    private static func openDescriptorCount() -> Int {
        let limit = getdtablesize()
        var count = 0
        for descriptor in 0..<limit where fcntl(descriptor, F_GETFD) != -1 {
            count += 1
        }
        return count
    }
}

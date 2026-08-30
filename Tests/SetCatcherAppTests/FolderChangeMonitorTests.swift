import XCTest
import SetCatcherCore
@testable import SetCatcherApp

final class FolderChangeMonitorTests: XCTestCase {
    private var tempRoot: URL!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("SetCatcherAppTests-\(UUID().uuidString)", isDirectory: true)
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
}

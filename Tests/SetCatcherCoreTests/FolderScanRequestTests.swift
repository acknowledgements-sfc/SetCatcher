import XCTest
@testable import SetCatcherCore

final class FolderScanRequestTests: XCTestCase {
    func testRecordingRequestsIncludeOnlyConfiguredRecordingsFolders() {
        let recordings = FolderAccess(
            appID: "serato",
            kind: .recordings,
            url: URL(fileURLWithPath: "/tmp/serato-rec"),
            bookmarkData: Data([1, 2, 3])
        )
        let history = FolderAccess(
            appID: "serato",
            kind: .history,
            url: URL(fileURLWithPath: "/tmp/serato-hist"),
            bookmarkData: Data([4, 5, 6])
        )
        let rekordbox = FolderAccess(
            appID: "rekordbox",
            kind: .recordings,
            url: URL(fileURLWithPath: "/tmp/rb-rec"),
            bookmarkData: nil
        )

        let requests = FolderScanRequest.recordingRequests(from: [recordings, history, rekordbox]) { $0.url }

        XCTAssertEqual(requests.map(\.appID), ["serato", "rekordbox"])
        XCTAssertEqual(requests.map(\.folderURL.path), ["/tmp/serato-rec", "/tmp/rb-rec"])
        XCTAssertEqual(requests.map(\.bookmarkData), [Data([1, 2, 3]), nil])
    }

    func testRecordingRequestsIgnoreProbeDiscoveredPaths() {
        // Discovered paths are never passed into this builder — empty access list yields no scans.
        let requests = FolderScanRequest.recordingRequests(from: []) { $0.url }
        XCTAssertTrue(requests.isEmpty)
    }
}

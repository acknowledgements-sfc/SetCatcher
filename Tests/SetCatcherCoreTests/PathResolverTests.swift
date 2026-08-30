import XCTest
@testable import SetCatcherCore

final class PathResolverTests: XCTestCase {
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

    func testExpandedURLExpandsTilde() {
        let resolver = PathResolver()
        let url = resolver.expandedURL(for: "~/Music")

        XCTAssertFalse(url.path.contains("~"))
        XCTAssertTrue(url.path.hasSuffix("/Music"))
    }

    func testExistingURLsExpandsWildcardPathComponents() throws {
        let historyURL = tempRoot
            .appendingPathComponent("Native Instruments", isDirectory: true)
            .appendingPathComponent("Traktor 3.11.1", isDirectory: true)
            .appendingPathComponent("History", isDirectory: true)
        let otherURL = tempRoot
            .appendingPathComponent("Native Instruments", isDirectory: true)
            .appendingPathComponent("Maschine", isDirectory: true)
            .appendingPathComponent("History", isDirectory: true)
        try FileManager.default.createDirectory(at: historyURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: otherURL, withIntermediateDirectories: true)

        let resolver = PathResolver()
        let urls = resolver.existingURLs(from: [
            tempRoot
                .appendingPathComponent("Native Instruments", isDirectory: true)
                .appendingPathComponent("Traktor*", isDirectory: true)
                .appendingPathComponent("History", isDirectory: true)
                .path
        ])

        XCTAssertEqual(urls.map(\.lastPathComponent), ["History"])
        XCTAssertEqual(urls.first?.deletingLastPathComponent().lastPathComponent, "Traktor 3.11.1")
    }
}

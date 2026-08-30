import Foundation
import XCTest
@testable import SetCatcherCore

final class ArchiveRootResolverTests: XCTestCase {
    private let envKey = "SETCATCHER_ARCHIVE_ROOT"

    override func tearDown() {
        unsetenv(envKey)
        super.tearDown()
    }

    func testEnvOverrideWinsOverPathAndBookmark() throws {
        let envRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("setcatcher-archive-env-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: envRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: envRoot) }

        let pathRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("setcatcher-archive-path-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: pathRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: pathRoot) }

        setenv(envKey, envRoot.path, 1)
        let settings = AppSettings(
            archiveRootPath: pathRoot.path,
            archiveRootBookmarkData: Data([0x00, 0x01, 0x02, 0x03])
        )

        let resolution = ArchiveRootResolver.resolve(settings: settings)
        XCTAssertEqual(resolution.url.standardizedFileURL, envRoot.standardizedFileURL)
        XCTAssertNil(resolution.bookmarkData)
    }

    func testGarbageBookmarkFallsBackToArchiveRootPathWithoutBookmark() throws {
        unsetenv(envKey)
        let pathRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("setcatcher-archive-fallback-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: pathRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: pathRoot) }

        let settings = AppSettings(
            archiveRootPath: pathRoot.path,
            archiveRootBookmarkData: Data([0x00, 0x01, 0x02, 0x03])
        )

        let resolution = ArchiveRootResolver.resolve(settings: settings)
        XCTAssertEqual(resolution.url.standardizedFileURL, pathRoot.standardizedFileURL)
        XCTAssertNil(resolution.bookmarkData)
    }

    func testEmptySettingsUsesDefaultArchiveRoot() {
        unsetenv(envKey)
        let resolution = ArchiveRootResolver.resolve(settings: .default)
        XCTAssertEqual(
            resolution.url.standardizedFileURL,
            ArchiveService.defaultArchiveRoot().standardizedFileURL
        )
        XCTAssertNil(resolution.bookmarkData)
    }
}

import XCTest
@testable import SetCatcherCore

final class SecurityScopedAccessTests: XCTestCase {
    func testResolveFailsOnGarbageBookmarkData() {
        let garbage = Data([0x00, 0x01, 0x02, 0x03])
        XCTAssertThrowsError(try SecurityScopedAccess.resolve(bookmarkData: garbage)) { error in
            XCTAssertEqual(error as? SecurityScopedAccessError, .resolveFailed)
        }
    }

    func testWithScopedAccessUsesFallbackWhenBookmarkNil() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("setcatcher-scoped-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let path = try SecurityScopedAccess.withScopedAccess(
            bookmarkData: nil,
            fallbackURL: dir
        ) { url in
            url.path
        }
        XCTAssertEqual(path, dir.path)
    }
}

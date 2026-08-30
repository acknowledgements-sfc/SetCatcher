import XCTest
@testable import SetCatcherCore

final class SetCatcherDataMigrationTests: XCTestCase {
    private var homeDirectory: URL!

    override func setUp() {
        super.setUp()
        homeDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("setcatcher-migration-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: homeDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: homeDirectory)
        homeDirectory = nil
        super.tearDown()
    }

    func testMigratesLegacySupportAndArchiveDirectories() throws {
        let migration = SetCatcherDataMigration(homeDirectory: homeDirectory)
        try makeDirectory(migration.legacyApplicationSupportURL)
        try makeDirectory(migration.legacyArchiveURL)
        try Data("settings".utf8).write(to: migration.legacyApplicationSupportURL.appendingPathComponent("settings.json"))
        try Data("recording".utf8).write(to: migration.legacyArchiveURL.appendingPathComponent("set.wav"))

        let result = migration.run()

        XCTAssertEqual(result, .migrated(applicationSupport: true, archive: true))
        XCTAssertTrue(FileManager.default.fileExists(atPath: migration.destinationApplicationSupportURL.appendingPathComponent("settings.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: migration.destinationArchiveURL.appendingPathComponent("set.wav").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: migration.legacyApplicationSupportURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: migration.legacyArchiveURL.path))
    }

    func testMigrationIsIdempotentAfterFirstRun() throws {
        let migration = SetCatcherDataMigration(homeDirectory: homeDirectory)
        try makeDirectory(migration.legacyApplicationSupportURL)

        XCTAssertTrue(migration.run().isSuccessful)
        XCTAssertEqual(migration.run(), .noLegacyData)
    }

    func testDestinationCollisionLeavesLegacyDataUntouched() throws {
        let migration = SetCatcherDataMigration(homeDirectory: homeDirectory)
        try makeDirectory(migration.legacyArchiveURL)
        try makeDirectory(migration.destinationArchiveURL)
        let sourceFile = migration.legacyArchiveURL.appendingPathComponent("old.wav")
        try Data("legacy".utf8).write(to: sourceFile)

        let result = migration.run()

        XCTAssertEqual(result, .destinationExists(migration.destinationArchiveURL))
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceFile.path))
    }

    private func makeDirectory(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}

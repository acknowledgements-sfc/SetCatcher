import XCTest
@testable import SetCatcherCore

final class AppSettingsStoreTests: XCTestCase {
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

    func testLoadReturnsDefaultWhenSettingsFileDoesNotExist() throws {
        let store = AppSettingsStore(storageURL: tempRoot.appendingPathComponent("settings.json"))

        XCTAssertEqual(try store.load(), .default)
    }

    func testSavePersistsSettings() throws {
        let store = AppSettingsStore(storageURL: tempRoot.appendingPathComponent("settings.json"))
        let settings = AppSettings(
            automaticScanningEnabled: false,
            scanIntervalSeconds: 300,
            archiveNamingTemplate: "{date} - {app} - {source}",
            archiveRootPath: "/tmp/SetCatcher Archive",
            archiveRootBookmarkData: Data("bookmark".utf8),
            hasCompletedOnboarding: true
        )

        try store.save(settings)

        XCTAssertEqual(try store.load(), settings)
    }

    func testLoadLegacySettingsDefaultsArchiveNamingTemplate() throws {
        let store = AppSettingsStore(storageURL: tempRoot.appendingPathComponent("settings.json"))
        let json = """
        {
          "automaticScanningEnabled" : true,
          "scanIntervalSeconds" : 60
        }
        """
        try Data(json.utf8).write(to: store.storageURL)

        let settings = try store.load()

        XCTAssertEqual(settings.archiveNamingTemplate, AppSettings.defaultArchiveNamingTemplate)
        XCTAssertNil(settings.archiveRootPath)
        XCTAssertNil(settings.archiveRootBookmarkData)
        XCTAssertFalse(settings.hasCompletedOnboarding)
        XCTAssertTrue(settings.verifyCopies)
        XCTAssertTrue(settings.notifyAfterArchiving)
        XCTAssertFalse(settings.launchAtLogin)
        XCTAssertEqual(settings.captureMode, .appAudio)
        XCTAssertEqual(settings.appAudioIdleSeconds, 60)
        XCTAssertEqual(settings.appAudioMinDurationSeconds, 30)
        XCTAssertEqual(settings.appAudioStartHoldSeconds, 3)
        XCTAssertEqual(settings.appAudioEnergyThreshold, CaptureLevelScale.dispatchStartEnergyThreshold, accuracy: 0.0001)
        XCTAssertTrue(settings.autoArmOnDJAppFound)
        XCTAssertEqual(settings.dualRoutePosture, .both)
        XCTAssertNil(settings.pinnedAnalogInputDeviceID)
        XCTAssertEqual(settings.appPresentationMode, .menuBarAndMainWindow)
        XCTAssertFalse(settings.menuBarOnly)
    }

    func testPinnedAnalogInputDeviceIDRoundTrips() throws {
        let store = AppSettingsStore(storageURL: tempRoot.appendingPathComponent("settings.json"))
        let settings = AppSettings(pinnedAnalogInputDeviceID: "USBAudioDevice:Test:RecOut")
        try store.save(settings)
        XCTAssertEqual(try store.load().pinnedAnalogInputDeviceID, "USBAudioDevice:Test:RecOut")
    }

    func testLegacyMenuBarOnlyMigratesToPresentationMode() throws {
        let store = AppSettingsStore(storageURL: tempRoot.appendingPathComponent("settings.json"))
        let json = """
        {
          "automaticScanningEnabled" : true,
          "menuBarOnly" : true
        }
        """
        try Data(json.utf8).write(to: store.storageURL)
        let settings = try store.load()
        XCTAssertEqual(settings.appPresentationMode, .menuBarOnly)
        XCTAssertTrue(settings.menuBarOnly)
    }

    func testAppPresentationModeRoundTripsAndKeepsLegacyKey() throws {
        let store = AppSettingsStore(storageURL: tempRoot.appendingPathComponent("settings.json"))
        let settings = AppSettings(appPresentationMode: .mainWindowOnly)
        try store.save(settings)
        let loaded = try store.load()
        XCTAssertEqual(loaded.appPresentationMode, .mainWindowOnly)
        XCTAssertFalse(loaded.menuBarOnly)
        let raw = try String(contentsOf: store.storageURL, encoding: .utf8)
        XCTAssertTrue(raw.contains("\"appPresentationMode\""))
        XCTAssertTrue(raw.contains("\"menuBarOnly\""))
        XCTAssertTrue(raw.contains("false"))
    }

    func testLegacyCapturePolicyValuesMigrateToLockedContract() throws {
        let store = AppSettingsStore(storageURL: tempRoot.appendingPathComponent("settings.json"))
        let json = """
        {
          "appAudioIdleSeconds" : 5,
          "appAudioMinDurationSeconds" : 2,
          "appAudioStartHoldSeconds" : 1,
          "appAudioEnergyThreshold" : 0.9
        }
        """
        try Data(json.utf8).write(to: store.storageURL)

        let settings = try store.load()

        XCTAssertEqual(settings.appAudioIdleSeconds, 60)
        XCTAssertEqual(settings.appAudioMinDurationSeconds, 30)
        XCTAssertEqual(settings.appAudioStartHoldSeconds, 3)
        XCTAssertEqual(settings.appAudioEnergyThreshold, CaptureLevelScale.dispatchStartEnergyThreshold, accuracy: 0.0001)
        XCTAssertEqual(settings.silenceSessionConfig.idleEnergyThreshold, CaptureLevelScale.dispatchIdleEnergyThreshold, accuracy: 0.0001)
        XCTAssertEqual(settings.silenceSessionConfig.prerollSeconds, 10)
        XCTAssertEqual(settings.silenceSessionConfig.postRollSeconds, 5)
    }
}

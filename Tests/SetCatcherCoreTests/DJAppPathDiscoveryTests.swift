import XCTest
@testable import SetCatcherCore

final class DJSoftwareVariantCatalogTests: XCTestCase {
    func testSeratoProVariantLabel() {
        let label = DJSoftwareVariantCatalog.variantLabel(
            familyID: "serato",
            bundleIdentifier: "com.serato.seratodj",
            shortVersion: "3.2.1"
        )
        XCTAssertEqual(label, "Serato DJ Pro 3")
    }

    func testSeratoLiteVariantLabel() {
        let label = DJSoftwareVariantCatalog.variantLabel(
            familyID: "serato",
            bundleIdentifier: "com.serato.dj",
            shortVersion: "4.0.0"
        )
        XCTAssertEqual(label, "Serato DJ Lite 4")
    }

    func testRekordboxMajorFromVersion() {
        let label = DJSoftwareVariantCatalog.variantLabel(
            familyID: "rekordbox",
            bundleIdentifier: "com.pioneerdj.rekordboxdj",
            shortVersion: "7.0.5"
        )
        XCTAssertEqual(label, "rekordbox 7")
    }

    func testDjayPro2BundleMapping() {
        let label = DJSoftwareVariantCatalog.variantLabel(
            familyID: "djay",
            bundleIdentifier: "com.algoriddim.direct.djay-pro-2-mac",
            shortVersion: "5.1"
        )
        XCTAssertEqual(label, "djay Pro 2")
    }

    func testTraktorFloorExcludesOldProBuilds() {
        XCTAssertFalse(
            DJSoftwareVariantCatalog.isSupportedTraktorInstallation(
                bundleIdentifier: "com.native-instruments.Traktor",
                shortVersion: "3.7.1"
            )
        )
        XCTAssertTrue(
            DJSoftwareVariantCatalog.isSupportedTraktorInstallation(
                bundleIdentifier: "com.native-instruments.Traktor",
                shortVersion: "3.11.1"
            )
        )
        XCTAssertTrue(
            DJSoftwareVariantCatalog.isSupportedTraktorInstallation(
                bundleIdentifier: "com.native-instruments.tmnt",
                shortVersion: nil
            )
        )
    }
}

final class DJAppPathDiscoveryTests: XCTestCase {
    private var tempRoot: URL!
    private var fileManager: FileManager!

    override func setUpWithError() throws {
        fileManager = FileManager()
        tempRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? fileManager.removeItem(at: tempRoot)
    }

    func testSeratoReaderUsesRecordLocationPreference() throws {
        let home = try XCTUnwrap(tempRoot)
        let preferencesDir = home.appendingPathComponent("Library/Preferences", isDirectory: true)
        try fileManager.createDirectory(at: preferencesDir, withIntermediateDirectories: true)

        let recordingDir = home.appendingPathComponent("Music/_Serato_/Recording", isDirectory: true)
        try fileManager.createDirectory(at: recordingDir, withIntermediateDirectories: true)

        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>record_location</key>
            <string>\(recordingDir.path)</string>
        </dict>
        </plist>
        """
        try plist.write(
            to: preferencesDir.appendingPathComponent("com.serato.seratodj.plist"),
            atomically: true,
            encoding: .utf8
        )

        let software = try XCTUnwrap(SupportedDJSoftware.all.first { $0.id == "serato" })
        let installation = DJSoftwareInstallation(
            familyID: "serato",
            variantLabel: "Serato DJ Pro 3",
            bundleIdentifier: "com.serato.seratodj",
            bundleVersion: "3.2.1",
            appURL: URL(fileURLWithPath: "/Applications/Serato DJ Pro.app"),
            isRunning: false,
            discoveredPaths: []
        )

        let paths = SeratoPathReader().readPaths(
            installation: installation,
            software: software,
            homeDirectory: home,
            fileManager: fileManager
        )

        let recordings = paths.filter { $0.kind == DJPathKind.recordings }
        XCTAssertEqual(recordings.first?.source, DJPathSource.userPreference)
        XCTAssertEqual(recordings.first?.url.standardizedFileURL.path, recordingDir.standardizedFileURL.path)
    }

    func testVirtualDJReaderParsesSettingsXML() throws {
        let home = try XCTUnwrap(tempRoot)
        let root = home.appendingPathComponent("Documents/VirtualDJ", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        let recordDir = root.appendingPathComponent("Recordings", isDirectory: true)
        try fileManager.createDirectory(at: recordDir, withIntermediateDirectories: true)
        let settings = """
        <?xml version="1.0" encoding="UTF-8"?>
        <settings>
            <recordFolder>\(recordDir.path)</recordFolder>
        </settings>
        """
        try settings.write(to: root.appendingPathComponent("settings.xml"), atomically: true, encoding: .utf8)

        let software = try XCTUnwrap(SupportedDJSoftware.all.first { $0.id == "virtualdj" })
        let installation = DJSoftwareInstallation(
            familyID: "virtualdj",
            variantLabel: "VirtualDJ 2025",
            bundleIdentifier: "com.atomixproductions.virtualdj",
            bundleVersion: "2025",
            appURL: URL(fileURLWithPath: "/Applications/VirtualDJ.app"),
            isRunning: false,
            discoveredPaths: []
        )

        let paths = VirtualDJPathReader().readPaths(
            installation: installation,
            software: software,
            homeDirectory: home,
            fileManager: fileManager
        )

        XCTAssertTrue(paths.contains(where: { $0.kind == DJPathKind.recordings && $0.source == DJPathSource.userPreference }))
    }

    func testMergePrefersUserPreferenceOverCatalogDefault() throws {
        let preferred = DiscoveredDJPath(
            kind: .recordings,
            url: tempRoot.appendingPathComponent("preferred", isDirectory: true),
            source: .userPreference
        )
        let fallback = DiscoveredDJPath(
            kind: .recordings,
            url: tempRoot.appendingPathComponent("preferred", isDirectory: true),
            source: .catalogDefault
        )
        try fileManager.createDirectory(at: preferred.url, withIntermediateDirectories: true)

        let merged = DJPathDiscovery.merge(rawPaths: [fallback, preferred], fileManager: fileManager)
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged.first?.source, .userPreference)
    }

    func testProbeResultComputesLegacyRecordingURLsFromInstallations() throws {
        let software = try XCTUnwrap(SupportedDJSoftware.all.first { $0.id == "serato" })
        let recordingURL = tempRoot.appendingPathComponent("Recording", isDirectory: true)
        try fileManager.createDirectory(at: recordingURL, withIntermediateDirectories: true)

        let result = SoftwareProbeResult(
            software: software,
            installations: [
                DJSoftwareInstallation(
                    familyID: "serato",
                    variantLabel: "Serato DJ Pro 3",
                    bundleIdentifier: "com.serato.seratodj",
                    bundleVersion: "3.2.1",
                    appURL: URL(fileURLWithPath: "/Applications/Serato DJ Pro.app"),
                    isRunning: true,
                    discoveredPaths: [
                        DiscoveredDJPath(kind: .recordings, url: recordingURL, source: .userPreference)
                    ]
                )
            ]
        )

        XCTAssertEqual(result.existingRecordingURLs.map(\.path), [recordingURL.path])
        XCTAssertTrue(result.isInstalled)
        XCTAssertTrue(result.isRunning)
    }

    func testCatalogDefaultTildeExpandsAgainstInjectedHome() throws {
        let home = try XCTUnwrap(tempRoot)
        let recordings = home.appendingPathComponent("Music/Engine DJ/Recordings", isDirectory: true)
        try fileManager.createDirectory(at: recordings, withIntermediateDirectories: true)

        let software = try XCTUnwrap(SupportedDJSoftware.all.first { $0.id == "denon-engine" })
        let paths = CatalogDefaultPathReader().readPaths(
            installation: DJSoftwareInstallation(
                familyID: "denon-engine",
                variantLabel: "Engine DJ",
                bundleIdentifier: "com.denondj.engine",
                bundleVersion: nil,
                appURL: URL(fileURLWithPath: "/Applications/Engine DJ.app"),
                isRunning: false,
                discoveredPaths: []
            ),
            software: software,
            homeDirectory: home,
            fileManager: fileManager
        )

        XCTAssertTrue(
            paths.contains(where: {
                $0.kind == .recordings
                    && $0.source == .catalogDefault
                    && $0.url.standardizedFileURL.path == recordings.standardizedFileURL.path
            })
        )
    }

    func testTraktorHistoryWildcardResolvesUnderInjectedHome() throws {
        let home = try XCTUnwrap(tempRoot)
        let history = home.appendingPathComponent(
            "Documents/Native Instruments/Traktor 3.11.1/History",
            isDirectory: true
        )
        try fileManager.createDirectory(at: history, withIntermediateDirectories: true)

        let software = try XCTUnwrap(SupportedDJSoftware.all.first { $0.id == "traktor" })
        let paths = TraktorPathReader().readPaths(
            installation: DJSoftwareInstallation(
                familyID: "traktor",
                variantLabel: "Traktor Pro 3.11.1",
                bundleIdentifier: "com.native-instruments.Traktor",
                bundleVersion: "3.11.1",
                appURL: URL(fileURLWithPath: "/Applications/Traktor.app"),
                isRunning: false,
                discoveredPaths: []
            ),
            software: software,
            homeDirectory: home,
            fileManager: fileManager
        )

        XCTAssertTrue(
            paths.contains(where: {
                $0.kind == .history
                    && $0.source == .catalogDefault
                    && $0.url.standardizedFileURL.path == history.standardizedFileURL.path
            })
        )
    }
}

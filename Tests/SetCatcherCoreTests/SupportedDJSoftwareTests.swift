import XCTest
@testable import SetCatcherCore

final class SupportedDJSoftwareTests: XCTestCase {
    func testSupportedSoftwareContainsExpectedAdapters() {
        let ids = Set(SupportedDJSoftware.all.map(\.id))

        XCTAssertEqual(ids, [
            "serato",
            "rekordbox",
            "djay",
            "virtualdj",
            "traktor",
            "setcatcher-capture",
            "pioneer-hardware"
        ])
    }

    func testEveryAdapterHasDisplayNameAndNotes() {
        for software in SupportedDJSoftware.all {
            XCTAssertFalse(software.displayName.isEmpty)
            XCTAssertFalse(software.notes.isEmpty)
        }
    }

    func testCaptureAdapterUsesSetCatcherDisplayName() throws {
        let capture = try XCTUnwrap(SupportedDJSoftware.all.first { $0.id == "setcatcher-capture" })
        XCTAssertEqual(capture.displayName, "SetCatcher Capture")
    }

    func testAdaptersExposeHonestSupportStatus() {
        let statuses = Dictionary(uniqueKeysWithValues: SupportedDJSoftware.all.map { ($0.id, $0.supportStatus) })

        XCTAssertEqual(statuses["serato"], .supported)
        XCTAssertEqual(statuses["rekordbox"], .supported)
        XCTAssertEqual(statuses["traktor"], .supported)
        XCTAssertEqual(statuses["virtualdj"], .partial)
        XCTAssertEqual(statuses["djay"], .manualSetup)
        XCTAssertEqual(statuses["setcatcher-capture"], .manualSetup)
        XCTAssertEqual(statuses["pioneer-hardware"], .manualSetup)
    }

    func testDjayIncludesDocumentedRecordingDefaults() throws {
        let djay = try XCTUnwrap(SupportedDJSoftware.all.first { $0.id == "djay" })

        XCTAssertEqual(djay.defaultRecordingPaths, ["~/Music/djay/Recordings", "~/Music/djay Pro 2/Recordings"])
        XCTAssertTrue(djay.defaultHistoryPaths.isEmpty)
    }

    func testAdaptersIncludeLiveBundleIdentifiers() throws {
        let byID = Dictionary(uniqueKeysWithValues: SupportedDJSoftware.all.map { ($0.id, $0.bundleIdentifiers) })

        XCTAssertTrue(try XCTUnwrap(byID["serato"]).contains("com.serato.seratodj"))
        XCTAssertTrue(try XCTUnwrap(byID["rekordbox"]).contains("com.pioneerdj.rekordboxdj"))
        XCTAssertTrue(try XCTUnwrap(byID["djay"]).contains("com.algoriddim.djay-iphone-free"))
        XCTAssertTrue(try XCTUnwrap(byID["djay"]).contains("com.algoriddim.direct.djay-pro-2-mac"))
        XCTAssertTrue(try XCTUnwrap(byID["virtualdj"]).contains("com.atomixproductions.virtualdj"))
        XCTAssertTrue(try XCTUnwrap(byID["traktor"]).contains("com.native-instruments.Traktor"))
        XCTAssertTrue(try XCTUnwrap(byID["traktor"]).contains("com.native-instruments.tmnt"))
        XCTAssertTrue(try XCTUnwrap(byID["setcatcher-capture"]).isEmpty)
        XCTAssertTrue(try XCTUnwrap(byID["pioneer-hardware"]).isEmpty)
    }

    func testOnlySeratoDeclaresVirtualAudioDeviceHints() {
        let byID = Dictionary(uniqueKeysWithValues: SupportedDJSoftware.all.map { ($0.id, $0.virtualAudioDeviceNameHints) })
        XCTAssertEqual(byID["serato"], ["Serato Virtual Audio"])
        for id in ["rekordbox", "djay", "virtualdj", "traktor", "setcatcher-capture", "pioneer-hardware"] {
            XCTAssertEqual(byID[id], [], "\(id) must not declare an unverified virtual-audio hint")
        }
    }

    func testDJSoftwareDecodesWithoutVirtualAudioHints() throws {
        let json = """
        {
          "id": "serato",
          "displayName": "Serato DJ Pro",
          "bundleIdentifiers": ["com.serato.dj"],
          "defaultRecordingPaths": [],
          "defaultHistoryPaths": [],
          "integrationDepth": "exportImport",
          "supportStatus": "supported",
          "notes": "legacy"
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(DJSoftware.self, from: json)
        XCTAssertEqual(decoded.virtualAudioDeviceNameHints, [])
    }

    func testProbeResultReportsRunningStatusFirst() throws {
        let software = try XCTUnwrap(SupportedDJSoftware.all.first { $0.id == "serato" })
        let result = SoftwareProbeResult(
            software: software,
            installedApplicationURLs: [],
            runningApplicationBundleIdentifiers: ["com.serato.seratodj"],
            existingRecordingURLs: [],
            existingHistoryURLs: []
        )

        XCTAssertTrue(result.isRunning)
        XCTAssertEqual(result.status, "running")
    }
}

import XCTest
@testable import SetCatcherCore

final class ActivityEventKindTests: XCTestCase {
    func testDiagnosticsRoundTrips() throws {
        let event = ActivityEvent(kind: .diagnostics, message: "Exported diagnostics", detail: "/tmp/report.json")
        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(ActivityEvent.self, from: data)
        XCTAssertEqual(decoded.kind, .diagnostics)
    }

    func testUnknownKindFallsBackToScan() throws {
        let json = """
        {
          "id" : "00000000-0000-0000-0000-000000000001",
          "kind" : "futureThing",
          "message" : "legacy",
          "detail" : null,
          "createdAt" : 0
        }
        """
        let decoded = try JSONDecoder().decode(ActivityEvent.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.kind, .scan)
    }

    func testLegacyKindsStillDecode() throws {
        for raw in ["archive", "importTracklist", "scan", "error"] {
            let json = """
            {
              "id" : "00000000-0000-0000-0000-000000000001",
              "kind" : "\(raw)",
              "message" : "ok",
              "createdAt" : 0
            }
            """
            let decoded = try JSONDecoder().decode(ActivityEvent.self, from: Data(json.utf8))
            XCTAssertEqual(decoded.kind.rawValue, raw)
        }
    }
}

final class ProtectionStateTests: XCTestCase {
    func testDerivePriority() {
        XCTAssertEqual(
            ProtectionState.derive(isScanning: true, hasUnreachableFolder: true, hasConfiguredRecordingsFolder: true),
            .scanning
        )
        XCTAssertEqual(
            ProtectionState.derive(isScanning: false, hasUnreachableFolder: true, hasConfiguredRecordingsFolder: true),
            .attentionNeeded
        )
        XCTAssertEqual(
            ProtectionState.derive(isScanning: false, hasUnreachableFolder: false, hasConfiguredRecordingsFolder: false),
            .needsSetup
        )
        XCTAssertEqual(
            ProtectionState.derive(isScanning: false, hasUnreachableFolder: false, hasConfiguredRecordingsFolder: true),
            .protected
        )
    }
}

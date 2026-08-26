import XCTest
@testable import DJMemoryCore

final class AppAudioCaptureLifecyclePolicyTests: XCTestCase {
    func testVirtualFallbackRequiresExplicitEnableAndMicPermission() {
        let envEnabled = ["DJMEMORY_ENABLE_VIRTUAL_APP_AUDIO": "1"]
        XCTAssertTrue(AppAudioCaptureBackendSelector.virtualAppAudioEnabled(environment: envEnabled))
        XCTAssertFalse(AppAudioCaptureBackendSelector.virtualAppAudioEnabled(environment: [:]))

        // Vendor fallback selection still requires catalog device presence.
        let device = AudioInputDevice(
            id: "sva",
            name: "Serato Virtual Audio",
            manufacturer: "Serato",
            transportType: .virtual
        )
        let software = SupportedDJSoftware.all.first { $0.id == "serato" }!
        let selection = AppAudioCaptureBackendSelector.vendorFallbackSelection(
            targetSoftware: software,
            inputDevices: [device],
            runningSoftwareIDs: ["serato"],
            virtualEnabled: true
        )
        if case .virtualInputDevice(let bound, let softwareID) = selection {
            XCTAssertEqual(bound.id, "sva")
            XCTAssertEqual(softwareID, "serato")
        } else {
            XCTFail("expected vendor fallback")
        }
    }

    func testProbePassGateRequiresLibraryReconciliation() {
        let almost = InvisibleCaptureProbePassInput(
            peakLevel: 0.5,
            rmsLevel: 0.2,
            framesWritten: 48_000,
            stagingBytes: 128_000,
            wavValid: true,
            archivePath: "/tmp/x.wav",
            libraryReconciled: false
        )
        XCTAssertFalse(InvisibleCaptureProbeEvaluator.passes(almost))
    }
}

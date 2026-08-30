import XCTest
@testable import SetCatcherCore

final class AppAudioCaptureBackendSelectorTests: XCTestCase {
    func testPrefersProcessAudioTapWhenSupported() {
        XCTAssertEqual(
            AppAudioCaptureBackendSelector.preferredBackend(processTapSupported: true, forceScreenCaptureKit: false),
            .processAudioTap
        )
    }

    func testFallsBackToScreenCaptureKitWhenProcessTapUnsupported() {
        XCTAssertEqual(
            AppAudioCaptureBackendSelector.preferredBackend(processTapSupported: false, forceScreenCaptureKit: false),
            .screenCaptureKit
        )
    }

    func testCanForceScreenCaptureKitForFallbackVerification() {
        XCTAssertEqual(
            AppAudioCaptureBackendSelector.preferredBackend(processTapSupported: true, forceScreenCaptureKit: true),
            .screenCaptureKit
        )
    }

    // `virtualEnabled` is explicit below so selection logic remains deterministic regardless
    // of the process environment used to launch the test suite.

    func testVirtualBackendIsDisabledByDefault() {
        XCTAssertFalse(AppAudioCaptureBackendSelector.virtualAppAudioEnabled(environment: [:]))
        XCTAssertTrue(
            AppAudioCaptureBackendSelector.virtualAppAudioEnabled(
                environment: ["SETCATCHER_ENABLE_VIRTUAL_APP_AUDIO": "1"]
            )
        )
    }

    func testNonOptInEnvironmentValuesKeepVirtualBackendDisabled() {
        XCTAssertFalse(
            AppAudioCaptureBackendSelector.virtualAppAudioEnabled(
                environment: ["SETCATCHER_ENABLE_VIRTUAL_APP_AUDIO": "0"]
            )
        )
    }

    func testVendorFallbackSelectionUsesSeratoVirtualDeviceWhenEnabled() {
        let selection = AppAudioCaptureBackendSelector.vendorFallbackSelection(
            targetSoftware: Self.serato,
            inputDevices: [Self.seratoVirtualAudio],
            runningSoftwareIDs: ["serato"],
            virtualEnabled: true
        )
        guard case .virtualInputDevice(let device, let softwareID) = selection else {
            return XCTFail("expected virtualInputDevice, got \(String(describing: selection))")
        }
        XCTAssertEqual(device.id, Self.seratoVirtualAudio.id)
        XCTAssertEqual(softwareID, "serato")
        XCTAssertEqual(selection?.kind, .virtualInputDevice)
    }

    func testPreferredSelectionAlwaysUsesApplePathsFirst() {
        let selection = AppAudioCaptureBackendSelector.preferredSelection(
            targetSoftware: Self.serato,
            inputDevices: [Self.seratoVirtualAudio],
            runningSoftwareIDs: ["serato"],
            processTapSupported: true,
            forceScreenCaptureKit: false,
            virtualEnabled: true
        )
        XCTAssertEqual(selection, .processAudioTap)
    }

    func testExplicitDisableFallsBackToProcessAudioTap() {
        let selection = AppAudioCaptureBackendSelector.preferredSelection(
            targetSoftware: Self.serato,
            inputDevices: [Self.seratoVirtualAudio],
            runningSoftwareIDs: ["serato"],
            processTapSupported: true,
            forceScreenCaptureKit: false,
            virtualEnabled: false
        )
        XCTAssertEqual(selection, .processAudioTap)
    }

    func testFallsBackToProcessTapWhenSeratoHasNoVirtualDevice() {
        let selection = AppAudioCaptureBackendSelector.preferredSelection(
            targetSoftware: Self.serato,
            inputDevices: [],
            runningSoftwareIDs: ["serato"],
            processTapSupported: true,
            forceScreenCaptureKit: false,
            virtualEnabled: true
        )
        XCTAssertEqual(selection, .processAudioTap)
    }

    func testRekordboxDoesNotSelectSeratoVirtualDevice() {
        let selection = AppAudioCaptureBackendSelector.preferredSelection(
            targetSoftware: Self.rekordbox,
            inputDevices: [Self.seratoVirtualAudio],
            runningSoftwareIDs: ["rekordbox", "serato"],
            processTapSupported: true,
            forceScreenCaptureKit: false,
            virtualEnabled: true
        )
        XCTAssertEqual(selection, .processAudioTap)
    }

    func testNoDetectedAppDoesNotSelectVirtualBackend() {
        let selection = AppAudioCaptureBackendSelector.preferredSelection(
            targetSoftware: Self.serato,
            inputDevices: [Self.seratoVirtualAudio],
            runningSoftwareIDs: [],
            processTapSupported: true,
            forceScreenCaptureKit: false,
            virtualEnabled: true
        )
        XCTAssertEqual(selection, .processAudioTap)

        let nilTarget = AppAudioCaptureBackendSelector.preferredSelection(
            targetSoftware: nil,
            inputDevices: [Self.seratoVirtualAudio],
            runningSoftwareIDs: ["serato"],
            processTapSupported: true,
            forceScreenCaptureKit: false,
            virtualEnabled: true
        )
        XCTAssertEqual(nilTarget, .processAudioTap)
    }

    func testVirtualBindFailureFallsBackToProcessTap() {
        XCTAssertEqual(
            AppAudioCaptureBackendSelector.fallbackAfterVirtualBindFailure(
                processTapSupported: true,
                forceScreenCaptureKit: false
            ),
            .processAudioTap
        )
        XCTAssertEqual(
            AppAudioCaptureBackendSelector.fallbackAfterVirtualBindFailure(
                processTapSupported: false,
                forceScreenCaptureKit: false
            ),
            .screenCaptureKit
        )
    }

    private static let seratoVirtualAudio = AudioInputDevice(
        id: "sva",
        name: "Serato Virtual Audio",
        manufacturer: "Serato",
        transportType: .virtual
    )

    private static var serato: DJSoftware {
        SupportedDJSoftware.all.first { $0.id == "serato" }!
    }

    private static var rekordbox: DJSoftware {
        SupportedDJSoftware.all.first { $0.id == "rekordbox" }!
    }
}

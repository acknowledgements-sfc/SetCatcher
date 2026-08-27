import XCTest
@testable import DJMemoryCore

final class AppAudioCaptureLifecyclePolicyTests: XCTestCase {
    func testProcessTapFailureCleansUpRetriesThenFallsBackToScreenCaptureKit() async throws {
        guard ProcessAudioTapCaptureService.isSupported else { return }
        let process = MockAppAudioBackend(kind: .processAudioTap)
        process.startResults = [
            .failure(AppAudioCaptureError.engineFailed("tap stale")),
            .failure(AppAudioCaptureError.engineFailed("tap stale after cleanup"))
        ]
        process.sourceDeviceUIDValue = "process-aggregate"
        let screen = MockAppAudioBackend(kind: .screenCaptureKit)
        screen.shareableApps = [
            MatchedDJApp(
                software: SupportedDJSoftware.all[0],
                matchedBundleIdentifier: SupportedDJSoftware.all[0].bundleIdentifiers[0]
            )
        ]
        let service = AppAudioCaptureService(
            processTapBackend: process,
            screenCaptureBackend: screen,
            virtualBackend: MockVirtualAppAudioBackend()
        )

        try await service.startMonitoring(
            bundleIdentifier: screen.shareableApps[0].matchedBundleIdentifier,
            displayName: screen.shareableApps[0].software.displayName
        )

        XCTAssertEqual(process.startCallCount, 2)
        XCTAssertEqual(process.stopCallCount, 2)
        XCTAssertEqual(screen.listCallCount, 1)
        XCTAssertEqual(screen.startCallCount, 1)
        XCTAssertEqual(service.activeBackendKind, .screenCaptureKit)
        XCTAssertEqual(service.activeSourceDeviceUID, screen.shareableApps[0].matchedBundleIdentifier)
    }

    func testInterruptedCaptureCallbackCarriesFinalizedResult() {
        let process = MockAppAudioBackend(kind: .processAudioTap)
        let screen = MockAppAudioBackend(kind: .screenCaptureKit)
        let expected = CaptureResult(
            stagingURL: URL(fileURLWithPath: "/tmp/interrupted.wav"),
            deviceID: "com.example.dj",
            deviceName: "Example DJ app audio",
            startedAt: Date(timeIntervalSince1970: 10),
            endedAt: Date(timeIntervalSince1970: 20),
            captureRoute: .appAudio,
            captureBackend: .screenCaptureKit,
            captureInterrupted: true,
            captureInterruptionReason: "stream stopped"
        )
        let service = AppAudioCaptureService(
            processTapBackend: process,
            screenCaptureBackend: screen,
            virtualBackend: MockVirtualAppAudioBackend()
        )
        var delivered: CaptureResult?
        var deliveredError: AppAudioCaptureError?
        service.onInterruptedCapture = { result, error in
            delivered = result
            deliveredError = error
        }

        screen.onInterruptedCapture?(expected, .streamStopped("stream stopped"))

        XCTAssertEqual(delivered, expected)
        XCTAssertEqual(deliveredError, .streamStopped("stream stopped"))
    }

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

    func testProbePassGateRequiresSignalFromRecordedWindow() {
        let disconnected = InvisibleCaptureProbePassInput(
            peakLevel: 0.5,
            rmsLevel: 0.2,
            framesWritten: 48_000,
            stagingBytes: 128_000,
            wavValid: true,
            archivePath: "/tmp/x.wav",
            libraryReconciled: true,
            signalMeasuredDuringRecording: false
        )

        XCTAssertFalse(InvisibleCaptureProbeEvaluator.passes(disconnected))
    }
}

private class MockAppAudioBackend: @unchecked Sendable, AppAudioCaptureBackend {
    let backendKind: AppAudioCaptureBackendKind
    var isMonitoring = false
    var isWriting = false
    var sourceDeviceUIDValue: String?
    var sourceDeviceUID: String? { sourceDeviceUIDValue ?? backendKind.rawValue }
    var onStreamStopped: ((AppAudioCaptureError) -> Void)?
    var onInterruptedCapture: ((CaptureResult, AppAudioCaptureError) -> Void)?
    var shareableApps: [MatchedDJApp] = []
    var startResults: [Result<Void, AppAudioCaptureError>] = [.success(())]
    var listCallCount = 0
    var startCallCount = 0
    var stopCallCount = 0

    init(kind: AppAudioCaptureBackendKind) {
        self.backendKind = kind
    }

    func listShareableDJApps() async throws -> [MatchedDJApp] {
        listCallCount += 1
        return shareableApps
    }

    func startMonitoring(
        bundleIdentifier: String,
        displayName: String,
        prerollSeconds: TimeInterval
    ) async throws {
        _ = bundleIdentifier
        _ = displayName
        _ = prerollSeconds
        startCallCount += 1
        let result = startResults.isEmpty ? .success(()) : startResults.removeFirst()
        switch result {
        case .success:
            isMonitoring = true
        case .failure(let error):
            throw error
        }
    }

    func stopMonitoring() async {
        stopCallCount += 1
        isMonitoring = false
        isWriting = false
    }

    func beginRecordingFile() throws {
        isWriting = true
    }

    func endRecordingFile(discard: Bool) throws -> CaptureResult? {
        _ = discard
        guard isWriting else { throw AppAudioCaptureError.notWriting }
        isWriting = false
        return nil
    }

    func currentInputLevel() -> Float {
        0
    }
}

private final class MockVirtualAppAudioBackend: MockAppAudioBackend, @unchecked Sendable, VirtualInputAppAudioCaptureBackend {
    private(set) var boundDevice: AudioInputDevice?

    init() {
        super.init(kind: .virtualInputDevice)
    }

    func bind(device: AudioInputDevice, softwareID: String) {
        _ = softwareID
        boundDevice = device
        sourceDeviceUIDValue = device.id
    }
}

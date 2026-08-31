import AVFoundation
import XCTest
@testable import SetCatcherCore

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

    func testInterruptedCaptureResultIngestsSidecarMetadataEndToEnd() throws {
        let stagingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("setcatcher-interrupt-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: stagingURL) }
        try writeCanonicalWAV(to: stagingURL, amplitude: 0.2, frames: 2_400)

        let reason = "stream stopped"
        let finalized = CaptureResult(
            stagingURL: stagingURL,
            deviceID: "com.serato.seratodj",
            deviceName: "Serato DJ Pro app audio",
            startedAt: Date(timeIntervalSince1970: 1_700_000_100),
            endedAt: Date(timeIntervalSince1970: 1_700_000_160),
            captureRoute: .appAudio,
            captureBackend: .screenCaptureKit,
            captureInterrupted: true,
            captureInterruptionReason: reason
        )

        let process = MockAppAudioBackend(kind: .processAudioTap)
        let screen = MockAppAudioBackend(kind: .screenCaptureKit)
        let service = AppAudioCaptureService(
            processTapBackend: process,
            screenCaptureBackend: screen,
            virtualBackend: MockVirtualAppAudioBackend()
        )
        var delivered: CaptureResult?
        service.onInterruptedCapture = { result, _ in
            delivered = result
        }
        screen.onInterruptedCapture?(finalized, .streamStopped(reason))

        let deliveredResult = try XCTUnwrap(delivered)
        XCTAssertTrue(deliveredResult.captureInterrupted)
        XCTAssertEqual(deliveredResult.captureInterruptionReason, reason)

        let archiveRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("setcatcher-interrupt-archive-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: archiveRoot) }
        let archive = ArchiveService(archiveRoot: archiveRoot)
        let session = try archive.ingestCapture(
            stagingURL: deliveredResult.stagingURL,
            deviceID: deliveredResult.deviceID,
            deviceName: deliveredResult.deviceName,
            startedAt: deliveredResult.startedAt,
            endedAt: deliveredResult.endedAt,
            sourceAppID: "serato",
            captureRoute: deliveredResult.captureRoute ?? .appAudio,
            captureBackend: deliveredResult.captureBackend ?? .screenCaptureKit,
            captureInterrupted: deliveredResult.captureInterrupted,
            captureInterruptionReason: deliveredResult.captureInterruptionReason
        )
        let archiveURL = try XCTUnwrap(session.archiveURL)
        let data = try Data(contentsOf: archive.metadataURL(for: archiveURL))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let metadata = try decoder.decode(ArchiveMetadata.self, from: data)

        XCTAssertTrue(metadata.captureInterrupted)
        XCTAssertEqual(metadata.captureInterruptionReason, reason)
        XCTAssertEqual(metadata.captureBackend, .screenCaptureKit)
    }

    func testPermissionDeniedWithoutVendorOptInDoesNotStartVendor() async {
        let process = MockAppAudioBackend(kind: .processAudioTap)
        process.startResults = [.failure(.permissionDenied)]
        let screen = MockAppAudioBackend(kind: .screenCaptureKit)
        let vendor = MockVirtualAppAudioBackend()
        let service = AppAudioCaptureService(
            processTapBackend: process,
            screenCaptureBackend: screen,
            virtualBackend: vendor,
            microphonePermissionGranted: { true }
        )

        do {
            try await service.startMonitoring(
                bundleIdentifier: "com.serato.seratodj",
                displayName: "Serato DJ Pro",
                softwareID: "serato",
                inputDevices: [seratoVirtualDevice],
                runningSoftwareIDs: ["serato"]
            )
            XCTFail("expected permissionDenied")
        } catch AppAudioCaptureError.permissionDenied {
            XCTAssertEqual(process.startCallCount, 1)
            XCTAssertEqual(vendor.startCallCount, 0)
            XCTAssertFalse(service.appleAppAudioPathExhausted)
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    func testPermissionDeniedWithVendorOptInUsesInjectableMicPermission() async throws {
        setenv("SETCATCHER_ENABLE_VIRTUAL_APP_AUDIO", "1", 1)
        defer { unsetenv("SETCATCHER_ENABLE_VIRTUAL_APP_AUDIO") }

        let process = MockAppAudioBackend(kind: .processAudioTap)
        process.startResults = [.failure(.permissionDenied)]
        let screen = MockAppAudioBackend(kind: .screenCaptureKit)
        let vendor = MockVirtualAppAudioBackend()
        var micCalls = 0
        let service = AppAudioCaptureService(
            processTapBackend: process,
            screenCaptureBackend: screen,
            virtualBackend: vendor,
            microphonePermissionGranted: {
                micCalls += 1
                return true
            }
        )

        try await service.startMonitoring(
            bundleIdentifier: "com.serato.seratodj",
            displayName: "Serato DJ Pro",
            softwareID: "serato",
            inputDevices: [seratoVirtualDevice],
            runningSoftwareIDs: ["serato"]
        )

        XCTAssertEqual(process.startCallCount, 1)
        XCTAssertEqual(vendor.startCallCount, 1)
        XCTAssertGreaterThanOrEqual(micCalls, 1)
        XCTAssertEqual(service.activeBackendKind, .virtualInputDevice)
        XCTAssertEqual(vendor.boundDevice?.id, seratoVirtualDevice.id)
    }

    func testPermissionDeniedWithVendorOptInButMicDeniedSkipsVendor() async {
        setenv("SETCATCHER_ENABLE_VIRTUAL_APP_AUDIO", "1", 1)
        defer { unsetenv("SETCATCHER_ENABLE_VIRTUAL_APP_AUDIO") }

        let process = MockAppAudioBackend(kind: .processAudioTap)
        process.startResults = [.failure(.permissionDenied)]
        let screen = MockAppAudioBackend(kind: .screenCaptureKit)
        let vendor = MockVirtualAppAudioBackend()
        let service = AppAudioCaptureService(
            processTapBackend: process,
            screenCaptureBackend: screen,
            virtualBackend: vendor,
            microphonePermissionGranted: { false }
        )

        do {
            try await service.startMonitoring(
                bundleIdentifier: "com.serato.seratodj",
                displayName: "Serato DJ Pro",
                softwareID: "serato",
                inputDevices: [seratoVirtualDevice],
                runningSoftwareIDs: ["serato"]
            )
            XCTFail("expected permissionDenied")
        } catch AppAudioCaptureError.permissionDenied {
            XCTAssertEqual(vendor.startCallCount, 0)
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    func testVirtualFallbackRequiresExplicitEnableAndMicPermission() {
        let envEnabled = ["SETCATCHER_ENABLE_VIRTUAL_APP_AUDIO": "1"]
        XCTAssertTrue(AppAudioCaptureBackendSelector.virtualAppAudioEnabled(environment: envEnabled))
        XCTAssertFalse(AppAudioCaptureBackendSelector.virtualAppAudioEnabled(environment: [:]))

        let device = seratoVirtualDevice
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
            libraryReconciled: false,
            outputModeLabel: "system-default"
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
            signalMeasuredDuringRecording: false,
            outputModeLabel: "system-default"
        )

        XCTAssertFalse(InvisibleCaptureProbeEvaluator.passes(disconnected))
    }

    func testProbePassGateRejectsUnknownOutputModeLabel() {
        let unknown = InvisibleCaptureProbePassInput(
            peakLevel: 0.5,
            rmsLevel: 0.2,
            framesWritten: 48_000,
            stagingBytes: 128_000,
            wavValid: true,
            archivePath: "/tmp/x.wav",
            libraryReconciled: true,
            outputModeLabel: "UNKNOWN"
        )
        XCTAssertFalse(InvisibleCaptureProbeEvaluator.passes(unknown))
        XCTAssertEqual(InvisibleCaptureProbeEvaluator.outcomeLabel(for: unknown), "unknown_scenario")
    }

    private var seratoVirtualDevice: AudioInputDevice {
        AudioInputDevice(
            id: "sva",
            name: "Serato Virtual Audio",
            manufacturer: "Serato",
            transportType: .virtual
        )
    }

    private func writeCanonicalWAV(to url: URL, amplitude: Float, frames: AVAudioFrameCount) throws {
        let processing = try XCTUnwrap(CaptureAudioFormat.processingFormat())
        let audioFile = try AVAudioFile(forWriting: url, settings: CaptureAudioFormat.writeSettings)
        let writeFormat = audioFile.processingFormat
        let converter = try XCTUnwrap(CaptureAudioFormat.makeConverter(from: processing, to: writeFormat))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: processing, frameCapacity: frames))
        buffer.frameLength = frames
        if let channels = buffer.floatChannelData {
            for channel in 0..<Int(processing.channelCount) {
                for frame in 0..<Int(frames) {
                    channels[channel][frame] = amplitude
                }
            }
        }
        let errorDetail = CapturePCMWriter.convertAndWrite(
            buffer: buffer,
            converter: converter,
            writeFormat: writeFormat,
            audioFile: audioFile
        )
        XCTAssertNil(errorDetail)
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

    func currentStagingByteCount() -> Int64? {
        isWriting ? 1_024 : nil
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

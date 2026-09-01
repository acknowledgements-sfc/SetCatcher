import XCTest
@testable import SetCatcherCore

final class LiveCaptureRouteFactsBuilderTests: XCTestCase {
    private static let djm = AudioInputDevice(
        id: "djm", name: "DJM-V10", manufacturer: "Pioneer DJ", transportType: .usb
    )

    func testPioneerDraftsUseCacheChannelsAndFormat() {
        let drafts = LiveCaptureRouteFactsBuilder.pioneerDrafts(
            from: [Self.djm],
            cache: ["djm": (channels: 2, formatOK: true)]
        )
        XCTAssertEqual(drafts.count, 1)
        XCTAssertEqual(drafts[0].inputChannelCount, 2)
        XCTAssertTrue(drafts[0].formatIsSupported)
        XCTAssertNil(drafts[0].peakLevel)
    }

    func testHardwareFeedSignalRequiresExactMonitoredUID() {
        XCTAssertTrue(
            LiveCaptureRouteFactsBuilder.hardwareFeedIsProducingSignal(
                currentKind: .verifiedHardwareFeed,
                currentDeviceID: "djm",
                monitoredDeviceID: "djm",
                level: 0.5
            )
        )
        XCTAssertFalse(
            LiveCaptureRouteFactsBuilder.hardwareFeedIsProducingSignal(
                currentKind: .verifiedHardwareFeed,
                currentDeviceID: "djm",
                monitoredDeviceID: "other",
                level: 0.5
            )
        )
        XCTAssertFalse(
            LiveCaptureRouteFactsBuilder.hardwareFeedIsProducingSignal(
                currentKind: .verifiedHardwareFeed,
                currentDeviceID: "djm",
                monitoredDeviceID: nil,
                level: 0.5
            )
        )
    }

    func testAppAudioLevelDoesNotVerifyUnmonitoredHardware() {
        var tracker = LiveCaptureDetectionTracker()
        let draft = HardwareInputObservation(
            device: Self.djm,
            inputChannelCount: 2,
            formatIsSupported: true
        )
        let start = Date(timeIntervalSince1970: 3_000)
        let observed = tracker.observe(
            [draft],
            monitoredDeviceID: nil,
            level: 0.8,
            observing: true,
            now: start.addingTimeInterval(3)
        )
        XCTAssertNil(observed[0].peakLevel)
        XCTAssertFalse(LiveCaptureHardwareClassifier.isVerifiedFeed(observed[0]))
    }

    func testBuildIncludesFrozenBackendInSession() {
        let facts = LiveCaptureRouteFactsBuilder.build(
            LiveCaptureRouteFactsBuilder.Input(
                currentKind: .existingAppAudio,
                currentBackend: .existingAppAudio(archiveBackend: .screenCaptureKit),
                recordingAlreadyActive: true
            )
        )
        XCTAssertEqual(facts.session.currentBackend, .existingAppAudio(archiveBackend: .screenCaptureKit))
    }

    func testAppAudioObservationRequiresRunningAppAndPermissionAndMonitoringSignal() {
        let unavailable = LiveCaptureRouteFactsBuilder.appAudioObservation(
            runningDJSoftwareIDs: [],
            isMonitoring: true,
            activeBackend: .processAudioTap,
            sourceDeviceUID: "tap",
            peakLevel: 0.5,
            applePathExhausted: false,
            screenCapturePermissionGranted: true
        )
        XCTAssertEqual(unavailable.capability, .unavailable)

        let denied = LiveCaptureRouteFactsBuilder.appAudioObservation(
            runningDJSoftwareIDs: ["serato"],
            isMonitoring: true,
            activeBackend: .processAudioTap,
            sourceDeviceUID: "tap",
            peakLevel: 0.5,
            applePathExhausted: false,
            screenCapturePermissionGranted: false,
            processTapSupported: true
        )
        XCTAssertEqual(denied.capability, .available)

        let sckOnlyDenied = LiveCaptureRouteFactsBuilder.appAudioCapability(
            runningDJSoftwareIDs: ["serato"],
            screenCapturePermissionGranted: false,
            processTapSupported: false,
            isMonitoring: false
        )
        XCTAssertEqual(sckOnlyDenied, .permissionDenied)

        let producing = LiveCaptureRouteFactsBuilder.appAudioObservation(
            runningDJSoftwareIDs: ["serato"],
            isMonitoring: true,
            activeBackend: .screenCaptureKit,
            sourceDeviceUID: "com.serato.seratodj",
            peakLevel: 0.5,
            applePathExhausted: false,
            screenCapturePermissionGranted: true
        )
        XCTAssertEqual(producing.capability, .available)
        XCTAssertEqual(producing.archiveBackend, .screenCaptureKit)
        XCTAssertTrue(producing.isProducing)
    }
}

#if os(macOS)
final class InvisibleCaptureProbeEvaluatorTests: XCTestCase {
    func testPassRequiresAllGates() {
        let good = InvisibleCaptureProbePassInput(
            peakLevel: 0.5,
            rmsLevel: 0.2,
            framesWritten: 48_000,
            stagingBytes: 192_000,
            wavValid: true,
            archivePath: "/tmp/test.wav",
            libraryReconciled: true,
            outputModeLabel: "system-default"
        )
        XCTAssertTrue(InvisibleCaptureProbeEvaluator.passes(good))
        XCTAssertEqual(InvisibleCaptureProbeEvaluator.outcomeLabel(for: good), "pass_archive_signal")

        let silent = InvisibleCaptureProbePassInput(
            peakLevel: 0.001,
            rmsLevel: good.rmsLevel,
            framesWritten: good.framesWritten,
            stagingBytes: good.stagingBytes,
            wavValid: good.wavValid,
            archivePath: good.archivePath,
            libraryReconciled: good.libraryReconciled,
            outputModeLabel: "system-default"
        )
        XCTAssertFalse(InvisibleCaptureProbeEvaluator.passes(silent))
    }

    func testPassRejectsUnknownScenarioEvenWithAudibleArchivePeak() {
        let unknown = InvisibleCaptureProbePassInput(
            peakLevel: 0.9,
            rmsLevel: 0.4,
            framesWritten: 48_000,
            stagingBytes: 192_000,
            wavValid: true,
            archivePath: "/tmp/test.wav",
            libraryReconciled: true,
            outputModeLabel: "UNKNOWN"
        )
        XCTAssertFalse(InvisibleCaptureProbeEvaluator.passes(unknown))
        XCTAssertEqual(InvisibleCaptureProbeEvaluator.outcomeLabel(for: unknown), "unknown_scenario")
    }

    func testSilentArchivedPeakFailsEvenIfLiveMeterWouldHavePassed() {
        // Live meter is no longer an evaluator input; archived peak of ~0 must fail.
        let archivedSilent = InvisibleCaptureProbePassInput(
            peakLevel: 0,
            rmsLevel: 0.8,
            framesWritten: 48_000,
            stagingBytes: 192_000,
            wavValid: true,
            archivePath: "/tmp/silent.wav",
            libraryReconciled: true,
            signalMeasuredDuringRecording: true,
            outputModeLabel: "system-default"
        )
        XCTAssertFalse(InvisibleCaptureProbeEvaluator.passes(archivedSilent))
    }
}
#endif

import XCTest
@testable import SetCatcherCore

final class SilenceSessionControllerTests: XCTestCase {
    private let config = SilenceSessionConfig(
        startEnergyThreshold: 0.1,
        idleEnergyThreshold: 0.05,
        startHoldSeconds: 0.5,
        idleSeconds: 2,
        minDurationSeconds: 5,
        postRollSeconds: 0
    )

    func testArmedIgnoresBriefNoiseThenStartsAfterHold() {
        var controller = SilenceSessionController(config: config)
        let t0 = Date(timeIntervalSince1970: 1_000)

        XCTAssertNil(controller.process(level: 0.2, now: t0))
        XCTAssertEqual(controller.phase, .armed)

        XCTAssertNil(controller.process(level: 0.2, now: t0.addingTimeInterval(0.4)))
        XCTAssertEqual(controller.phase, .armed)

        let event = controller.process(level: 0.2, now: t0.addingTimeInterval(0.5))
        XCTAssertEqual(event, .startedRecording)
        XCTAssertEqual(controller.phase, .recording)
    }

    func testArmedResetsHoldWhenLevelDrops() {
        var controller = SilenceSessionController(config: config)
        let t0 = Date(timeIntervalSince1970: 2_000)

        XCTAssertNil(controller.process(level: 0.2, now: t0))
        XCTAssertNil(controller.process(level: 0.01, now: t0.addingTimeInterval(0.3)))
        XCTAssertNil(controller.process(level: 0.2, now: t0.addingTimeInterval(0.6)))
        XCTAssertEqual(controller.phase, .armed)

        let event = controller.process(level: 0.2, now: t0.addingTimeInterval(1.1))
        XCTAssertEqual(event, .startedRecording)
    }

    func testRecordingFinalizesAfterIdleAndDiscardsShortTakes() {
        var controller = SilenceSessionController(config: config)
        let t0 = Date(timeIntervalSince1970: 3_000)
        _ = controller.process(level: 0.2, now: t0)
        _ = controller.process(level: 0.2, now: t0.addingTimeInterval(0.5))
        XCTAssertEqual(controller.phase, .recording)

        XCTAssertNil(controller.process(level: 0.01, now: t0.addingTimeInterval(1.0)))
        let event = controller.process(level: 0.01, now: t0.addingTimeInterval(3.0))
        guard case .finalizeSession(let duration, let discard)? = event else {
            return XCTFail("Expected finalizeSession, got \(String(describing: event))")
        }
        XCTAssertEqual(duration, 2.5, accuracy: 0.001)
        XCTAssertTrue(discard)
        XCTAssertEqual(controller.phase, .armed)
    }

    func testRecordingKeepsLongTakes() {
        var controller = SilenceSessionController(config: config)
        let t0 = Date(timeIntervalSince1970: 4_000)
        _ = controller.process(level: 0.2, now: t0)
        _ = controller.process(level: 0.2, now: t0.addingTimeInterval(0.5))

        // Stay loud for 6s, then idle for 2s.
        XCTAssertNil(controller.process(level: 0.2, now: t0.addingTimeInterval(6.5)))
        XCTAssertNil(controller.process(level: 0.01, now: t0.addingTimeInterval(7.0)))
        let event = controller.process(level: 0.01, now: t0.addingTimeInterval(9.0))
        guard case .finalizeSession(let duration, let discard)? = event else {
            return XCTFail("Expected finalizeSession, got \(String(describing: event))")
        }
        XCTAssertEqual(duration, 8.5, accuracy: 0.001)
        XCTAssertFalse(discard)
        XCTAssertEqual(controller.phase, .armed)
    }

    func testPostRollExtendsRecordingAfterIdleThreshold() {
        let postRollConfig = SilenceSessionConfig(
            startEnergyThreshold: 0.1,
            idleEnergyThreshold: 0.05,
            startHoldSeconds: 0.5,
            idleSeconds: 2,
            minDurationSeconds: 5,
            postRollSeconds: 5
        )
        var controller = SilenceSessionController(config: postRollConfig)
        let t0 = Date(timeIntervalSince1970: 7_000)
        _ = controller.process(level: 0.2, now: t0)
        _ = controller.process(level: 0.2, now: t0.addingTimeInterval(0.5))
        _ = controller.process(level: 0.01, now: t0.addingTimeInterval(1.0))
        XCTAssertNil(controller.process(level: 0.01, now: t0.addingTimeInterval(3.0)))
        XCTAssertEqual(controller.phase, .recording)
        let event = controller.process(level: 0.01, now: t0.addingTimeInterval(8.0))
        XCTAssertNotNil(event)
    }

    func testResumeStartsNewSessionAfterFinalize() {
        var controller = SilenceSessionController(config: config)
        let t0 = Date(timeIntervalSince1970: 5_000)
        _ = controller.process(level: 0.2, now: t0)
        _ = controller.process(level: 0.2, now: t0.addingTimeInterval(0.5))
        _ = controller.process(level: 0.01, now: t0.addingTimeInterval(1.0))
        _ = controller.process(level: 0.01, now: t0.addingTimeInterval(3.0))
        XCTAssertEqual(controller.phase, .armed)

        XCTAssertNil(controller.process(level: 0.2, now: t0.addingTimeInterval(4.0)))
        let event = controller.process(level: 0.2, now: t0.addingTimeInterval(4.5))
        XCTAssertEqual(event, .startedRecording)
        XCTAssertEqual(controller.phase, .recording)
    }

    func testIdleTimerResetsWhenAudioReturns() {
        var controller = SilenceSessionController(config: config)
        let t0 = Date(timeIntervalSince1970: 6_000)
        _ = controller.process(level: 0.2, now: t0)
        _ = controller.process(level: 0.2, now: t0.addingTimeInterval(0.5))

        // Brief dip should not finalize; audio returns and idle clock restarts.
        XCTAssertNil(controller.process(level: 0.01, now: t0.addingTimeInterval(1.0)))
        XCTAssertNil(controller.process(level: 0.2, now: t0.addingTimeInterval(2.5)))
        XCTAssertNil(controller.process(level: 0.01, now: t0.addingTimeInterval(8.0)))
        XCTAssertNil(controller.process(level: 0.01, now: t0.addingTimeInterval(9.5)))
        XCTAssertEqual(controller.phase, .recording)

        let event = controller.process(level: 0.01, now: t0.addingTimeInterval(10.0))
        guard case .finalizeSession(let duration, let discard)? = event else {
            return XCTFail("Expected finalizeSession, got \(String(describing: event))")
        }
        XCTAssertEqual(duration, 9.5, accuracy: 0.001)
        XCTAssertFalse(discard)
    }
}

final class DJAppProcessMatcherTests: XCTestCase {
    func testMatchKnownBundleIdentifiers() {
        XCTAssertEqual(DJAppProcessMatcher.match(bundleIdentifier: "com.serato.seratodj")?.id, "serato")
        XCTAssertEqual(DJAppProcessMatcher.match(bundleIdentifier: "com.pioneerdj.rekordbox")?.id, "rekordbox")
        XCTAssertEqual(DJAppProcessMatcher.match(bundleIdentifier: "com.native-instruments.Traktor")?.id, "traktor")
        XCTAssertEqual(DJAppProcessMatcher.match(bundleIdentifier: "com.atomixproductions.virtualdj")?.id, "virtualdj")
    }

    func testMatchIgnoresUnknownAndDedupesSoftware() {
        XCTAssertNil(DJAppProcessMatcher.match(bundleIdentifier: "com.apple.Safari"))
        let matches = DJAppProcessMatcher.matchRunning(bundleIdentifiers: [
            "com.serato.seratodj",
            "com.serato.dj",
            "com.apple.Safari",
            "com.pioneerdj.rekordboxdj"
        ])
        XCTAssertEqual(matches.map(\.software.id), ["rekordbox", "serato"])
    }

    func testCapturableSoftwareExcludesStubs() {
        let ids = Set(DJAppProcessMatcher.capturableSoftware.map(\.id))
        XCTAssertFalse(ids.contains(SupportedDJSoftware.captureAppID))
        XCTAssertFalse(ids.contains(SupportedDJSoftware.pioneerHardwareAppID))
        XCTAssertTrue(ids.contains("serato"))
        XCTAssertTrue(ids.contains("djay"))
    }
}

#if os(macOS)
final class AppAudioCapturePermissionTests: XCTestCase {
    func testPermissionErrorClassifierMatchesCommonCopy() {
        let permission = NSError(
            domain: "com.apple.ScreenCaptureKit.SCStreamErrorDomain",
            code: -3801,
            userInfo: [NSLocalizedDescriptionKey: "User declined to provide screen recording permission"]
        )
        XCTAssertTrue(AppAudioCaptureService.isScreenCapturePermissionError(permission))

        let unrelated = NSError(
            domain: NSPOSIXErrorDomain,
            code: Int(ENOENT),
            userInfo: [NSLocalizedDescriptionKey: "No such file"]
        )
        XCTAssertFalse(AppAudioCaptureService.isScreenCapturePermissionError(unrelated))
    }
}
#endif


import XCTest
@testable import SetCatcherCore

final class CaptureSessionCoordinatorTests: XCTestCase {
    private let config = SilenceSessionConfig(
        energyThreshold: 0.1,
        startHoldSeconds: 0.5,
        idleSeconds: 2,
        minDurationSeconds: 5
    )

    func testPrepareWatchingThenStartHoldBeginsRecording() {
        var coordinator = CaptureSessionCoordinator(config: config)
        let watching = coordinator.prepareWatching(config: config, targetDisplayName: "Serato DJ Pro")
        XCTAssertEqual(watching.phase, .watching)
        XCTAssertNil(watching.engineAction)

        let t0 = Date(timeIntervalSince1970: 10_000)
        XCTAssertNil(coordinator.tick(level: 0.2, now: t0).engineAction)

        let started = coordinator.tick(level: 0.2, now: t0.addingTimeInterval(0.5))
        XCTAssertEqual(started.phase, .recording)
        XCTAssertEqual(started.engineAction, .beginRecordingFile)
        XCTAssertTrue(started.statusMessage.contains("Serato DJ Pro"))
    }

    func testIdleSilenceFinalizesWithDiscardForShortTake() {
        var coordinator = CaptureSessionCoordinator(config: config)
        _ = coordinator.prepareWatching(config: config, targetDisplayName: "rekordbox")
        let t0 = Date(timeIntervalSince1970: 11_000)
        _ = coordinator.tick(level: 0.2, now: t0)
        _ = coordinator.tick(level: 0.2, now: t0.addingTimeInterval(0.5))

        _ = coordinator.tick(level: 0.01, now: t0.addingTimeInterval(1.0))
        let finalized = coordinator.tick(level: 0.01, now: t0.addingTimeInterval(3.0))
        XCTAssertEqual(finalized.phase, .saving)
        XCTAssertEqual(finalized.engineAction, .endRecordingFile(discard: true))

        let resumed = coordinator.resumeWatchingAfterSave(discarded: true, minDurationSeconds: 5, level: 0)
        XCTAssertEqual(resumed.phase, .watching)
        XCTAssertTrue(resumed.statusMessage.contains("discarded"))
    }

    func testLongTakeSavesWithoutDiscard() {
        var coordinator = CaptureSessionCoordinator(config: config)
        _ = coordinator.prepareWatching(config: config, targetDisplayName: "Traktor")
        let t0 = Date(timeIntervalSince1970: 12_000)
        _ = coordinator.tick(level: 0.2, now: t0)
        _ = coordinator.tick(level: 0.2, now: t0.addingTimeInterval(0.5))
        _ = coordinator.tick(level: 0.2, now: t0.addingTimeInterval(6.5))
        _ = coordinator.tick(level: 0.01, now: t0.addingTimeInterval(7.0))
        let finalized = coordinator.tick(level: 0.01, now: t0.addingTimeInterval(9.0))
        XCTAssertEqual(finalized.engineAction, .endRecordingFile(discard: false))
    }

    func testManualSaveAndDisarm() {
        var coordinator = CaptureSessionCoordinator(config: config)
        _ = coordinator.prepareWatching(config: config, targetDisplayName: "djay Pro")
        let t0 = Date(timeIntervalSince1970: 13_000)
        _ = coordinator.tick(level: 0.2, now: t0)
        _ = coordinator.tick(level: 0.2, now: t0.addingTimeInterval(0.5))

        let manual = coordinator.requestManualSave()
        XCTAssertEqual(manual.phase, .saving)
        XCTAssertEqual(manual.engineAction, .endRecordingFile(discard: false))

        let afterManual = coordinator.resumeWatchingAfterManualSave(level: 0.05)
        XCTAssertEqual(afterManual.phase, .watching)

        let disarmed = coordinator.disarm(hasTargets: true)
        XCTAssertEqual(disarmed.phase, .armed)
    }

    func testInputDeviceWatchingCopyNamesFolderProtection() {
        var coordinator = CaptureSessionCoordinator(config: config)
        let watching = coordinator.prepareWatching(
            config: config,
            targetDisplayName: "the XDJ-XZ input",
            route: .inputDevice
        )
        XCTAssertTrue(watching.statusMessage.contains("Watching the XDJ-XZ input."))
        XCTAssertTrue(watching.statusMessage.contains("Folder Protection still watches recording folders."))
        XCTAssertFalse(watching.statusMessage.contains("app audio"))
    }
}

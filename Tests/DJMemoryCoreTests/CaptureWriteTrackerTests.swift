import XCTest
@testable import DJMemoryCore

final class CaptureWriteTrackerTests: XCTestCase {
    func testCleanTakeReportsNoFailure() {
        var tracker = CaptureWriteTracker()
        for _ in 0..<10 { tracker.recordSuccess() }

        XCTAssertFalse(tracker.hasFailures)
        XCTAssertNil(tracker.failure)
    }

    /// The core regression: each capture path used to keep a single `lastWriteErrorDetail` that a
    /// later successful write reset to `nil`, so a mid-take failure was erased and the set was
    /// archived with an unannounced gap.
    func testLaterSuccessDoesNotEraseAnEarlierFailure() throws {
        var tracker = CaptureWriteTracker()
        tracker.recordSuccess()
        tracker.recordFailure { "disk hiccup" }
        for _ in 0..<100 { tracker.recordSuccess() }

        let failure = try XCTUnwrap(tracker.failure)
        XCTAssertEqual(failure.failedBufferCount, 1)
        XCTAssertEqual(failure.detail, "disk hiccup")
        XCTAssertTrue(failure.wroteAnyAudio)
        XCTAssertFalse(failure.isFatal, "a gapped take must still be archived")
    }

    /// The other half: a failure on the final buffer used to discard the entire staging file.
    func testPartialFailureIsNotFatalSoTheSetIsKept() {
        var tracker = CaptureWriteTracker()
        for _ in 0..<500 { tracker.recordSuccess() }
        tracker.recordFailure { "write failed at the end" }

        XCTAssertEqual(tracker.failure?.isFatal, false)
        XCTAssertEqual(tracker.failure?.wroteAnyAudio, true)
    }

    func testTakeWithNoSuccessfulWritesIsFatal() {
        var tracker = CaptureWriteTracker()
        for _ in 0..<5 { tracker.recordFailure { "format rejected" } }

        let failure = tracker.failure
        XCTAssertEqual(failure?.failedBufferCount, 5)
        XCTAssertEqual(failure?.wroteAnyAudio, false)
        XCTAssertEqual(failure?.isFatal, true, "a take with no audio must fail loudly")
    }

    /// The detail closure is the expensive part (two AVAudioFormat descriptions), so it must run
    /// once per take rather than once per dropped buffer.
    func testDetailIsBuiltOnlyOnceRegardlessOfFailureCount() {
        var tracker = CaptureWriteTracker()
        var builds = 0

        for _ in 0..<1_000 {
            tracker.recordFailure {
                builds += 1
                return "first failure only"
            }
        }

        XCTAssertEqual(builds, 1)
        XCTAssertEqual(tracker.failure?.failedBufferCount, 1_000)
        XCTAssertEqual(tracker.failure?.detail, "first failure only")
    }

    func testResetClearsEverythingBetweenTakes() {
        var tracker = CaptureWriteTracker()
        tracker.recordFailure { "stale" }
        tracker.recordSuccess()

        tracker.reset()

        XCTAssertFalse(tracker.hasFailures)
        XCTAssertNil(tracker.failure, "a previous take must not leak into the next one")
    }

    func testSummaryDistinguishesGappedFromEmpty() {
        var gapped = CaptureWriteTracker()
        gapped.recordSuccess()
        gapped.recordFailure { "detail" }
        XCTAssertTrue(gapped.failure?.summary.contains("saved with gaps") == true)

        var empty = CaptureWriteTracker()
        empty.recordFailure { "detail" }
        XCTAssertTrue(empty.failure?.summary.contains("no audio") == true)
    }
}

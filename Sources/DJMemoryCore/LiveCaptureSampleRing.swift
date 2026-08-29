import DJMemoryAtomics
import Foundation

/// Diagnostic counters for the capture ring. Metadata only — never audio, never track titles.
public struct LiveCaptureRingDiagnostics: Equatable, Sendable {
    /// Frames the producer had to discard because the consumer fell behind.
    public var droppedFrames: Int
    /// Frames the consumer asked for that did not exist yet (filled with silence).
    public var underflowFrames: Int
    /// Number of distinct times the reader had to skip forward after an overrun.
    public var discontinuities: Int

    public init(droppedFrames: Int = 0, underflowFrames: Int = 0, discontinuities: Int = 0) {
        self.droppedFrames = droppedFrames
        self.underflowFrames = underflowFrames
        self.discontinuities = discontinuities
    }
}

/// Preallocated interleaved Float32 ring between a real-time audio callback and the
/// recording pipeline.
///
/// `writeRealtime` is the only entry the future `DJMemoryAudio.driver` IOProc should call.
/// It does not allocate, take locks, log, perform file I/O, or create Swift objects.
///
/// Single producer, single consumer. The producer owns `writeIndex` and the consumer owns
/// `readIndex`; neither writes the other's cursor, so no compare-and-swap loop is needed —
/// a spin loop in a real-time callback is a lock in all but name.
///
/// On overflow the ring drops the **oldest** frames: live audio is worth more than stale
/// audio, so the producer keeps writing and the consumer skips forward to the newest
/// `frameCapacity` frames it can still deliver.
public final class LiveCaptureSampleRing: @unchecked Sendable {
    public let frameCapacity: Int
    public let channelCount: Int

    private let storage: UnsafeMutablePointer<Float>
    /// Heap-allocated so their addresses are stable for the lifetime of the ring.
    private let writeIndex: UnsafeMutablePointer<Int64>
    private let readIndex: UnsafeMutablePointer<Int64>
    private let droppedFrames: UnsafeMutablePointer<Int64>
    private let underflowFrames: UnsafeMutablePointer<Int64>
    private let discontinuities: UnsafeMutablePointer<Int64>

    public init(frameCapacity: Int, channelCount: Int = 2) {
        precondition(frameCapacity > 0)
        precondition(channelCount > 0)
        self.frameCapacity = frameCapacity
        self.channelCount = channelCount
        let count = frameCapacity * channelCount
        storage = .allocate(capacity: count)
        storage.initialize(repeating: 0, count: count)

        func makeCounter() -> UnsafeMutablePointer<Int64> {
            let pointer = UnsafeMutablePointer<Int64>.allocate(capacity: 1)
            pointer.initialize(to: 0)
            return pointer
        }
        writeIndex = makeCounter()
        readIndex = makeCounter()
        droppedFrames = makeCounter()
        underflowFrames = makeCounter()
        discontinuities = makeCounter()
    }

    deinit {
        storage.deinitialize(count: frameCapacity * channelCount)
        storage.deallocate()
        for pointer in [writeIndex, readIndex, droppedFrames, underflowFrames, discontinuities] {
            pointer.deinitialize(count: 1)
            pointer.deallocate()
        }
    }

    public var availableFrames: Int {
        let write = djm_atomic_load_acquire(writeIndex)
        let read = djm_atomic_load_acquire(readIndex)
        return min(max(0, Int(write - read)), frameCapacity)
    }

    public var diagnostics: LiveCaptureRingDiagnostics {
        LiveCaptureRingDiagnostics(
            droppedFrames: Int(djm_atomic_load_relaxed(droppedFrames)),
            underflowFrames: Int(djm_atomic_load_relaxed(underflowFrames)),
            discontinuities: Int(djm_atomic_load_relaxed(discontinuities))
        )
    }

    /// Real-time safe producer. Always accepts the newest audio; the oldest unread frames
    /// are the ones that go. Returns the number of frames written.
    @discardableResult
    public func writeRealtime(interleavedFrames: UnsafePointer<Float>, frameCount: Int) -> Int {
        guard frameCount > 0 else { return 0 }

        // Only this thread advances writeIndex, so a relaxed load of our own cursor is safe.
        let write = djm_atomic_load_relaxed(writeIndex)
        let read = djm_atomic_load_acquire(readIndex)
        let filled = Int(write - read)

        // Writing more than the ring holds: keep only the newest frameCapacity frames.
        let source: UnsafePointer<Float>
        let framesToWrite: Int
        if frameCount > frameCapacity {
            let skipped = frameCount - frameCapacity
            source = interleavedFrames.advanced(by: skipped * channelCount)
            framesToWrite = frameCapacity
            djm_atomic_add_relaxed(droppedFrames, Int64(skipped))
        } else {
            source = interleavedFrames
            framesToWrite = frameCount
        }

        let overrun = max(0, filled + framesToWrite - frameCapacity)
        if overrun > 0 {
            djm_atomic_add_relaxed(droppedFrames, Int64(overrun))
        }

        let start = Int(write % Int64(frameCapacity))
        copyFrames(from: source, frameCount: framesToWrite, toFrame: start)
        djm_atomic_store_release(writeIndex, write + Int64(framesToWrite))
        return framesToWrite
    }

    /// Non-realtime consumer for the existing recording pipeline.
    ///
    /// Returns the number of real frames delivered. Anything the producer overwrote before
    /// it could be read is skipped and counted as a discontinuity.
    @discardableResult
    public func read(into destination: UnsafeMutablePointer<Float>, maxFrames: Int) -> Int {
        guard maxFrames > 0 else { return 0 }
        let write = djm_atomic_load_acquire(writeIndex)
        var read = djm_atomic_load_relaxed(readIndex)

        // The producer lapped us: skip forward to the oldest frame still intact.
        if write - read > Int64(frameCapacity) {
            read = write - Int64(frameCapacity)
            djm_atomic_store_relaxed(readIndex, read)
            djm_atomic_add_relaxed(discontinuities, 1)
        }

        let filled = Int(write - read)
        let framesToRead = min(maxFrames, filled)
        guard framesToRead > 0 else { return 0 }

        let start = Int(read % Int64(frameCapacity))
        copyFrames(fromFrame: start, frameCount: framesToRead, to: destination)
        djm_atomic_store_release(readIndex, read + Int64(framesToRead))
        return framesToRead
    }

    /// Consumer variant with deterministic underflow: any frames the ring cannot supply are
    /// filled with silence rather than left as stale memory. Always fills `maxFrames`.
    @discardableResult
    public func readFillingSilence(
        into destination: UnsafeMutablePointer<Float>,
        maxFrames: Int
    ) -> Int {
        guard maxFrames > 0 else { return 0 }
        let delivered = read(into: destination, maxFrames: maxFrames)
        let missing = maxFrames - delivered
        if missing > 0 {
            destination.advanced(by: delivered * channelCount)
                .update(repeating: 0, count: missing * channelCount)
            djm_atomic_add_relaxed(underflowFrames, Int64(missing))
        }
        return delivered
    }

    private func copyFrames(from source: UnsafePointer<Float>, frameCount: Int, toFrame start: Int) {
        let first = min(frameCount, frameCapacity - start)
        let sampleFirst = first * channelCount
        storage.advanced(by: start * channelCount).update(from: source, count: sampleFirst)
        if first < frameCount {
            storage.update(from: source.advanced(by: sampleFirst), count: (frameCount - first) * channelCount)
        }
    }

    private func copyFrames(fromFrame start: Int, frameCount: Int, to destination: UnsafeMutablePointer<Float>) {
        let first = min(frameCount, frameCapacity - start)
        let sampleFirst = first * channelCount
        destination.update(from: storage.advanced(by: start * channelCount), count: sampleFirst)
        if first < frameCount {
            destination.advanced(by: sampleFirst).update(
                from: storage,
                count: (frameCount - first) * channelCount
            )
        }
    }
}

import Foundation

/// What went wrong while writing a take, surfaced alongside the finished `CaptureResult`.
///
/// A dropped buffer is lost audio. It cannot be recovered later in the take, so the fact that it
/// happened has to outlive the buffer that failed.
public struct CaptureWriteFailure: Equatable, Sendable {
    /// Detail of the *first* failure, with format diagnostics attached.
    public let detail: String
    /// How many buffers failed to write.
    public let failedBufferCount: Int
    /// Whether any buffer was written successfully. `false` means the file has no usable audio.
    public let wroteAnyAudio: Bool

    public init(detail: String, failedBufferCount: Int, wroteAnyAudio: Bool) {
        self.detail = detail
        self.failedBufferCount = failedBufferCount
        self.wroteAnyAudio = wroteAnyAudio
    }

    /// A take that produced no audio at all is worthless and should fail loudly. One that lost
    /// some buffers is gapped but still worth keeping — for a set archiver, a set with a gap
    /// beats a deleted set.
    public var isFatal: Bool { !wroteAnyAudio }

    public var summary: String {
        let buffers = failedBufferCount == 1 ? "1 buffer" : "\(failedBufferCount) buffers"
        return wroteAnyAudio
            ? "Recording saved with gaps — \(buffers) failed to write. \(detail)"
            : "Recording failed — no audio could be written. \(detail)"
    }
}

/// Accumulates per-buffer write outcomes across one take.
///
/// Previously each capture path kept a single `lastWriteErrorDetail` that a later successful
/// write reset to `nil`. That made failures last-write-wins: a mid-take failure was silently
/// erased by the next success and the take was archived with an unannounced gap, while a failure
/// on the final buffer discarded the entire staging file. Both are wrong; this records the whole
/// picture instead.
public struct CaptureWriteTracker: Sendable {
    private var firstDetail: String?
    private var failedCount = 0
    private var succeededCount = 0

    public init() {}

    public mutating func reset() {
        firstDetail = nil
        failedCount = 0
        succeededCount = 0
    }

    public mutating func recordSuccess() {
        succeededCount += 1
    }

    /// Records a failed buffer. `makeDetail` is evaluated only for the first failure, so the
    /// expensive diagnostic string is built once per take rather than once per dropped buffer.
    public mutating func recordFailure(_ makeDetail: () -> String) {
        failedCount += 1
        if firstDetail == nil {
            firstDetail = makeDetail()
        }
    }

    public var hasFailures: Bool { failedCount > 0 }

    public var failure: CaptureWriteFailure? {
        guard let firstDetail else { return nil }
        return CaptureWriteFailure(
            detail: firstDetail,
            failedBufferCount: failedCount,
            wroteAnyAudio: succeededCount > 0
        )
    }
}

import Foundation

public struct SilenceSessionConfig: Codable, Equatable, Sendable {
    /// Level at or above which the armed phase accumulates start hold time.
    public var startEnergyThreshold: Float
    /// Level below which the recording phase accumulates idle stop time.
    public var idleEnergyThreshold: Float
    public var startHoldSeconds: TimeInterval
    public var idleSeconds: TimeInterval
    public var minDurationSeconds: TimeInterval
    public var prerollSeconds: TimeInterval
    public var postRollSeconds: TimeInterval

    public init(
        startEnergyThreshold: Float = CaptureLevelScale.dispatchStartEnergyThreshold,
        idleEnergyThreshold: Float = CaptureLevelScale.dispatchIdleEnergyThreshold,
        startHoldSeconds: TimeInterval = CaptureLevelScale.dispatchStartHoldSeconds,
        idleSeconds: TimeInterval = CaptureLevelScale.dispatchIdleSeconds,
        minDurationSeconds: TimeInterval = CaptureLevelScale.dispatchMinimumDurationSeconds,
        prerollSeconds: TimeInterval = CaptureLevelScale.dispatchPrerollSeconds,
        postRollSeconds: TimeInterval = CaptureLevelScale.dispatchPostRollSeconds
    ) {
        self.startEnergyThreshold = startEnergyThreshold
        self.idleEnergyThreshold = idleEnergyThreshold
        self.startHoldSeconds = startHoldSeconds
        self.idleSeconds = idleSeconds
        self.minDurationSeconds = minDurationSeconds
        self.prerollSeconds = prerollSeconds
        self.postRollSeconds = postRollSeconds
    }

    /// Legacy alias for callers that only set one threshold (used in tests).
    public init(
        energyThreshold: Float,
        startHoldSeconds: TimeInterval,
        idleSeconds: TimeInterval,
        minDurationSeconds: TimeInterval
    ) {
        self.init(
            startEnergyThreshold: energyThreshold,
            idleEnergyThreshold: energyThreshold * 0.5,
            startHoldSeconds: startHoldSeconds,
            idleSeconds: idleSeconds,
            minDurationSeconds: minDurationSeconds
        )
    }

    public static let `default` = SilenceSessionConfig()
}

public enum SilenceSessionPhase: Equatable, Sendable {
    case armed
    case recording
}

public enum SilenceSessionEvent: Equatable, Sendable {
    case startedRecording
    /// Session ended. `discard` is true when duration is below `minDurationSeconds`.
    case finalizeSession(duration: TimeInterval, discard: Bool)
}

/// Pure policy for silence-based start / stop / re-arm. Feed RMS levels from a capture engine.
public struct SilenceSessionController: Equatable, Sendable {
    public private(set) var phase: SilenceSessionPhase
    public var config: SilenceSessionConfig

    private var aboveSince: Date?
    private var belowSince: Date?
    private var recordingStartedAt: Date?
    private var postRollUntil: Date?

    public init(config: SilenceSessionConfig = .default, phase: SilenceSessionPhase = .armed) {
        self.config = config
        self.phase = phase
        self.aboveSince = nil
        self.belowSince = nil
        self.recordingStartedAt = nil
        self.postRollUntil = nil
    }

    public mutating func resetToArmed() {
        phase = .armed
        aboveSince = nil
        belowSince = nil
        recordingStartedAt = nil
        postRollUntil = nil
    }

    /// Force recording without waiting for start hold (manual start — never confirms in UI).
    public mutating func forceStartRecording(now: Date = Date()) {
        phase = .recording
        recordingStartedAt = now
        aboveSince = nil
        belowSince = nil
        postRollUntil = nil
    }

    public mutating func process(level: Float, now: Date = Date()) -> SilenceSessionEvent? {
        let isAboveStart = level >= config.startEnergyThreshold
        let isBelowIdle = level < config.idleEnergyThreshold

        switch phase {
        case .armed:
            belowSince = nil
            postRollUntil = nil
            if isAboveStart {
                if aboveSince == nil { aboveSince = now }
                if let aboveSince, now.timeIntervalSince(aboveSince) >= config.startHoldSeconds {
                    phase = .recording
                    recordingStartedAt = now
                    self.aboveSince = nil
                    belowSince = nil
                    return .startedRecording
                }
            } else {
                aboveSince = nil
            }
            return nil

        case .recording:
            if !isBelowIdle {
                belowSince = nil
                postRollUntil = nil
                return nil
            }
            if belowSince == nil { belowSince = now }
            guard let belowSince, now.timeIntervalSince(belowSince) >= config.idleSeconds else {
                return nil
            }
            if postRollUntil == nil {
                postRollUntil = now.addingTimeInterval(config.postRollSeconds)
            }
            guard let postRollUntil, now >= postRollUntil else {
                return nil
            }
            let started = recordingStartedAt ?? now
            let duration = now.timeIntervalSince(started)
            let discard = duration < config.minDurationSeconds
            phase = .armed
            aboveSince = nil
            self.belowSince = nil
            recordingStartedAt = nil
            self.postRollUntil = nil
            return .finalizeSession(duration: duration, discard: discard)
        }
    }
}

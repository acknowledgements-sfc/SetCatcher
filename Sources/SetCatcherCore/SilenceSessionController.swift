import Foundation

public struct SilenceSessionConfig: Codable, Equatable, Sendable {
    public var energyThreshold: Float
    public var startHoldSeconds: TimeInterval
    public var idleSeconds: TimeInterval
    public var minDurationSeconds: TimeInterval

    public init(
        energyThreshold: Float = 0.02,
        startHoldSeconds: TimeInterval = 0.5,
        idleSeconds: TimeInterval = 90,
        minDurationSeconds: TimeInterval = 30
    ) {
        self.energyThreshold = energyThreshold
        self.startHoldSeconds = startHoldSeconds
        self.idleSeconds = idleSeconds
        self.minDurationSeconds = minDurationSeconds
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

    public init(config: SilenceSessionConfig = .default, phase: SilenceSessionPhase = .armed) {
        self.config = config
        self.phase = phase
        self.aboveSince = nil
        self.belowSince = nil
        self.recordingStartedAt = nil
    }

    public mutating func resetToArmed() {
        phase = .armed
        aboveSince = nil
        belowSince = nil
        recordingStartedAt = nil
    }

    public mutating func process(level: Float, now: Date = Date()) -> SilenceSessionEvent? {
        let isAbove = level >= config.energyThreshold

        switch phase {
        case .armed:
            belowSince = nil
            if isAbove {
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
            if isAbove {
                belowSince = nil
                return nil
            }
            if belowSince == nil { belowSince = now }
            guard let belowSince, now.timeIntervalSince(belowSince) >= config.idleSeconds else {
                return nil
            }
            let started = recordingStartedAt ?? now
            let duration = now.timeIntervalSince(started)
            let discard = duration < config.minDurationSeconds
            phase = .armed
            aboveSince = nil
            self.belowSince = nil
            recordingStartedAt = nil
            return .finalizeSession(duration: duration, discard: discard)
        }
    }
}

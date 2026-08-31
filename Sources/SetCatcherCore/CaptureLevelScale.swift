import Foundation

/// Maps RMS / UI meter levels to dBFS for capture start/stop policy and metering labels.
public enum CaptureLevelScale: Sendable {
    /// Matches `CaptureDSP.inputLevel(rms:)` — UI level = min(1, rms × 4).
    public static let inputLevelScale: Float = 4

    public static let dispatchStartDbFS: Float = -40
    public static let dispatchIdleDbFS: Float = -55
    public static let dispatchStartHoldSeconds: TimeInterval = 3
    public static let dispatchIdleSeconds: TimeInterval = 60
    public static let dispatchPrerollSeconds: TimeInterval = 10
    public static let dispatchPostRollSeconds: TimeInterval = 5
    public static let dispatchMinimumDurationSeconds: TimeInterval = 30

    public static var dispatchStartEnergyThreshold: Float {
        inputLevel(forDbFS: dispatchStartDbFS)
    }

    public static var dispatchIdleEnergyThreshold: Float {
        inputLevel(forDbFS: dispatchIdleDbFS)
    }

    /// Full-scale sine reference: 0 dBFS = RMS 1.0.
    public static func dbFS(forRMS rms: Float) -> Float {
        guard rms.isFinite, rms > 0 else { return -120 }
        return 20 * log10f(rms)
    }

    public static func dbFS(forInputLevel level: Float) -> Float {
        let rms = rms(forInputLevel: level)
        return dbFS(forRMS: rms)
    }

    public static func rms(forInputLevel level: Float) -> Float {
        guard level.isFinite, level > 0 else { return 0 }
        return level / inputLevelScale
    }

    public static func inputLevel(forDbFS dbFS: Float) -> Float {
        let rms = powf(10, dbFS / 20)
        return min(1, max(0, rms * inputLevelScale))
    }

    /// Maps input level onto a −60…0 dBFS meter (0 = silence floor, 1 = full scale).
    public static let meterFloorDbFS: Float = -60

    public static func meterFraction(forInputLevel level: Float) -> Float {
        let db = dbFS(forInputLevel: level)
        let span = -meterFloorDbFS
        return min(1, max(0, (db - meterFloorDbFS) / span))
    }
}

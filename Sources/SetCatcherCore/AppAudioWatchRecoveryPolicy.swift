import Foundation

/// When App audio is already `.watching`, auto-arm is otherwise skipped.
/// Recover only when the tap is dead or bound to a DJ app that is no longer running.
public enum AppAudioWatchRecoveryPolicy {
    public static func shouldRearm(
        phase: CapturePhase,
        isMonitoring: Bool,
        monitoredBundleIdentifier: String,
        shareableBundleIdentifiers: [String]
    ) -> Bool {
        guard phase == .watching else { return false }
        guard !shareableBundleIdentifiers.isEmpty else { return false }
        if !isMonitoring { return true }
        if monitoredBundleIdentifier.isEmpty { return true }
        return !shareableBundleIdentifiers.contains(monitoredBundleIdentifier)
    }

    /// The DJ app feeding the current take has quit. Save immediately instead of
    /// waiting out idle silence on a dead tap, then the host can re-arm.
    /// Do not use this while the monitored app is still shareable — that would split a live take.
    public static func shouldFinalizeAbandonedRecording(
        phase: CapturePhase,
        monitoredBundleIdentifier: String,
        shareableBundleIdentifiers: [String]
    ) -> Bool {
        guard phase == .recording else { return false }
        guard !monitoredBundleIdentifier.isEmpty else { return false }
        return !shareableBundleIdentifiers.contains(monitoredBundleIdentifier)
    }
}

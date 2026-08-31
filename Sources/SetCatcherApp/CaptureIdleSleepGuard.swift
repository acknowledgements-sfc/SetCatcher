import Foundation

/// Prevents idle system sleep while Capture is on duty (watching / recording / saving).
///
/// Uses `ProcessInfo.beginActivity` only — never shells out to `caffeinate` or vendors
/// third-party stay-awake apps.
final class CaptureIdleSleepGuard: @unchecked Sendable {
    private let lock = NSLock()
    private var activity: NSObjectProtocol?

    /// Idempotent: begins at most one activity while `shouldHold` is true; ends when false.
    func sync(shouldHold: Bool) {
        lock.lock()
        defer { lock.unlock() }

        if shouldHold {
            guard activity == nil else { return }
            activity = ProcessInfo.processInfo.beginActivity(
                options: [.idleSystemSleepDisabled],
                reason: "SetCatcher Capture is armed and listening or recording"
            )
        } else {
            endLocked()
        }
    }

    func release() {
        lock.lock()
        defer { lock.unlock() }
        endLocked()
    }

    deinit {
        lock.lock()
        endLocked()
        lock.unlock()
    }

    private func endLocked() {
        guard let activity else { return }
        ProcessInfo.processInfo.endActivity(activity)
        self.activity = nil
    }
}

import Foundation
import UserNotifications
import SetCatcherCore

struct LocalNotificationService {
    /// UserNotifications requires a real `.app` bundle. SPM/Xcode package runs
    /// (Products/Debug/SetCatcherApp) have no bundle proxy and assert on `.current()`.
    static var canUseUserNotifications: Bool {
        Bundle.main.bundleURL.pathExtension.lowercased() == "app"
    }

    static let quietCategoryID = "setcatcher.quiet"
    static let urgentCategoryID = "setcatcher.urgent"
    static let openAppActionID = "setcatcher.open"

    private let center: UNUserNotificationCenter?

    init(center: UNUserNotificationCenter? = nil) {
        if let center {
            self.center = center
        } else if Self.canUseUserNotifications {
            self.center = .current()
        } else {
            self.center = nil
        }
    }

    func requestAuthorization() {
        center?.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        registerCategories()
    }

    private func registerCategories() {
        guard let center else { return }
        let open = UNNotificationAction(
            identifier: Self.openAppActionID,
            title: "Open SetCatcher",
            options: [.foreground]
        )
        let quiet = UNNotificationCategory(
            identifier: Self.quietCategoryID,
            actions: [],
            intentIdentifiers: []
        )
        let urgent = UNNotificationCategory(
            identifier: Self.urgentCategoryID,
            actions: [open],
            intentIdentifiers: []
        )
        center.setNotificationCategories([quiet, urgent])
    }

    func notifyPerformanceAttachment(_ body: String) {
        postQuiet(title: "SetCatcher", body: body, idPrefix: "archive-attached")
    }

    func notifyArchiveSaved(count: Int) {
        guard count > 0 else { return }
        let body = count == 1
            ? "SetCatcher archived a completed recording."
            : "SetCatcher archived \(count) completed recordings."
        postQuiet(title: "SetCatcher", body: body, idPrefix: "archive-saved")
    }

    /// Quiet tier: set protected toast companion.
    func notifySetProtected(setName: String, durationText: String) {
        postQuiet(
            title: "SetCatcher",
            body: "Set protected — \(setName) · \(durationText)",
            idPrefix: "set-protected"
        )
    }

    static func captureStartedBody(displayName _: String, at date: Date = Date(), calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        return String(format: "Recording started - %02d:%02d", hour, minute)
    }

    /// A different DJ app or input device was detected while one is already armed/watching.
    func notifyAlternateSourceDetected(displayName: String) {
        postQuiet(
            title: "Another source detected",
            body: "\(displayName) is also running. Open SetCatcher to switch, or keep watching the current source.",
            idPrefix: "alternate-source"
        )
    }

    /// Quiet tier: capture started (no sound — don't interrupt the DJ).
    func notifyCaptureStarted(displayName: String, at date: Date = Date()) {
        postQuiet(
            title: "SetCatcher",
            body: "Capturing — \(displayName) detected",
            idPrefix: "capture-started",
            sound: false
        )
    }

    /// Urgent tier: attention needed — persists in Notification Center until dismissed.
    func notifyAttentionNeeded(_ event: AttentionEvent) {
        let body = Self.urgentBody(for: event)
        postUrgent(title: "SetCatcher", body: body, identifier: "attention-\(event.id)")
    }

    func clearAttentionNotification(id: String) {
        center?.removeDeliveredNotifications(withIdentifiers: ["attention-\(id)"])
        center?.removePendingNotificationRequests(withIdentifiers: ["attention-\(id)"])
    }

    static func urgentBody(for event: AttentionEvent) -> String {
        switch event.kind {
        case .folderMoved:
            return "Recording folder was moved — sets may not be protected"
        case .folderMissing:
            return "Recording folder not found — sets may not be protected"
        case .permissionDenied:
            return "Can't access recording folder — sets may not be protected"
        case .diskFull:
            return event.warning ?? "Low disk space — capture may stop"
        case .saveFailed:
            return "Failed to save set — recording is safe in temp file"
        case .screenRecording:
            return "Screen Recording permission required — App audio Capture can't arm"
        case .sourceUnreadable:
            return event.body + " — capture may be incomplete"
        }
    }

    private func postQuiet(title: String, body: String, idPrefix: String, sound: Bool = true) {
        guard let center else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.categoryIdentifier = Self.quietCategoryID
        if sound { content.sound = .default }
        let request = UNNotificationRequest(
            identifier: "\(idPrefix)-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        center.add(request)
    }

    private func postUrgent(title: String, body: String, identifier: String) {
        guard let center else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = Self.urgentCategoryID
        // Replacing same identifier keeps one persistent alert per attention event.
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )
        center.add(request)
    }
}

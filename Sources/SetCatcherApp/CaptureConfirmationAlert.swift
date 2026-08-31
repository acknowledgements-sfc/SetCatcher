import AppKit

enum CaptureConfirmationAlert {
    static func confirmStopCapture() -> Bool {
        let alert = NSAlert()
        alert.messageText = "Stop capture and save?"
        alert.informativeText = "SetCatcher will save this set to your archive and keep watching for the next one. Source DJ app files are not moved."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Stop & Save")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    static func confirmStopAndDisarm() -> Bool {
        let alert = NSAlert()
        alert.messageText = "Stop capture, save, and disarm?"
        alert.informativeText = "SetCatcher will save this set, then stop watching for audio. Folder Protection still watches recording folders. You can arm again from Capture or the menu bar."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Stop & Disarm")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    static func confirmDisarmWhileRecording() -> Bool {
        confirmStopAndDisarm()
    }

    static func confirmSourceSwitch(from current: String, to alternate: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = "Switch protection source?"
        alert.informativeText = "SetCatcher will stop watching \(current) and arm \(alternate). No recording is currently in progress."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Switch Source")
        alert.addButton(withTitle: "Keep Current")
        return alert.runModal() == .alertFirstButtonReturn
    }
}

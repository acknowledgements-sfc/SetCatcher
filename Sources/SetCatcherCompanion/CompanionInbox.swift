import Foundation
import SetCatcherCore

/// App Group inbox used by the Share extension → companion import path.
public enum CompanionInbox {
    public static let appGroupID = "group.app.setcatcher.shared"

    public static var inboxDirectory: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("Inbox", isDirectory: true)
    }

    @MainActor
    public static func drain(into model: CompanionModel) {
        guard let inbox = inboxDirectory else { return }
        let fm = FileManager.default
        try? fm.createDirectory(at: inbox, withIntermediateDirectories: true)
        guard let files = try? fm.contentsOfDirectory(at: inbox, includingPropertiesForKeys: nil) else { return }
        let audio = files.filter { ["wav", "mp3", "m4a", "aiff", "caf"].contains($0.pathExtension.lowercased()) }
        guard !audio.isEmpty else { return }
        model.importAudioURLs(audio, appID: MobileDJSoftware.djay.id)
        for url in audio {
            try? fm.removeItem(at: url)
        }
    }

    public static func copySharedFile(from url: URL) throws -> URL {
        guard let inbox = inboxDirectory else {
            throw NSError(domain: "SetCatcherShare", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Shared container is unavailable. Reinstall SetCatcher Companion."
            ])
        }
        let fm = FileManager.default
        try fm.createDirectory(at: inbox, withIntermediateDirectories: true)
        let dest = inbox.appendingPathComponent(url.lastPathComponent)
        if fm.fileExists(atPath: dest.path) {
            try fm.removeItem(at: dest)
        }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        try fm.copyItem(at: url, to: dest)
        return dest
    }
}

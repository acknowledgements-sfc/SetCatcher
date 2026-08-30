import Foundation

public enum SeratoSessionResearch {
    public static let notes = "Serato live .session files are undocumented and brittle. Prefer History Export CSV/TXT and the Recording folder watcher."

    public static func looksLikeSessionFilename(_ name: String) -> Bool {
        name.lowercased().hasSuffix(".session")
    }
}

import Foundation

public enum FolderKind: String, Codable, Sendable {
    case recordings
    case history

    public var displayName: String {
        switch self {
        case .recordings:
            return "Recording"
        case .history:
            return "History"
        }
    }
}

public struct FolderAccess: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let appID: String
    public let kind: FolderKind
    public let url: URL
    public let bookmarkData: Data?
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        appID: String,
        kind: FolderKind,
        url: URL,
        bookmarkData: Data?,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.appID = appID
        self.kind = kind
        self.url = url
        self.bookmarkData = bookmarkData
        self.createdAt = createdAt
    }
}

import Foundation

public enum ActivityEventKind: String, Codable, Sendable {
    case archive
    case importTracklist
    case scan
    case error
    case diagnostics
    case capture

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = ActivityEventKind(rawValue: raw) ?? .scan
    }
}

public struct ActivityEvent: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let kind: ActivityEventKind
    public let message: String
    public let detail: String?
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        kind: ActivityEventKind,
        message: String,
        detail: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.message = message
        self.detail = detail
        self.createdAt = createdAt
    }
}

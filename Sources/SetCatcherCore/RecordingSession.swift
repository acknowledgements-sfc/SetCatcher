import Foundation

public enum RecordingSessionStatus: String, Codable, Sendable {
    case detected
    case stabilizing
    case archived
    case failed
}

public struct RecordingSession: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let sourceAppID: String
    public let detectedAt: Date
    public var completedAt: Date?
    public let sourceURL: URL
    public var archiveURL: URL?
    public var fileSize: Int64?
    public var status: RecordingSessionStatus

    public init(
        id: UUID = UUID(),
        sourceAppID: String,
        detectedAt: Date = Date(),
        completedAt: Date? = nil,
        sourceURL: URL,
        archiveURL: URL? = nil,
        fileSize: Int64? = nil,
        status: RecordingSessionStatus = .detected
    ) {
        self.id = id
        self.sourceAppID = sourceAppID
        self.detectedAt = detectedAt
        self.completedAt = completedAt
        self.sourceURL = sourceURL
        self.archiveURL = archiveURL
        self.fileSize = fileSize
        self.status = status
    }
}

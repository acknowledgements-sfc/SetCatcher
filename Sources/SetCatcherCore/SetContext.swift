import Foundation

public struct SetContext: Identifiable, Codable, Equatable, Sendable {
    public let sessionID: UUID
    public var eventName: String
    public var venue: String
    public var city: String
    public var tags: String
    public var notes: String
    public var manualTracklistID: UUID?
    public var updatedAt: Date

    public var id: UUID { sessionID }

    public init(
        sessionID: UUID,
        eventName: String = "",
        venue: String = "",
        city: String = "",
        tags: String = "",
        notes: String = "",
        manualTracklistID: UUID? = nil,
        updatedAt: Date = Date()
    ) {
        self.sessionID = sessionID
        self.eventName = eventName
        self.venue = venue
        self.city = city
        self.tags = tags
        self.notes = notes
        self.manualTracklistID = manualTracklistID
        self.updatedAt = updatedAt
    }
}

public struct SetContextStore {
    public let storageURL: URL
    private let fileManager: FileManager

    public init(
        storageURL: URL = Self.defaultStorageURL(),
        fileManager: FileManager = .default
    ) {
        self.storageURL = storageURL
        self.fileManager = fileManager
    }

    public static func defaultStorageURL() -> URL {
        DefaultPathProvider().applicationSupportDirectory()
            .appendingPathComponent("set-contexts.json")
    }

    public func all() throws -> [SetContext] {
        guard fileManager.fileExists(atPath: storageURL.path) else {
            return []
        }

        let data = try Data(contentsOf: storageURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([SetContext].self, from: data)
    }

    public func context(for sessionID: UUID) throws -> SetContext {
        try all().first { $0.sessionID == sessionID } ?? SetContext(sessionID: sessionID)
    }

    public func save(_ context: SetContext) throws {
        var contexts = try all()
        contexts.removeAll { $0.sessionID == context.sessionID }
        var updated = context
        updated.updatedAt = Date()
        contexts.append(updated)
        try write(contexts)
    }

    public func remove(sessionID: UUID) throws {
        var contexts = try all()
        contexts.removeAll { $0.sessionID == sessionID }
        try write(contexts)
    }

    private func write(_ contexts: [SetContext]) throws {
        try fileManager.createDirectory(
            at: storageURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(contexts.sorted { $0.updatedAt > $1.updatedAt })
        try data.write(to: storageURL, options: [.atomic])
    }
}

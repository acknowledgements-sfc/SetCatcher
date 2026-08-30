import Foundation

public struct ActivityLogStore {
    public let storageURL: URL
    private let fileManager: FileManager
    private let limit: Int

    public init(
        storageURL: URL = Self.defaultStorageURL(),
        fileManager: FileManager = .default,
        limit: Int = 200
    ) {
        self.storageURL = storageURL
        self.fileManager = fileManager
        self.limit = limit
    }

    public static func defaultStorageURL() -> URL {
        DefaultPathProvider().applicationSupportDirectory()
            .appendingPathComponent("activity-log.json")
    }

    public func all() throws -> [ActivityEvent] {
        guard fileManager.fileExists(atPath: storageURL.path) else {
            return []
        }

        let data = try Data(contentsOf: storageURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([ActivityEvent].self, from: data)
    }

    public func append(_ event: ActivityEvent) throws {
        let events = ([event] + (try all()))
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(limit)

        try write(Array(events))
    }

    public func clear() throws {
        try write([])
    }

    private func write(_ events: [ActivityEvent]) throws {
        try fileManager.createDirectory(
            at: storageURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(events)
        try data.write(to: storageURL, options: [.atomic])
    }
}

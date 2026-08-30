import Foundation

public struct ImportedTracklistStore {
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
            .appendingPathComponent("imported-tracklists.json")
    }

    public func all() throws -> [ImportedTracklist] {
        guard fileManager.fileExists(atPath: storageURL.path) else {
            return []
        }

        let data = try Data(contentsOf: storageURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([ImportedTracklist].self, from: data)
    }

    public func save(_ tracklist: ImportedTracklist) throws {
        var tracklists = try all()
        tracklists.removeAll { $0.appID == tracklist.appID && $0.sourceURL == tracklist.sourceURL }
        tracklists.append(tracklist)
        try write(tracklists)
    }

    public func remove(id: UUID) throws {
        var tracklists = try all()
        tracklists.removeAll { $0.id == id }
        try write(tracklists)
    }

    private func write(_ tracklists: [ImportedTracklist]) throws {
        try fileManager.createDirectory(
            at: storageURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(tracklists.sorted { $0.importedAt > $1.importedAt })
        try data.write(to: storageURL, options: [.atomic])
    }
}

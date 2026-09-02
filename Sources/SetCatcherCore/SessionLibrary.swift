import Foundation

public struct SessionLibrary {
    public let archiveRoot: URL
    private let archiveRootBookmarkData: Data?
    private let fileManager: FileManager

    public init(
        archiveRoot: URL = ArchiveService.defaultArchiveRoot(),
        archiveRootBookmarkData: Data? = nil,
        fileManager: FileManager = .default
    ) {
        self.archiveRoot = archiveRoot
        self.archiveRootBookmarkData = archiveRootBookmarkData
        self.fileManager = fileManager
    }

    public func archivedMetadata() throws -> [ArchiveMetadata] {
        try withSecurityScopedArchiveRoot {
            try archivedMetadataWithAccess()
        }
    }

    private func archivedMetadataWithAccess() throws -> [ArchiveMetadata] {
        guard fileManager.fileExists(atPath: archiveRoot.path) else {
            return []
        }

        let urls = try fileManager.contentsOfDirectory(
            at: archiveRoot,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        return urls
            .filter { $0.pathExtension.lowercased() == "json" }
            .compactMap { url -> ArchiveMetadata? in
                try? ArchiveMetadataMigration.loadRepaired(from: url, decoder: decoder, encoder: encoder)
            }
            .sorted { $0.detectedAt > $1.detectedAt }
    }

    private func withSecurityScopedArchiveRoot<T>(_ operation: () throws -> T) throws -> T {
        try SecurityScopedAccess.withScopedArchiveRootAccess(
            bookmarkData: archiveRootBookmarkData,
            operation: operation
        )
    }
}

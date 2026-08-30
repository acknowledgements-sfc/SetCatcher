import Foundation

public enum SetCatcherDataMigrationResult: Equatable, Sendable {
    case noLegacyData
    case migrated(applicationSupport: Bool, archive: Bool)
    case destinationExists(URL)
    case failed(String)

    public var isSuccessful: Bool {
        switch self {
        case .noLegacyData, .migrated:
            return true
        case .destinationExists, .failed:
            return false
        }
    }

    public var userMessage: String? {
        switch self {
        case .noLegacyData, .migrated:
            return nil
        case .destinationExists(let destination):
            return "SetCatcher found existing data at \(destination.path). Your older DJMemory data was left unchanged; choose a different archive location or move the folders after making a backup."
        case .failed(let reason):
            return "SetCatcher could not finish moving older DJMemory data. The original folders were kept. \(reason)"
        }
    }
}

/// Moves DJMemory-owned state into the SetCatcher locations during the first renamed launch.
/// Source recordings and user-selected recording folders are never touched by this migration.
public struct SetCatcherDataMigration {
    private let fileManager: FileManager
    private let homeDirectory: URL

    public init(
        fileManager: FileManager = .default,
        homeDirectory: URL = DefaultPathProvider().homeDirectory()
    ) {
        self.fileManager = fileManager
        self.homeDirectory = homeDirectory
    }

    public var legacyApplicationSupportURL: URL {
        homeDirectory
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("DJMemory", isDirectory: true)
    }

    public var destinationApplicationSupportURL: URL {
        homeDirectory
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("SetCatcher", isDirectory: true)
    }

    public var legacyArchiveURL: URL {
        homeDirectory
            .appendingPathComponent("Music", isDirectory: true)
            .appendingPathComponent("DJMemory", isDirectory: true)
    }

    public var destinationArchiveURL: URL {
        homeDirectory
            .appendingPathComponent("Music", isDirectory: true)
            .appendingPathComponent("SetCatcher", isDirectory: true)
    }

    public func run() -> SetCatcherDataMigrationResult {
        let pairs = [
            (legacyApplicationSupportURL, destinationApplicationSupportURL),
            (legacyArchiveURL, destinationArchiveURL)
        ]
        let existingPairs = pairs.filter { fileManager.fileExists(atPath: $0.0.path) }
        guard !existingPairs.isEmpty else { return .noLegacyData }

        if let collision = existingPairs.first(where: { fileManager.fileExists(atPath: $0.1.path) }) {
            return .destinationExists(collision.1)
        }

        var moved: [(source: URL, destination: URL)] = []
        do {
            for (source, destination) in existingPairs {
                try fileManager.createDirectory(
                    at: destination.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try fileManager.moveItem(at: source, to: destination)
                moved.append((source, destination))
            }

            let marker = destinationApplicationSupportURL.appendingPathComponent("migration-v1-complete", isDirectory: false)
            try Data("SetCatcher migration v1\n".utf8).write(to: marker, options: [.atomic])
            return .migrated(
                applicationSupport: existingPairs.contains { $0.0 == legacyApplicationSupportURL },
                archive: existingPairs.contains { $0.0 == legacyArchiveURL }
            )
        } catch {
            for pair in moved.reversed() {
                guard fileManager.fileExists(atPath: pair.destination.path),
                      !fileManager.fileExists(atPath: pair.source.path) else { continue }
                try? fileManager.moveItem(at: pair.destination, to: pair.source)
            }
            return .failed(error.localizedDescription)
        }
    }
}

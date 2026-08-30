import Foundation

public struct FileSnapshot: Equatable, Sendable {
    public let fileSize: Int64
    public let modificationDate: Date?

    public init(fileSize: Int64, modificationDate: Date?) {
        self.fileSize = fileSize
        self.modificationDate = modificationDate
    }
}

public struct FileStabilityChecker {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func snapshot(for url: URL) throws -> FileSnapshot {
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        return FileSnapshot(
            fileSize: Int64(values.fileSize ?? 0),
            modificationDate: values.contentModificationDate
        )
    }

    public func isStable(url: URL, previousSnapshot: FileSnapshot) throws -> Bool {
        try snapshot(for: url) == previousSnapshot
    }

    public func isAudioFile(_ url: URL) -> Bool {
        let audioExtensions = Set(["aif", "aiff", "flac", "m4a", "mp3", "wav"])
        return audioExtensions.contains(url.pathExtension.lowercased())
    }

    public func recentAudioFiles(
        in folderURL: URL,
        modifiedAfter cutoff: Date,
        stableBefore: Date? = nil
    ) throws -> [URL] {
        let urls = try fileManager.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        return try urls.filter { url in
            let values = try url.resourceValues(forKeys: [.contentModificationDateKey, .isDirectoryKey])
            guard values.isDirectory != true, isAudioFile(url) else { return false }
            let modificationDate = values.contentModificationDate ?? .distantPast
            guard modificationDate >= cutoff else { return false }

            if let stableBefore {
                return modificationDate <= stableBefore
            }

            return true
        }
        .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    public func recentUnstableAudioFiles(
        in folderURL: URL,
        modifiedAfter cutoff: Date,
        unstableAfter: Date
    ) throws -> [URL] {
        let urls = try recentAudioFiles(in: folderURL, modifiedAfter: cutoff)

        return try urls.filter { url in
            let values = try url.resourceValues(forKeys: [.contentModificationDateKey])
            return (values.contentModificationDate ?? .distantPast) > unstableAfter
        }
    }
}

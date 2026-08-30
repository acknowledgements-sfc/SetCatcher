import Foundation

public struct RecordingFolderScanner {
    private let stabilityChecker: FileStabilityChecker
    private let archiveService: ArchiveService

    public init(stabilityChecker: FileStabilityChecker = FileStabilityChecker(), archiveService: ArchiveService = ArchiveService()) {
        self.stabilityChecker = stabilityChecker
        self.archiveService = archiveService
    }

    public func archiveRecentStableFiles(
        in folderURL: URL,
        sourceAppID: String,
        modifiedAfter cutoff: Date,
        stableBefore: Date
    ) throws -> [RecordingSession] {
        let candidates = try stabilityChecker.recentAudioFiles(
            in: folderURL,
            modifiedAfter: cutoff,
            stableBefore: stableBefore
        )

        return try candidates.filter { url in
            !archiveService.isSourceAlreadyArchived(url)
        }.map { url in
            try archiveService.archive(sourceURL: url, sourceAppID: sourceAppID)
        }
    }

    public func recentUnstableFiles(
        in folderURL: URL,
        modifiedAfter cutoff: Date,
        unstableAfter: Date
    ) throws -> [URL] {
        try stabilityChecker.recentUnstableAudioFiles(
            in: folderURL,
            modifiedAfter: cutoff,
            unstableAfter: unstableAfter
        ).filter { url in
            !archiveService.isSourceAlreadyArchived(url)
        }
    }
}

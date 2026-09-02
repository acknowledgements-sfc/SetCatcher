import Foundation

public struct PerformanceGroup: Equatable, Sendable {
    public let id: UUID
    public let primary: ArchiveMetadata
    public let hardwareBackup: ArchiveMetadata?

    public init(id: UUID, primary: ArchiveMetadata, hardwareBackup: ArchiveMetadata?) {
        self.id = id
        self.primary = primary
        self.hardwareBackup = hardwareBackup
    }

    public var earliestDetectedAt: Date {
        min(primary.detectedAt, hardwareBackup?.detectedAt ?? primary.detectedAt)
    }
}

public enum PerformanceAttachment: Equatable, Sendable {
    case newPerformance
    case hardwareBackupAttached
    case primaryAttached(sourceAppID: String)
}

/// Groups a folder-protected recording and an overlapping Input Capture as one performance.
/// Does not read, move, rename, or delete audio files.
public enum PerformanceSessionLinker {
    public static let folderJoinSlack: TimeInterval = 15 * 60

    public static let folderProtectedAppIDs: Set<String> = [
        "serato",
        "rekordbox",
        "traktor",
        "virtualdj",
        "djay",
        SupportedDJSoftware.pioneerHardwareAppID,
        SupportedDJSoftware.denonHardwareAppID,
        SupportedDJSoftware.analogMixerAppID,
        SupportedDJSoftware.raneHardwareAppID
    ]

    public static func groups(from archives: [ArchiveMetadata]) -> [PerformanceGroup] {
        let captures = archives.filter(\.isCaptureLane)
        let folders = archives.filter {
            $0.ingestionKind == .folderWatch
                || (folderProtectedAppIDs.contains($0.sourceAppID) && !$0.isCaptureLane)
        }
        let leftovers = archives.filter {
            !$0.isCaptureLane && !folderProtectedAppIDs.contains($0.sourceAppID)
                && $0.ingestionKind != .folderWatch
        }

        var usedFolderIDs = Set<UUID>()
        var groups: [PerformanceGroup] = []

        for capture in captures.sorted(by: { $0.detectedAt < $1.detectedAt }) {
            let candidates = folders.filter { folder in
                !usedFolderIDs.contains(folder.sessionID) && isSamePerformance(capture: capture, folder: folder)
            }
            if let folder = bestFolder(for: capture, candidates: candidates) {
                usedFolderIDs.insert(folder.sessionID)
                groups.append(makeGroup(folder: folder, capture: capture))
            } else {
                groups.append(singleton(capture))
            }
        }

        for folder in folders where !usedFolderIDs.contains(folder.sessionID) {
            groups.append(singleton(folder))
        }

        for leftover in leftovers {
            groups.append(singleton(leftover))
        }

        return groups.sorted { lhs, rhs in
            if lhs.earliestDetectedAt != rhs.earliestDetectedAt {
                return lhs.earliestDetectedAt > rhs.earliestDetectedAt
            }
            return lhs.id.uuidString > rhs.id.uuidString
        }
    }

    public static func attachment(
        of newArchive: ArchiveMetadata,
        existing: [ArchiveMetadata]
    ) -> PerformanceAttachment {
        let grouped = groups(from: existing + [newArchive])
        guard let group = grouped.first(where: {
            $0.primary.sessionID == newArchive.sessionID
                || $0.hardwareBackup?.sessionID == newArchive.sessionID
        }) else {
            return .newPerformance
        }
        guard let backup = group.hardwareBackup else {
            return .newPerformance
        }
        if newArchive.sessionID == backup.sessionID {
            return .hardwareBackupAttached
        }
        if newArchive.sessionID == group.primary.sessionID {
            return .primaryAttached(sourceAppID: group.primary.sourceAppID)
        }
        return .newPerformance
    }

    private static func makeGroup(folder: ArchiveMetadata, capture: ArchiveMetadata) -> PerformanceGroup {
        let earliest = folder.detectedAt <= capture.detectedAt ? folder : capture
        return PerformanceGroup(id: earliest.sessionID, primary: folder, hardwareBackup: capture)
    }

    private static func singleton(_ archive: ArchiveMetadata) -> PerformanceGroup {
        PerformanceGroup(id: archive.sessionID, primary: archive, hardwareBackup: nil)
    }

    private static func isSamePerformance(capture: ArchiveMetadata, folder: ArchiveMetadata) -> Bool {
        if intervalsOverlap(capture: capture, folder: folder) {
            return true
        }
        let captureEnd = capture.completedAt ?? capture.detectedAt
        let windowEnd = captureEnd.addingTimeInterval(folderJoinSlack)
        return folder.detectedAt >= capture.detectedAt && folder.detectedAt <= windowEnd
    }

    private static func intervalsOverlap(capture: ArchiveMetadata, folder: ArchiveMetadata) -> Bool {
        let captureStart = capture.detectedAt
        let captureEnd = capture.completedAt ?? capture.detectedAt
        let folderEnd = folder.detectedAt
        let folderStart: Date
        if let duration = folder.durationSeconds, duration > 0 {
            folderStart = folderEnd.addingTimeInterval(-duration)
        } else {
            folderStart = folderEnd
        }
        return captureStart <= folderEnd && folderStart <= captureEnd
    }

    private static func bestFolder(for capture: ArchiveMetadata, candidates: [ArchiveMetadata]) -> ArchiveMetadata? {
        let captureEnd = capture.completedAt ?? capture.detectedAt
        return candidates.min { lhs, rhs in
            let lhsDelta = abs(lhs.detectedAt.timeIntervalSince(captureEnd))
            let rhsDelta = abs(rhs.detectedAt.timeIntervalSince(captureEnd))
            if lhsDelta != rhsDelta {
                return lhsDelta < rhsDelta
            }
            return primaryRank(lhs.sourceAppID) < primaryRank(rhs.sourceAppID)
        }
    }

    /// Lower is preferred: DJ-software folder, then Pioneer USB folder, then anything else.
    private static func primaryRank(_ sourceAppID: String) -> Int {
        if sourceAppID == SupportedDJSoftware.pioneerHardwareAppID { return 1 }
        if folderProtectedAppIDs.contains(sourceAppID) { return 0 }
        return 2
    }
}

import Foundation

public struct HistoryFolderIngest {
    public static let allowedExtensions: Set<String> = [
        "csv", "tsv", "txt", "xml", "nml", "m3u", "m3u8", "vdjfolder", "jsonl"
    ]

    public struct Candidate: Equatable, Sendable {
        public let url: URL
        public let modificationDate: Date

        public init(url: URL, modificationDate: Date) {
            self.url = url
            self.modificationDate = modificationDate
        }
    }

    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func candidateFiles(in directories: [URL]) -> [Candidate] {
        var results: [Candidate] = []
        for directory in directories {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory),
                  isDirectory.boolValue
            else { continue }

            guard let children = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for child in children {
                let ext = child.pathExtension.lowercased()
                guard Self.allowedExtensions.contains(ext) else { continue }
                let values = try? child.resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey])
                guard values?.isRegularFile == true else { continue }
                let modified = values?.contentModificationDate ?? .distantPast
                results.append(Candidate(url: child, modificationDate: modified))
            }
        }
        return results
    }

    public func bestCandidate(
        in directories: [URL],
        near referenceDate: Date,
        windowSeconds: TimeInterval = LibrarySessionMatcher.captureMatchWindowSeconds
    ) -> Candidate? {
        candidateFiles(in: directories)
            .filter { abs($0.modificationDate.timeIntervalSince(referenceDate)) <= windowSeconds }
            .min { lhs, rhs in
                abs(lhs.modificationDate.timeIntervalSince(referenceDate))
                    < abs(rhs.modificationDate.timeIntervalSince(referenceDate))
            }
    }

    public func historyDirectoryURLs(
        for appID: String,
        defaultHistoryPaths: [String],
        bookmarkedHistoryURLs: [URL],
        pathResolver: PathResolver = PathResolver()
    ) -> [URL] {
        var urls = pathResolver.existingURLs(from: defaultHistoryPaths)
        for bookmark in bookmarkedHistoryURLs {
            if !urls.contains(where: { $0.standardizedFileURL == bookmark.standardizedFileURL }) {
                urls.append(bookmark)
            }
        }
        return urls
    }
}

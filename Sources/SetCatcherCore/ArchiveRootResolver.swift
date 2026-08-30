import Foundation

public struct ArchiveRootResolution: Equatable, Sendable {
    public let url: URL
    /// Non-nil only when the bookmark resolves and is not stale.
    public let bookmarkData: Data?

    public init(url: URL, bookmarkData: Data?) {
        self.url = url
        self.bookmarkData = bookmarkData
    }
}

/// Resolves the archive root for CLI, tests, and other non-GUI callers.
/// Omits unresolvable GUI bookmarks instead of failing scoped access.
public enum ArchiveRootResolver {
    public static func resolve(settings: AppSettings) -> ArchiveRootResolution {
        if let path = ProcessInfo.processInfo.environment["SETCATCHER_ARCHIVE_ROOT"], !path.isEmpty {
            return ArchiveRootResolution(
                url: URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true),
                bookmarkData: nil
            )
        }

        if let bookmarkData = settings.archiveRootBookmarkData {
            var isStale = false
            if let url = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: SecurityScopedBookmarkOptions.resolve,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ), !isStale {
                return ArchiveRootResolution(url: url, bookmarkData: bookmarkData)
            }
        }

        if let archiveRootPath = settings.archiveRootPath, !archiveRootPath.isEmpty {
            return ArchiveRootResolution(
                url: URL(fileURLWithPath: (archiveRootPath as NSString).expandingTildeInPath, isDirectory: true),
                bookmarkData: nil
            )
        }

        return ArchiveRootResolution(
            url: ArchiveService.defaultArchiveRoot(),
            bookmarkData: nil
        )
    }
}

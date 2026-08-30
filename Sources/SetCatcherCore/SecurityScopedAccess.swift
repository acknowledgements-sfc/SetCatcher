import Foundation

public enum SecurityScopedAccessError: Error, Equatable {
    case resolveFailed
    case staleBookmark
}

/// Deep module for resolving and accessing security-scoped bookmarks.
/// Callers leverage one policy: stale bookmarks throw; missing resolve throws.
public enum SecurityScopedAccess {
    public static func resolve(bookmarkData: Data) throws -> URL {
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: SecurityScopedBookmarkOptions.resolve,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            throw SecurityScopedAccessError.resolveFailed
        }
        guard !isStale else {
            throw SecurityScopedAccessError.staleBookmark
        }
        return url
    }

    /// Resolves `bookmarkData` when present, starts scoped access, runs `operation`, then stops access.
    /// When `bookmarkData` is nil, runs `operation` with `fallbackURL` with no scoped access.
    public static func withScopedAccess<T>(
        bookmarkData: Data?,
        fallbackURL: URL,
        operation: (URL) throws -> T
    ) throws -> T {
        guard let bookmarkData else {
            return try operation(fallbackURL)
        }

        let url = try resolve(bookmarkData: bookmarkData)
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try operation(url)
    }

    /// Archive-root variant: scoped access around an operation that already knows the root path.
    /// When bookmark is missing, runs without scoped access. Stale/unresolvable bookmarks throw.
    public static func withScopedArchiveRootAccess<T>(
        bookmarkData: Data?,
        operation: () throws -> T
    ) throws -> T {
        guard let bookmarkData else {
            return try operation()
        }

        let url = try resolve(bookmarkData: bookmarkData)
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        _ = url
        return try operation()
    }

    /// Resolve-only helper that starts access and returns a stop closure. Caller must call `stop`.
    public static func beginScopedAccess(bookmarkData: Data) throws -> (url: URL, stop: () -> Void) {
        let url = try resolve(bookmarkData: bookmarkData)
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        return (url, {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        })
    }
}

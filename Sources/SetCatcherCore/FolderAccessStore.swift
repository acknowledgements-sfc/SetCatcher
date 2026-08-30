import Foundation

/// Outcome of resolving a saved folder bookmark for scanning / reachability.
public enum FolderAccessResolution: Equatable, Sendable {
    case reachable(URL)
    /// Bookmark exists but macOS reports it stale — user must choose the folder again.
    case staleBookmark(fallbackURL: URL)
    /// Path does not exist as a directory (or cannot be accessed under the sandbox).
    case unreachable(URL)

    public var url: URL {
        switch self {
        case .reachable(let url), .staleBookmark(let url), .unreachable(let url):
            return url
        }
    }

    public var isUsable: Bool {
        if case .reachable = self { return true }
        return false
    }
}

public struct FolderAccessStore {
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
            .appendingPathComponent("folder-access.json")
    }

    public func all() throws -> [FolderAccess] {
        guard fileManager.fileExists(atPath: storageURL.path) else {
            return []
        }

        let data = try Data(contentsOf: storageURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([FolderAccess].self, from: data)
    }

    public func folder(appID: String, kind: FolderKind) throws -> FolderAccess? {
        try all().first { $0.appID == appID && $0.kind == kind }
    }

    public func save(_ access: FolderAccess) throws {
        var records = try all()
        records.removeAll { $0.appID == access.appID && $0.kind == access.kind }
        records.append(access)
        try write(records)
    }

    public func remove(appID: String, kind: FolderKind) throws {
        var records = try all()
        records.removeAll { $0.appID == appID && $0.kind == kind }
        try write(records)
    }

    public func makeBookmarkData(for url: URL) throws -> Data {
        try url.bookmarkData(options: SecurityScopedBookmarkOptions.create, includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    /// Best-effort URL for display. Prefer `resolution(for:)` before scanning or watching.
    public func resolve(_ access: FolderAccess) -> URL {
        resolution(for: access).url
    }

    public func resolution(for access: FolderAccess) -> FolderAccessResolution {
        guard let bookmarkData = access.bookmarkData else {
            return directoryResolution(at: access.url)
        }

        do {
            return try SecurityScopedAccess.withScopedAccess(
                bookmarkData: bookmarkData,
                fallbackURL: access.url
            ) { url in
                directoryResolution(at: url)
            }
        } catch SecurityScopedAccessError.staleBookmark {
            return .staleBookmark(fallbackURL: access.url)
        } catch {
            return .unreachable(access.url)
        }
    }

    /// Resolve the bookmark with security scope, then check the path still exists as a directory (HANDOFF G3).
    public func isReachable(_ access: FolderAccess) -> Bool {
        resolution(for: access).isUsable
    }

    public func isBookmarkStale(_ access: FolderAccess) -> Bool {
        if case .staleBookmark = resolution(for: access) {
            return true
        }
        return false
    }

    private func directoryResolution(at url: URL) -> FolderAccessResolution {
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
            return .reachable(url)
        }
        return .unreachable(url)
    }

    private func write(_ records: [FolderAccess]) throws {
        try fileManager.createDirectory(
            at: storageURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(records.sorted { $0.createdAt < $1.createdAt })
        try data.write(to: storageURL, options: [.atomic])
    }
}

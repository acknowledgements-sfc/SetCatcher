import Foundation

public struct FolderScanRequest: Equatable, Sendable {
    public let appID: String
    public let folderURL: URL
    public let bookmarkData: Data?

    public init(appID: String, folderURL: URL, bookmarkData: Data? = nil) {
        self.appID = appID
        self.folderURL = folderURL
        self.bookmarkData = bookmarkData
    }

    /// Build scan requests from user-granted recordings folders only.
    /// Probe-discovered paths without a security-scoped bookmark are never scanned.
    public static func recordingRequests(
        from folderAccesses: [FolderAccess],
        resolve: (FolderAccess) -> URL
    ) -> [FolderScanRequest] {
        folderAccesses
            .filter { $0.kind == .recordings }
            .map { access in
                FolderScanRequest(
                    appID: access.appID,
                    folderURL: resolve(access),
                    bookmarkData: access.bookmarkData
                )
            }
    }

    /// Build watch requests from user-granted history folders.
    /// Used to keep imported tracklists fresh as late history exports land.
    public static func historyRequests(
        from folderAccesses: [FolderAccess],
        resolve: (FolderAccess) -> URL
    ) -> [FolderScanRequest] {
        folderAccesses
            .filter { $0.kind == .history }
            .map { access in
                FolderScanRequest(
                    appID: access.appID,
                    folderURL: resolve(access),
                    bookmarkData: access.bookmarkData
                )
            }
    }
}

public struct FolderScanResult: Equatable, Sendable {
    public let appID: String
    public let folderURL: URL
    public let archivedSessions: [RecordingSession]
    public let pendingRecordingURLs: [URL]
    public let errorDescription: String?

    public init(
        appID: String,
        folderURL: URL,
        archivedSessions: [RecordingSession],
        pendingRecordingURLs: [URL] = [],
        errorDescription: String?
    ) {
        self.appID = appID
        self.folderURL = folderURL
        self.archivedSessions = archivedSessions
        self.pendingRecordingURLs = pendingRecordingURLs
        self.errorDescription = errorDescription
    }
}

public struct ScanCoordinator {
    private let scanner: RecordingFolderScanner
    private let calendar: Calendar
    private let stabilityWindowSeconds: TimeInterval

    public init(
        scanner: RecordingFolderScanner = RecordingFolderScanner(),
        calendar: Calendar = .current,
        stabilityWindowSeconds: TimeInterval = 30
    ) {
        self.scanner = scanner
        self.calendar = calendar
        self.stabilityWindowSeconds = stabilityWindowSeconds
    }

    public func scanRecent(requests: [FolderScanRequest], hoursBack: Int = 24, now: Date = Date()) -> [FolderScanResult] {
        let cutoff = calendar.date(byAdding: .hour, value: -hoursBack, to: now) ?? .distantPast
        let stableBefore = now.addingTimeInterval(-stabilityWindowSeconds)

        return requests.map { request in
            do {
                let scan = try withSecurityScopedFolder(request) { folderURL in
                    let pending = try scanner.recentUnstableFiles(
                        in: folderURL,
                        modifiedAfter: cutoff,
                        unstableAfter: stableBefore
                    )
                    let archived = try scanner.archiveRecentStableFiles(
                        in: folderURL,
                        sourceAppID: request.appID,
                        modifiedAfter: cutoff,
                        stableBefore: stableBefore
                    )
                    return (pending: pending, archived: archived)
                }

                return FolderScanResult(
                    appID: request.appID,
                    folderURL: request.folderURL,
                    archivedSessions: scan.archived,
                    pendingRecordingURLs: scan.pending,
                    errorDescription: nil
                )
            } catch {
                return FolderScanResult(
                    appID: request.appID,
                    folderURL: request.folderURL,
                    archivedSessions: [],
                    errorDescription: scanErrorDescription(error, folderURL: request.folderURL)
                )
            }
        }
    }

    private func scanErrorDescription(_ error: Error, folderURL: URL) -> String {
        if case FolderScanAccessError.staleBookmark = error {
            return "Folder access expired. Choose the recording folder again in setup. Everything already in your archive is safe."
        }

        var isDirectory: ObjCBool = false
        let folderExists = FileManager.default.fileExists(atPath: folderURL.path, isDirectory: &isDirectory)

        if !folderExists {
            return "Recording folder was moved or deleted. Choose the folder again in setup."
        }

        if !isDirectory.boolValue {
            return "Saved recording folder points to a file. Choose the recording folder again in setup."
        }

        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain, nsError.code == NSFileReadNoPermissionError {
            return "SetCatcher cannot read this folder. Choose it again to refresh permission."
        }

        if nsError.domain == NSPOSIXErrorDomain, nsError.code == Int(EACCES) {
            return "SetCatcher cannot read this folder. Choose it again to refresh permission."
        }

        if case ArchiveServiceError.archiveDirectoryUnavailable = error {
            return "Archive folder is unavailable. Choose a different archive folder in Settings."
        }

        if nsError.domain == NSCocoaErrorDomain, nsError.code == NSFileWriteOutOfSpaceError {
            return "Archive folder does not have enough free space. Choose a drive with more space in Settings."
        }

        if nsError.domain == NSCocoaErrorDomain, nsError.code == NSFileWriteNoPermissionError {
            return "SetCatcher cannot write to the archive folder. Choose a different archive folder in Settings."
        }

        if let archiveError = error as? ArchiveServiceError {
            switch archiveError {
            case .copyVerificationFailed:
                return "The protected copy did not match the source recording. The incomplete copy was removed. Try scanning again. Source file was not changed."
            case .archiveDirectoryUnavailable:
                return "SetCatcher cannot write to the archive folder. Choose a different archive folder in Settings."
            case .sourceFileMissing, .sourceIsDirectory:
                break
            }
        }

        return "Could not scan this folder. Choose it again in setup. \(error.localizedDescription)"
    }

    private func withSecurityScopedFolder<T>(
        _ request: FolderScanRequest,
        operation: (URL) throws -> T
    ) throws -> T {
        guard let bookmarkData = request.bookmarkData else {
            return try operation(request.folderURL)
        }

        do {
            return try SecurityScopedAccess.withScopedAccess(
                bookmarkData: bookmarkData,
                fallbackURL: request.folderURL,
                operation: operation
            )
        } catch SecurityScopedAccessError.staleBookmark {
            throw FolderScanAccessError.staleBookmark(request.folderURL)
        } catch SecurityScopedAccessError.resolveFailed {
            throw CocoaError(.fileNoSuchFile)
        }
    }
}

public enum FolderScanAccessError: Error, Equatable {
    case staleBookmark(URL)
}

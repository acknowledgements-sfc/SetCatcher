import Darwin
import Dispatch
import Foundation
import DJMemoryCore

final class FolderChangeMonitor {
    private var watchedFolders: [WatchedFolder] = []
    /// Paths that successfully opened an FS event source (not merely requested).
    private var watchedPaths: Set<String> = []

    deinit {
        stop()
    }

    func start(requests: [FolderScanRequest], onChange: @escaping @Sendable () -> Void) {
        let uniqueRequests = uniqueReachableRequests(from: requests)

        // Decide *before* constructing any WatchedFolder: each init opens a file descriptor and
        // resumes a DispatchSource, so building them speculatively and discarding them on the
        // unchanged path leaked an fd + a live event source per folder, per call — and the
        // orphaned sources kept firing `onChange`, which re-entered this method and leaked more.
        let nextPaths = Set(uniqueRequests.map(\.folderURL.path))
        guard nextPaths != watchedPaths else {
            return
        }

        stop()
        watchedFolders = uniqueRequests.compactMap { request -> WatchedFolder? in
            WatchedFolder(request: request, onChange: onChange)
        }
        // Record what actually opened, not what was requested, so a folder that failed to open
        // is retried on the next call rather than being treated as already watched.
        watchedPaths = Set(watchedFolders.map(\.watchedPath))
    }

    func stop() {
        watchedFolders.forEach { $0.stop() }
        watchedFolders = []
        watchedPaths = []
    }

    /// Count of folders currently watched (for diagnostics / tests).
    var activeWatchCount: Int { watchedFolders.count }

    private func uniqueReachableRequests(from requests: [FolderScanRequest]) -> [FolderScanRequest] {
        var seenPaths = Set<String>()
        var usable: [FolderScanRequest] = []

        for request in requests {
            guard let resolved = Self.resolveWatchURL(for: request) else { continue }
            let path = resolved.path
            guard !seenPaths.contains(path) else { continue }

            var isDirectory: ObjCBool = false
            let started = resolved.startAccessingSecurityScopedResource()
            defer {
                if started {
                    resolved.stopAccessingSecurityScopedResource()
                }
            }
            guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
                  isDirectory.boolValue
            else {
                continue
            }

            seenPaths.insert(path)
            usable.append(
                FolderScanRequest(
                    appID: request.appID,
                    folderURL: resolved,
                    bookmarkData: request.bookmarkData
                )
            )
        }

        return usable
    }

    static func resolveWatchURL(for request: FolderScanRequest) -> URL? {
        guard let bookmarkData = request.bookmarkData else {
            return request.folderURL
        }
        return try? SecurityScopedAccess.resolve(bookmarkData: bookmarkData)
    }
}

private final class WatchedFolder {
    private let request: FolderScanRequest
    private let onChange: @Sendable () -> Void
    private let fileDescriptor: CInt
    private let source: DispatchSourceFileSystemObject
    private let securityScopedURL: URL?
    private let didStartAccessing: Bool
    private var isStopped = false
    let watchedPath: String

    init?(request: FolderScanRequest, onChange: @escaping @Sendable () -> Void) {
        self.request = request
        self.onChange = onChange

        var scopedURL: URL?
        var startedAccess = false
        let openURL: URL

        if let bookmarkData = request.bookmarkData {
            guard let url = try? SecurityScopedAccess.resolve(bookmarkData: bookmarkData) else {
                return nil
            }
            scopedURL = url
            startedAccess = url.startAccessingSecurityScopedResource()
            openURL = url
        } else {
            openURL = request.folderURL
        }

        let descriptor = open(openURL.path, O_EVTONLY)
        guard descriptor >= 0 else {
            if startedAccess {
                scopedURL?.stopAccessingSecurityScopedResource()
            }
            return nil
        }

        fileDescriptor = descriptor
        securityScopedURL = scopedURL
        didStartAccessing = startedAccess
        watchedPath = openURL.path

        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .extend, .attrib, .delete, .rename],
            queue: DispatchQueue.global(qos: .utility)
        )
        source.setEventHandler(handler: onChange)
        source.setCancelHandler {
            close(descriptor)
        }
        source.resume()
    }

    /// Backstop: a resumed DispatchSource is retained by libdispatch and keeps invoking its
    /// handler until cancelled, so a WatchedFolder that is dropped without `stop()` would leak
    /// its descriptor and go on firing. Cancelling here makes that unreachable by construction.
    deinit {
        stop()
    }

    /// Idempotent — safe to call from both the owner and `deinit`.
    func stop() {
        guard !isStopped else { return }
        isStopped = true
        source.cancel()
        if didStartAccessing {
            securityScopedURL?.stopAccessingSecurityScopedResource()
        }
    }
}

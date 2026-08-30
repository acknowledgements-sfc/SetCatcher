import Darwin
import Dispatch
import Foundation
import SetCatcherCore

final class FolderChangeMonitor {
    private var watchedFolders: [WatchedFolder] = []
    /// Paths that successfully opened an FS event source (not merely requested).
    private var watchedPaths: Set<String> = []

    deinit {
        stop()
    }

    func start(requests: [FolderScanRequest], onChange: @escaping @Sendable () -> Void) {
        let uniqueRequests = uniqueReachableRequests(from: requests)

        let startedFolders = uniqueRequests.compactMap { request -> WatchedFolder? in
            WatchedFolder(request: request, onChange: onChange)
        }
        let nextPaths = Set(startedFolders.map(\.watchedPath))

        guard nextPaths != watchedPaths else {
            return
        }

        stop()
        watchedFolders = startedFolders
        watchedPaths = nextPaths
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

    func stop() {
        source.cancel()
        if didStartAccessing {
            securityScopedURL?.stopAccessingSecurityScopedResource()
        }
    }
}

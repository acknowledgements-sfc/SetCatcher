import Foundation

struct CatalogDefaultPathReader: DJAppPathReading {
    private let resolver: PathResolver

    init(resolver: PathResolver = PathResolver()) {
        self.resolver = resolver
    }

    func readPaths(
        installation: DJSoftwareInstallation,
        software: DJSoftware,
        homeDirectory: URL,
        fileManager: FileManager
    ) -> [DiscoveredDJPath] {
        var paths: [DiscoveredDJPath] = []

        for url in resolver.existingURLs(from: software.defaultRecordingPaths) {
            paths.append(DiscoveredDJPath(kind: .recordings, url: url, source: .catalogDefault))
        }

        for url in resolver.existingURLs(from: software.defaultHistoryPaths) {
            paths.append(DiscoveredDJPath(kind: .history, url: url, source: .catalogDefault))
        }

        return paths
    }
}

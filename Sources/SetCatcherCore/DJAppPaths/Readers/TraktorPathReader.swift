import Foundation

struct TraktorPathReader: DJAppPathReading {
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

        for path in software.defaultRecordingPaths {
            let url = DJAppPathParsing.expandedPath(path, homeDirectory: homeDirectory)
            if fileManager.fileExists(atPath: url.path) {
                paths.append(DiscoveredDJPath(kind: .recordings, url: url, source: .catalogDefault))
            }
        }

        for url in resolver.existingURLs(from: software.defaultHistoryPaths) {
            paths.append(DiscoveredDJPath(kind: .history, url: url, source: .catalogDefault))
        }

        let settingsRoot = homeDirectory.appendingPathComponent("Documents/Native Instruments", isDirectory: true)
        if fileManager.fileExists(atPath: settingsRoot.path) {
            for (_, text) in DJAppPathParsing.readTextFiles(in: settingsRoot, fileManager: fileManager, maxDepth: 3) {
                if let value = DJAppPathParsing.firstMatch(
                    in: text,
                    patterns: [
                        #"<entry name="MixRecorder\.Path"[^>]*>([^<]+)</entry>"#,
                        #""MixRecorder\.Path"\s*:\s*"([^"]+)""#
                    ]
                ) {
                    let url = DJAppPathParsing.expandedPath(value, homeDirectory: homeDirectory)
                    if fileManager.fileExists(atPath: url.path) {
                        paths.append(
                            DiscoveredDJPath(
                                kind: .recordings,
                                url: url,
                                source: .userPreference,
                                note: "Traktor MixRecorder.Path"
                            )
                        )
                    }
                }
            }
        }

        return paths
    }
}

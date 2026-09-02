import Foundation

struct TraktorPathReader: DJAppPathReading {
    func readPaths(
        installation: DJSoftwareInstallation,
        software: DJSoftware,
        homeDirectory: URL,
        fileManager: FileManager
    ) -> [DiscoveredDJPath] {
        var paths: [DiscoveredDJPath] = []

        for path in software.defaultRecordingPaths {
            for url in DJAppPathParsing.existingDirectories(
                matching: path,
                homeDirectory: homeDirectory,
                fileManager: fileManager
            ) {
                paths.append(DiscoveredDJPath(kind: .recordings, url: url, source: .catalogDefault))
            }
        }

        for path in software.defaultHistoryPaths {
            for url in DJAppPathParsing.existingDirectories(
                matching: path,
                homeDirectory: homeDirectory,
                fileManager: fileManager
            ) {
                paths.append(DiscoveredDJPath(kind: .history, url: url, source: .catalogDefault))
            }
        }

        let settingsRoot = homeDirectory.appendingPathComponent("Documents/Native Instruments", isDirectory: true)
        // Only Traktor* product folders. Walking the whole NI tree reads Kontakt IRs and
        // other large files on the main thread during launch.
        let traktorSettingsRoots: [URL]
        if fileManager.fileExists(atPath: settingsRoot.path),
           let children = try? fileManager.contentsOfDirectory(
            at: settingsRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
           ) {
            traktorSettingsRoots = children.filter { child in
                child.lastPathComponent.lowercased().hasPrefix("traktor")
            }
        } else {
            traktorSettingsRoots = []
        }
        for settingsFolder in traktorSettingsRoots {
            for (_, text) in DJAppPathParsing.readTextFiles(in: settingsFolder, fileManager: fileManager, maxDepth: 3) {
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

import Foundation

struct CatalogDefaultPathReader: DJAppPathReading {
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

        return paths
    }
}

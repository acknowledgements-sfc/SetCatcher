import Foundation

struct DjayPathReader: DJAppPathReading {
    func readPaths(
        installation: DJSoftwareInstallation,
        software: DJSoftware,
        homeDirectory: URL,
        fileManager: FileManager
    ) -> [DiscoveredDJPath] {
        var paths: [DiscoveredDJPath] = []

        let containerRoot = homeDirectory
            .appendingPathComponent("Library/Containers", isDirectory: true)
        if let entries = try? fileManager.contentsOfDirectory(
            at: containerRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            for entry in entries where entry.lastPathComponent.contains("algoriddim") {
                let documents = entry.appendingPathComponent("Data/Documents", isDirectory: true)
                if let recordingPath = readRecordingPath(in: documents, fileManager: fileManager) {
                    paths.append(
                        DiscoveredDJPath(
                            kind: .recordings,
                            url: DJAppPathParsing.expandedPath(recordingPath, homeDirectory: homeDirectory),
                            source: .userPreference,
                            note: "djay container prefs"
                        )
                    )
                }
            }
        }

        for path in software.defaultRecordingPaths {
            let url = DJAppPathParsing.expandedPath(path, homeDirectory: homeDirectory)
            if fileManager.fileExists(atPath: url.path) {
                paths.append(DiscoveredDJPath(kind: .recordings, url: url, source: .catalogDefault))
            }
        }

        return paths
    }

    private func readRecordingPath(in documents: URL, fileManager: FileManager) -> String? {
        guard fileManager.fileExists(atPath: documents.path) else { return nil }
        for (_, text) in DJAppPathParsing.readTextFiles(in: documents, fileManager: fileManager, maxDepth: 2) {
            if let value = DJAppPathParsing.firstMatch(
                in: text,
                patterns: [
                    #"<key>recordingPath</key>\s*<string>([^<]+)</string>"#,
                    #""recordingPath"\s*:\s*"([^"]+)""#
                ]
            ) {
                return value
            }
        }
        return nil
    }
}

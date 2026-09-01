import Foundation

struct DenonEnginePathReader: DJAppPathReading {
    func readPaths(
        installation: DJSoftwareInstallation,
        software: DJSoftware,
        homeDirectory: URL,
        fileManager: FileManager
    ) -> [DiscoveredDJPath] {
        var paths: [DiscoveredDJPath] = []
        let supportCandidates = [
            homeDirectory.appendingPathComponent("Library/Application Support/Engine DJ", isDirectory: true),
            homeDirectory.appendingPathComponent("Library/Application Support/Denon DJ", isDirectory: true),
            homeDirectory.appendingPathComponent("Library/Application Support/Engine", isDirectory: true)
        ]

        for supportRoot in supportCandidates where fileManager.fileExists(atPath: supportRoot.path) {
            for (_, text) in DJAppPathParsing.readTextFiles(in: supportRoot, fileManager: fileManager) {
                if let value = DJAppPathParsing.firstMatch(
                    in: text,
                    patterns: [
                        #"<key>recordingPath</key>\s*<string>([^<]+)</string>"#,
                        #"<key>recordPath</key>\s*<string>([^<]+)</string>"#,
                        #""recordingPath"\s*:\s*"([^"]+)""#
                    ]
                ) {
                    let url = DJAppPathParsing.expandedPath(value, homeDirectory: homeDirectory)
                    paths.append(
                        DiscoveredDJPath(
                            kind: .recordings,
                            url: url,
                            source: .userPreference,
                            note: "Engine DJ prefs"
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

        for path in software.defaultHistoryPaths {
            let url = DJAppPathParsing.expandedPath(path, homeDirectory: homeDirectory)
            if fileManager.fileExists(atPath: url.path) {
                paths.append(DiscoveredDJPath(kind: .library, url: url, source: .catalogDefault))
            }
        }

        return paths
    }
}

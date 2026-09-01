import Foundation

struct VirtualDJPathReader: DJAppPathReading {
    func readPaths(
        installation: DJSoftwareInstallation,
        software: DJSoftware,
        homeDirectory: URL,
        fileManager: FileManager
    ) -> [DiscoveredDJPath] {
        var paths: [DiscoveredDJPath] = []
        let root = homeDirectory.appendingPathComponent("Documents/VirtualDJ", isDirectory: true)
        let settingsURL = root.appendingPathComponent("settings.xml")

        if let data = try? Data(contentsOf: settingsURL),
           let text = String(data: data, encoding: .utf8) {
            if let recordPath = DJAppPathParsing.firstMatch(
                in: text,
                patterns: [
                    #"<recordFolder>([^<]+)</recordFolder>"#,
                    #"<record>([^<]+)</record>"#,
                    #"<recordingFolder>([^<]+)</recordingFolder>"#
                ]
            ) {
                let url = DJAppPathParsing.expandedPath(recordPath, homeDirectory: homeDirectory)
                paths.append(
                    DiscoveredDJPath(
                        kind: .recordings,
                        url: url,
                        source: .userPreference,
                        note: "VirtualDJ settings.xml"
                    )
                )
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
                let kind: DJPathKind = path.contains("SetCatcherDrop") ? .pluginDrop : .history
                paths.append(DiscoveredDJPath(kind: kind, url: url, source: .catalogDefault))
            }
        }

        return paths
    }
}

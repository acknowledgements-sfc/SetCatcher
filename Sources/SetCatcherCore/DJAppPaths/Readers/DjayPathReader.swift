import Foundation

struct DjayPathReader: DJAppPathReading {
    func readPaths(
        installation: DJSoftwareInstallation,
        software: DJSoftware,
        homeDirectory: URL,
        fileManager: FileManager
    ) -> [DiscoveredDJPath] {
        var paths: [DiscoveredDJPath] = []

        // Never open files under ~/Library/Containers. Those containers are
        // file-provider backed; Data(contentsOf:) / directory listing hangs
        // launch on the main thread.
        var bundleIDs: [String] = software.bundleIdentifiers
        if !bundleIDs.contains(installation.bundleIdentifier) {
            bundleIDs.insert(installation.bundleIdentifier, at: 0)
        }
        for bundleID in bundleIDs {
            if let recordingPath = readRecordingPath(
                bundleID: bundleID,
                homeDirectory: homeDirectory,
                fileManager: fileManager
            ) {
                paths.append(
                    DiscoveredDJPath(
                        kind: .recordings,
                        url: DJAppPathParsing.expandedPath(recordingPath, homeDirectory: homeDirectory),
                        source: .userPreference,
                        note: "djay container prefs"
                    )
                )
                break
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

    private func readRecordingPath(
        bundleID: String,
        homeDirectory: URL,
        fileManager: FileManager
    ) -> String? {
        let url = homeDirectory
            .appendingPathComponent("Library/Preferences", isDirectory: true)
            .appendingPathComponent("\(bundleID).plist", isDirectory: false)
        return recordingPath(fromPlist: url, fileManager: fileManager)
    }

    private func recordingPath(fromPlist url: URL, fileManager: FileManager) -> String? {
        guard fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              data.count <= 512_000
        else { return nil }

        if let obj = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
           let value = obj["recordingPath"] as? String,
           !value.isEmpty
        {
            return value
        }

        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            return nil
        }
        return DJAppPathParsing.firstMatch(
            in: text,
            patterns: [
                #"<key>recordingPath</key>\s*<string>([^<]+)</string>"#,
                #""recordingPath"\s*:\s*"([^"]+)""#
            ]
        )
    }
}

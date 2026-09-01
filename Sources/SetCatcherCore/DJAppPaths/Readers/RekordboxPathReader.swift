import Foundation

struct RekordboxPathReader: DJAppPathReading {
    func readPaths(
        installation: DJSoftwareInstallation,
        software: DJSoftware,
        homeDirectory: URL,
        fileManager: FileManager
    ) -> [DiscoveredDJPath] {
        var paths: [DiscoveredDJPath] = []

        if let recordingPath = readRecordingPath(
            installation: installation,
            homeDirectory: homeDirectory,
            fileManager: fileManager
        ) {
            paths.append(
                DiscoveredDJPath(
                    kind: .recordings,
                    url: DJAppPathParsing.expandedPath(recordingPath, homeDirectory: homeDirectory),
                    source: .userPreference,
                    note: "rekordbox prefs"
                )
            )
        }

        paths.append(contentsOf: catalogPaths(for: software, homeDirectory: homeDirectory, fileManager: fileManager))
        return paths
    }

    private func readRecordingPath(
        installation: DJSoftwareInstallation,
        homeDirectory: URL,
        fileManager: FileManager
    ) -> String? {
        let preferenceKeys = ["recordingPath", "recordPath", "recordFolder", "recordingFolder"]
        let bundleIdentifiers = [installation.bundleIdentifier, "com.pioneerdj.rekordboxdj", "com.pioneerdj.rekordbox"]
        for bundleIdentifier in bundleIdentifiers {
            for key in preferenceKeys {
                if let value = DJAppPathParsing.preferencesStringValue(
                    forKey: key,
                    bundleIdentifier: bundleIdentifier,
                    homeDirectory: homeDirectory,
                    fileManager: fileManager
                ) {
                    return value
                }
            }
        }

        let supportRoot = homeDirectory
            .appendingPathComponent("Library/Application Support/rekordbox", isDirectory: true)
        return readRecordingPathFromApplicationSupport(in: supportRoot, fileManager: fileManager)
    }

    private func readRecordingPathFromApplicationSupport(in supportRoot: URL, fileManager: FileManager) -> String? {
        guard fileManager.fileExists(atPath: supportRoot.path) else { return nil }

        let patterns = [
            #"<key>recordingPath</key>\s*<string>([^<]+)</string>"#,
            #"<key>recordPath</key>\s*<string>([^<]+)</string>"#,
            #""recordingPath"\s*:\s*"([^"]+)""#,
            #"recordingPath\s*=\s*([^\n;]+)"#
        ]

        for (_, text) in DJAppPathParsing.readTextFiles(in: supportRoot, fileManager: fileManager) {
            if let value = DJAppPathParsing.firstMatch(in: text, patterns: patterns) {
                return value
            }
        }
        return nil
    }

    private func catalogPaths(
        for software: DJSoftware,
        homeDirectory: URL,
        fileManager: FileManager
    ) -> [DiscoveredDJPath] {
        var paths: [DiscoveredDJPath] = []
        let defaults = software.defaultRecordingPaths.isEmpty
            ? ["~/Music/rekordbox/Recorded"]
            : software.defaultRecordingPaths

        for path in defaults {
            let url = DJAppPathParsing.expandedPath(path, homeDirectory: homeDirectory)
            if fileManager.fileExists(atPath: url.path) {
                paths.append(DiscoveredDJPath(kind: .recordings, url: url, source: .catalogDefault))
            }
        }
        return paths
    }
}

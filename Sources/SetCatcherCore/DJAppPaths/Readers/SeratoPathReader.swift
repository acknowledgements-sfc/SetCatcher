import Foundation

struct SeratoPathReader: DJAppPathReading {
    func readPaths(
        installation: DJSoftwareInstallation,
        software: DJSoftware,
        homeDirectory: URL,
        fileManager: FileManager
    ) -> [DiscoveredDJPath] {
        var paths: [DiscoveredDJPath] = []

        if let recordLocation = readRecordLocation(
            installation: installation,
            homeDirectory: homeDirectory,
            fileManager: fileManager
        ) {
            let recordingsURL = DJAppPathParsing.expandedPath(recordLocation, homeDirectory: homeDirectory)
            paths.append(
                DiscoveredDJPath(
                    kind: .recordings,
                    url: recordingsURL,
                    source: .userPreference,
                    note: "Serato prefs record_location (\(installation.bundleIdentifier))"
                )
            )

            let tempURL = recordingsURL
                .deletingLastPathComponent()
                .appendingPathComponent("Recording temp", isDirectory: true)
            if fileManager.fileExists(atPath: tempURL.path) {
                paths.append(
                    DiscoveredDJPath(
                        kind: .tempRecordings,
                        url: tempURL,
                        source: .userPreference,
                        note: "Serato temp recordings beside record_location"
                    )
                )
            }
        }

        paths.append(contentsOf: catalogPaths(for: software, homeDirectory: homeDirectory, fileManager: fileManager))
        return paths
    }

    private func readRecordLocation(
        installation: DJSoftwareInstallation,
        homeDirectory: URL,
        fileManager: FileManager
    ) -> String? {
        if let value = DJAppPathParsing.preferencesStringValue(
            forKey: "record_location",
            bundleIdentifier: installation.bundleIdentifier,
            homeDirectory: homeDirectory,
            fileManager: fileManager
        ) {
            return value
        }

        for bundleIdentifier in ["com.serato.seratodj", "com.serato.dj"] where bundleIdentifier != installation.bundleIdentifier {
            if let value = DJAppPathParsing.preferencesStringValue(
                forKey: "record_location",
                bundleIdentifier: bundleIdentifier,
                homeDirectory: homeDirectory,
                fileManager: fileManager
            ) {
                return value
            }
        }

        let supportRoot = homeDirectory
            .appendingPathComponent("Library/Application Support/Serato", isDirectory: true)
        return readRecordLocationFromApplicationSupport(in: supportRoot, fileManager: fileManager)
    }

    private func readRecordLocationFromApplicationSupport(in supportRoot: URL, fileManager: FileManager) -> String? {
        guard fileManager.fileExists(atPath: supportRoot.path) else { return nil }

        for (_, text) in DJAppPathParsing.readTextFiles(in: supportRoot, fileManager: fileManager) {
            if let value = DJAppPathParsing.firstMatch(
                in: text,
                patterns: [
                    #"<key>record_location</key>\s*<string>([^<]+)</string>"#,
                    #""record_location"\s*:\s*"([^"]+)""#,
                    #"record_location\s*=\s*([^\n;]+)"#
                ]
            ) {
                return value
            }
        }

        for case let fileURL as URL in (try? fileManager.contentsOfDirectory(
            at: supportRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? [] {
            guard let data = try? Data(contentsOf: fileURL),
                  let value = DJAppPathParsing.plistStringValue(forKey: "record_location", in: data)
            else { continue }
            return value
        }

        return nil
    }

    private func catalogPaths(
        for software: DJSoftware,
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
        for path in software.defaultHistoryPaths {
            let url = DJAppPathParsing.expandedPath(path, homeDirectory: homeDirectory)
            if fileManager.fileExists(atPath: url.path) {
                paths.append(DiscoveredDJPath(kind: .history, url: url, source: .catalogDefault))
            }
        }
        return paths
    }
}

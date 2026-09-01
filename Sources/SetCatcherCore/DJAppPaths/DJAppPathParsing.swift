import Foundation

enum DJAppPathParsing {
    static func expandedPath(_ raw: String, homeDirectory: URL) -> URL {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("~") {
            return URL(fileURLWithPath: (trimmed as NSString).expandingTildeInPath, isDirectory: true)
        }
        if trimmed.hasPrefix("/") {
            return URL(fileURLWithPath: trimmed, isDirectory: true)
        }
        return homeDirectory.appendingPathComponent(trimmed, isDirectory: true)
    }

    static func firstMatch(in text: String, patterns: [String]) -> String? {
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            guard let match = regex.firstMatch(in: text, options: [], range: range),
                  match.numberOfRanges > 1,
                  let capture = Range(match.range(at: 1), in: text)
            else { continue }
            let value = String(text[capture]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty {
                return value
            }
        }
        return nil
    }

    static func readTextFiles(
        in directory: URL,
        fileManager: FileManager,
        maxDepth: Int = 2
    ) -> [(URL, String)] {
        guard maxDepth >= 0 else { return [] }
        guard let entries = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var results: [(URL, String)] = []
        for entry in entries {
            let values = try? entry.resourceValues(forKeys: [.isDirectoryKey])
            if values?.isDirectory == true {
                results.append(contentsOf: readTextFiles(in: entry, fileManager: fileManager, maxDepth: maxDepth - 1))
                continue
            }

            let ext = entry.pathExtension.lowercased()
            guard ["xml", "plist", "prefs", "txt", "json"].contains(ext) || ext.isEmpty else { continue }
            guard let data = try? Data(contentsOf: entry),
                  let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
            else { continue }
            results.append((entry, text))
        }
        return results
    }

    static func plistStringValue(forKey key: String, in data: Data) -> String? {
        guard let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) else {
            return nil
        }
        if let dictionary = plist as? [String: Any], let value = dictionary[key] as? String {
            return value
        }
        return nil
    }

    /// Per-user macOS preferences plist for a bundle identifier.
    static func userPreferencesURL(homeDirectory: URL, bundleIdentifier: String) -> URL {
        homeDirectory
            .appendingPathComponent("Library/Preferences", isDirectory: true)
            .appendingPathComponent("\(bundleIdentifier).plist")
    }

    /// Read a string from the current user's `~/Library/Preferences/<bundleID>.plist`.
    static func preferencesStringValue(
        forKey key: String,
        bundleIdentifier: String,
        homeDirectory: URL,
        fileManager: FileManager
    ) -> String? {
        let url = userPreferencesURL(homeDirectory: homeDirectory, bundleIdentifier: bundleIdentifier)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return plistStringValue(forKey: key, in: data)
    }
}

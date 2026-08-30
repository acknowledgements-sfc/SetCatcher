import Foundation

public struct PathResolver {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func expandedURL(for path: String) -> URL {
        let expanded = (path as NSString).expandingTildeInPath
        return URL(fileURLWithPath: expanded)
    }

    public func existingURLs(from paths: [String]) -> [URL] {
        paths
            .flatMap(existingURLs(for:))
    }

    private func existingURLs(for path: String) -> [URL] {
        let components = expandedURL(for: path).pathComponents
        let matches = matchingURLs(components: Array(components.dropFirst()), roots: [URL(fileURLWithPath: "/")])
        return matches.filter { fileManager.fileExists(atPath: $0.path) }
    }

    private func matchingURLs(components: [String], roots: [URL]) -> [URL] {
        guard let component = components.first else {
            return roots
        }

        let remaining = Array(components.dropFirst())

        if component.contains("*") {
            return roots.flatMap { root in
                wildcardChildren(in: root, matching: component)
            }.flatMap { match in
                matchingURLs(components: remaining, roots: [match])
            }
        }

        return matchingURLs(
            components: remaining,
            roots: roots.map { $0.appendingPathComponent(component) }
        )
    }

    private func wildcardChildren(in root: URL, matching pattern: String) -> [URL] {
        guard let children = try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let regexPattern = "^" + NSRegularExpression.escapedPattern(for: pattern)
            .replacingOccurrences(of: "\\*", with: ".*") + "$"

        return children.filter { child in
            child.lastPathComponent.range(of: regexPattern, options: [.regularExpression, .caseInsensitive]) != nil
        }
    }
}

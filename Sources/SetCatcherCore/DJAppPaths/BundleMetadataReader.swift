import Foundation

public struct BundleMetadata: Equatable, Sendable {
    public let bundleIdentifier: String
    public let displayName: String?
    public let shortVersion: String?
    public let bundleURL: URL

    public init(bundleIdentifier: String, displayName: String?, shortVersion: String?, bundleURL: URL) {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.shortVersion = shortVersion
        self.bundleURL = bundleURL
    }
}

public struct BundleMetadataReader {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func read(bundleURL: URL) -> BundleMetadata? {
        guard let bundle = Bundle(url: bundleURL) else { return nil }
        guard let bundleIdentifier = bundle.bundleIdentifier, !bundleIdentifier.isEmpty else { return nil }

        let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
        let shortVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String

        return BundleMetadata(
            bundleIdentifier: bundleIdentifier,
            displayName: displayName,
            shortVersion: shortVersion?.isEmpty == true ? nil : shortVersion,
            bundleURL: bundleURL
        )
    }
}

import Foundation

public struct DJPathDiscovery {
    private let pathProvider: PathProviding
    private let fileManager: FileManager
    private let readers: [String: any DJAppPathReading]

    public init(
        pathProvider: PathProviding = DefaultPathProvider(),
        fileManager: FileManager = .default,
        readers: [String: any DJAppPathReading]? = nil
    ) {
        self.pathProvider = pathProvider
        self.fileManager = fileManager
        self.readers = readers ?? Self.defaultReaders()
    }

    public func discoverInstallations(
        for software: DJSoftware,
        installedApplicationURLs: [URL],
        runningBundleIdentifiers: Set<String>
    ) -> [DJSoftwareInstallation] {
        guard !software.bundleIdentifiers.isEmpty else { return [] }

        var installations: [DJSoftwareInstallation] = []
        let metadataReader = BundleMetadataReader(fileManager: fileManager)
        let homeDirectory = pathProvider.homeDirectory()

        for appURL in installedApplicationURLs {
            guard let metadata = metadataReader.read(bundleURL: appURL) else { continue }

            if software.id == "traktor",
               !DJSoftwareVariantCatalog.isSupportedTraktorInstallation(
                   bundleIdentifier: metadata.bundleIdentifier,
                   shortVersion: metadata.shortVersion
               ) {
                continue
            }

            let variantLabel = DJSoftwareVariantCatalog.variantLabel(
                familyID: software.id,
                bundleIdentifier: metadata.bundleIdentifier,
                shortVersion: metadata.shortVersion
            )

            let installation = DJSoftwareInstallation(
                familyID: software.id,
                variantLabel: variantLabel,
                bundleIdentifier: metadata.bundleIdentifier,
                bundleVersion: metadata.shortVersion,
                appURL: appURL,
                isRunning: runningBundleIdentifiers.contains(metadata.bundleIdentifier),
                discoveredPaths: []
            )

            let reader = readers[software.id] ?? CatalogDefaultPathReader()
            let rawPaths = reader.readPaths(
                installation: installation,
                software: software,
                homeDirectory: homeDirectory,
                fileManager: fileManager
            )

            installations.append(
                DJSoftwareInstallation(
                    familyID: installation.familyID,
                    variantLabel: installation.variantLabel,
                    bundleIdentifier: installation.bundleIdentifier,
                    bundleVersion: installation.bundleVersion,
                    appURL: installation.appURL,
                    isRunning: installation.isRunning,
                    discoveredPaths: Self.merge(rawPaths: rawPaths, fileManager: fileManager)
                )
            )
        }

        return installations
    }

    public func discoverFamilyDefaults(for software: DJSoftware) -> [DiscoveredDJPath] {
        let reader = readers[software.id] ?? CatalogDefaultPathReader()
        let placeholder = DJSoftwareInstallation(
            familyID: software.id,
            variantLabel: software.displayName,
            bundleIdentifier: software.bundleIdentifiers.first ?? software.id,
            bundleVersion: nil,
            appURL: URL(fileURLWithPath: "/"),
            isRunning: false,
            discoveredPaths: []
        )
        let rawPaths = reader.readPaths(
            installation: placeholder,
            software: software,
            homeDirectory: pathProvider.homeDirectory(),
            fileManager: fileManager
        )
        return Self.merge(rawPaths: rawPaths, fileManager: fileManager)
    }

    public static func merge(rawPaths: [DiscoveredDJPath], fileManager: FileManager) -> [DiscoveredDJPath] {
        var bestByKey: [String: DiscoveredDJPath] = [:]

        for path in rawPaths {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: path.url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                continue
            }

            let key = "\(path.kind.rawValue)|\(path.url.standardizedFileURL.path)"
            if let existing = bestByKey[key] {
                if sourceRank(path.source) < sourceRank(existing.source) {
                    bestByKey[key] = path
                }
            } else {
                bestByKey[key] = path
            }
        }

        return bestByKey.values.sorted { lhs, rhs in
            if lhs.kind != rhs.kind {
                return lhs.kind.rawValue < rhs.kind.rawValue
            }
            return lhs.url.path < rhs.url.path
        }
    }

    private static func sourceRank(_ source: DJPathSource) -> Int {
        switch source {
        case .userPreference:
            return 0
        case .catalogDefault:
            return 1
        case .filesystemProbe:
            return 2
        }
    }

    private static func defaultReaders() -> [String: any DJAppPathReading] {
        [
            "serato": SeratoPathReader(),
            "rekordbox": RekordboxPathReader(),
            "traktor": TraktorPathReader(),
            "virtualdj": VirtualDJPathReader(),
            "djay": DjayPathReader(),
            "denon-engine": DenonEnginePathReader()
        ]
    }
}

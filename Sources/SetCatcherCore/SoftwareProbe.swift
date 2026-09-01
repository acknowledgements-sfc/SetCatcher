#if os(macOS)
import AppKit
#endif
import Foundation

public struct SoftwareProbeResult: Codable, Equatable, Sendable {
    public let software: DJSoftware
    public let installations: [DJSoftwareInstallation]
    public let familyDiscoveredPaths: [DiscoveredDJPath]

    public init(
        software: DJSoftware,
        installations: [DJSoftwareInstallation] = [],
        familyDiscoveredPaths: [DiscoveredDJPath] = []
    ) {
        self.software = software
        self.installations = installations
        self.familyDiscoveredPaths = familyDiscoveredPaths
    }

    /// Preview/test helper that builds probe state from legacy flat fields.
    public init(
        software: DJSoftware,
        installedApplicationURLs: [URL],
        runningApplicationBundleIdentifiers: [String],
        existingRecordingURLs: [URL],
        existingHistoryURLs: [URL]
    ) {
        self.software = software
        let running = Set(runningApplicationBundleIdentifiers)
        let discoveredPaths: [DiscoveredDJPath] = existingRecordingURLs.map {
            DiscoveredDJPath(kind: .recordings, url: $0, source: .catalogDefault)
        } + existingHistoryURLs.map {
            DiscoveredDJPath(kind: .history, url: $0, source: .catalogDefault)
        }

        if !installedApplicationURLs.isEmpty {
            self.installations = installedApplicationURLs.enumerated().map { index, appURL in
                let bundleIdentifier = software.bundleIdentifiers.indices.contains(index)
                    ? software.bundleIdentifiers[index]
                    : (software.bundleIdentifiers.first ?? software.id)
                return DJSoftwareInstallation(
                    familyID: software.id,
                    variantLabel: DJSoftwareVariantCatalog.variantLabel(
                        familyID: software.id,
                        bundleIdentifier: bundleIdentifier,
                        shortVersion: nil
                    ),
                    bundleIdentifier: bundleIdentifier,
                    bundleVersion: nil,
                    appURL: appURL,
                    isRunning: running.contains(bundleIdentifier),
                    discoveredPaths: discoveredPaths
                )
            }
        } else if !running.isEmpty {
            self.installations = runningApplicationBundleIdentifiers.map { bundleIdentifier in
                DJSoftwareInstallation(
                    familyID: software.id,
                    variantLabel: DJSoftwareVariantCatalog.variantLabel(
                        familyID: software.id,
                        bundleIdentifier: bundleIdentifier,
                        shortVersion: nil
                    ),
                    bundleIdentifier: bundleIdentifier,
                    bundleVersion: nil,
                    appURL: URL(fileURLWithPath: "/Applications/\(bundleIdentifier).app"),
                    isRunning: true,
                    discoveredPaths: discoveredPaths
                )
            }
        } else {
            self.installations = []
        }

        self.familyDiscoveredPaths = installations.isEmpty ? discoveredPaths : []
    }

    public var installedApplicationURLs: [URL] {
        installations.map(\.appURL)
    }

    public var runningApplicationBundleIdentifiers: [String] {
        installations.filter(\.isRunning).map(\.bundleIdentifier)
    }

    public var existingRecordingURLs: [URL] {
        let fromInstallations = installations.flatMap { $0.paths(ofKind: .recordings) }
        if !fromInstallations.isEmpty {
            return deduplicatedURLs(fromInstallations)
        }
        return deduplicatedURLs(
            familyDiscoveredPaths
                .filter { $0.kind == .recordings }
                .map(\.url)
        )
    }

    public var existingHistoryURLs: [URL] {
        let fromInstallations = installations.flatMap { $0.paths(ofKind: .history) }
        if !fromInstallations.isEmpty {
            return deduplicatedURLs(fromInstallations)
        }
        return deduplicatedURLs(
            familyDiscoveredPaths
                .filter { $0.kind == .history }
                .map(\.url)
        )
    }

    public var status: String {
        if !runningApplicationBundleIdentifiers.isEmpty {
            return "running"
        }

        if !installedApplicationURLs.isEmpty {
            return "installed"
        }

        if !existingRecordingURLs.isEmpty || !existingHistoryURLs.isEmpty {
            return "folders-found"
        }

        return "not-found"
    }

    public var isRunning: Bool {
        !runningApplicationBundleIdentifiers.isEmpty
    }

    public var isInstalled: Bool {
        !installedApplicationURLs.isEmpty
    }

    /// First-run presence label. Running wins over installed; a found folder is not "Installed".
    public var onboardingPresenceLabel: String {
        switch status {
        case "running":
            return "Running"
        case "installed":
            return "Installed"
        case "folders-found":
            return "Recording folder found"
        default:
            return "Not installed"
        }
    }

    private func deduplicatedURLs(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()
        return urls.filter { url in
            let key = url.standardizedFileURL.path
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
    }
}

public struct SoftwareProbe {
    #if os(macOS)
    private let workspace: NSWorkspace
    #endif
    private let resolver: PathResolver
    private let pathDiscovery: DJPathDiscovery

    #if os(macOS)
    public init(
        workspace: NSWorkspace = .shared,
        resolver: PathResolver = PathResolver(),
        pathDiscovery: DJPathDiscovery = DJPathDiscovery()
    ) {
        self.workspace = workspace
        self.resolver = resolver
        self.pathDiscovery = pathDiscovery
    }
    #else
    public init(
        resolver: PathResolver = PathResolver(),
        pathDiscovery: DJPathDiscovery = DJPathDiscovery()
    ) {
        self.resolver = resolver
        self.pathDiscovery = pathDiscovery
    }
    #endif

    public func probe(_ software: DJSoftware) -> SoftwareProbeResult {
        #if os(macOS)
        let appURLs = software.bundleIdentifiers.compactMap { workspace.urlForApplication(withBundleIdentifier: $0) }
        let runningBundleIDs = Set(workspace.runningApplications.compactMap(\.bundleIdentifier))
        let installations = pathDiscovery.discoverInstallations(
            for: software,
            installedApplicationURLs: appURLs,
            runningBundleIdentifiers: runningBundleIDs
        )
        let familyDiscoveredPaths = installations.isEmpty
            ? pathDiscovery.discoverFamilyDefaults(for: software)
            : []

        return SoftwareProbeResult(
            software: software,
            installations: installations,
            familyDiscoveredPaths: familyDiscoveredPaths
        )
        #else
        SoftwareProbeResult(software: software, installations: [])
        #endif
    }

    public func probeAll() -> [SoftwareProbeResult] {
        SupportedDJSoftware.all.map(probe(_:))
    }
}

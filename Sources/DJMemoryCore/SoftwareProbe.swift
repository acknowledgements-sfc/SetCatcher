#if os(macOS)
import AppKit
#endif
import Foundation

public struct SoftwareProbeResult: Codable, Equatable, Sendable {
    public let software: DJSoftware
    public let installedApplicationURLs: [URL]
    public let runningApplicationBundleIdentifiers: [String]
    public let existingRecordingURLs: [URL]
    public let existingHistoryURLs: [URL]

    public init(
        software: DJSoftware,
        installedApplicationURLs: [URL],
        runningApplicationBundleIdentifiers: [String],
        existingRecordingURLs: [URL],
        existingHistoryURLs: [URL]
    ) {
        self.software = software
        self.installedApplicationURLs = installedApplicationURLs
        self.runningApplicationBundleIdentifiers = runningApplicationBundleIdentifiers
        self.existingRecordingURLs = existingRecordingURLs
        self.existingHistoryURLs = existingHistoryURLs
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
}

public struct SoftwareProbe {
    #if os(macOS)
    private let workspace: NSWorkspace
    #endif
    private let resolver: PathResolver

    #if os(macOS)
    public init(workspace: NSWorkspace = .shared, resolver: PathResolver = PathResolver()) {
        self.workspace = workspace
        self.resolver = resolver
    }
    #else
    public init(resolver: PathResolver = PathResolver()) {
        self.resolver = resolver
    }
    #endif

    public func probe(_ software: DJSoftware) -> SoftwareProbeResult {
        #if os(macOS)
        let appURLs = software.bundleIdentifiers.compactMap { workspace.urlForApplication(withBundleIdentifier: $0) }
        let runningBundleIDs = Set(workspace.runningApplications.compactMap(\.bundleIdentifier))
        let runningMatches = software.bundleIdentifiers.filter { runningBundleIDs.contains($0) }

        return SoftwareProbeResult(
            software: software,
            installedApplicationURLs: appURLs,
            runningApplicationBundleIdentifiers: runningMatches,
            existingRecordingURLs: resolver.existingURLs(from: software.defaultRecordingPaths),
            existingHistoryURLs: resolver.existingURLs(from: software.defaultHistoryPaths)
        )
        #else
        SoftwareProbeResult(
            software: software,
            installedApplicationURLs: [],
            runningApplicationBundleIdentifiers: [],
            existingRecordingURLs: [],
            existingHistoryURLs: []
        )
        #endif
    }

    public func probeAll() -> [SoftwareProbeResult] {
        SupportedDJSoftware.all.map(probe(_:))
    }
}

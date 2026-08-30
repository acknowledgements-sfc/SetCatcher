import Foundation

public struct DiagnosticsReport: Codable, Equatable, Sendable {
    public let generatedAt: Date
    public let archiveRootPath: String
    public let software: [DiagnosticsSoftware]
    public let totals: DiagnosticsTotals
    public let imports: [DiagnosticsImport]
    public let archives: [DiagnosticsArchive]
    public let recentActivity: [DiagnosticsActivity]

    public init(
        generatedAt: Date = Date(),
        archiveRootPath: String,
        software: [DiagnosticsSoftware],
        totals: DiagnosticsTotals,
        imports: [DiagnosticsImport],
        archives: [DiagnosticsArchive],
        recentActivity: [DiagnosticsActivity]
    ) {
        self.generatedAt = generatedAt
        self.archiveRootPath = archiveRootPath
        self.software = software
        self.totals = totals
        self.imports = imports
        self.archives = archives
        self.recentActivity = recentActivity
    }
}

public struct DiagnosticsSoftware: Codable, Equatable, Sendable {
    public let appID: String
    public let displayName: String
    public let probeStatus: String
    public let isRunning: Bool
    public let installedApplicationPaths: [String]
    public let recordingFolderPaths: [String]
    public let historyFolderPaths: [String]

    public init(
        appID: String,
        displayName: String,
        probeStatus: String,
        isRunning: Bool,
        installedApplicationPaths: [String],
        recordingFolderPaths: [String],
        historyFolderPaths: [String]
    ) {
        self.appID = appID
        self.displayName = displayName
        self.probeStatus = probeStatus
        self.isRunning = isRunning
        self.installedApplicationPaths = installedApplicationPaths
        self.recordingFolderPaths = recordingFolderPaths
        self.historyFolderPaths = historyFolderPaths
    }
}

public struct DiagnosticsTotals: Codable, Equatable, Sendable {
    public let protectedSourceCount: Int
    public let configuredFolderCount: Int
    public let archivedSetCount: Int
    public let importedTracklistCount: Int
    public let importedTrackCount: Int
    public let recentActivityCount: Int

    public init(
        protectedSourceCount: Int,
        configuredFolderCount: Int,
        archivedSetCount: Int,
        importedTracklistCount: Int,
        importedTrackCount: Int,
        recentActivityCount: Int
    ) {
        self.protectedSourceCount = protectedSourceCount
        self.configuredFolderCount = configuredFolderCount
        self.archivedSetCount = archivedSetCount
        self.importedTracklistCount = importedTracklistCount
        self.importedTrackCount = importedTrackCount
        self.recentActivityCount = recentActivityCount
    }
}

public struct DiagnosticsImport: Codable, Equatable, Sendable {
    public let appID: String
    public let sourcePath: String
    public let importedAt: Date
    public let trackCount: Int

    public init(appID: String, sourcePath: String, importedAt: Date, trackCount: Int) {
        self.appID = appID
        self.sourcePath = sourcePath
        self.importedAt = importedAt
        self.trackCount = trackCount
    }
}

public struct DiagnosticsArchive: Codable, Equatable, Sendable {
    public let appID: String
    public let originalFilename: String
    public let detectedAt: Date
    public let sourcePath: String
    public let archivePath: String
    public let fileSize: Int64
    public let durationSeconds: Double?

    public init(
        appID: String,
        originalFilename: String,
        detectedAt: Date,
        sourcePath: String,
        archivePath: String,
        fileSize: Int64,
        durationSeconds: Double?
    ) {
        self.appID = appID
        self.originalFilename = originalFilename
        self.detectedAt = detectedAt
        self.sourcePath = sourcePath
        self.archivePath = archivePath
        self.fileSize = fileSize
        self.durationSeconds = durationSeconds
    }
}

public struct DiagnosticsActivity: Codable, Equatable, Sendable {
    public let kind: String
    public let message: String
    public let detail: String?
    public let createdAt: Date

    public init(kind: String, message: String, detail: String?, createdAt: Date) {
        self.kind = kind
        self.message = message
        self.detail = detail
        self.createdAt = createdAt
    }
}

public struct DiagnosticsReportBuilder {
    private let homeDirectory: URL
    private let isReachableDirectory: @Sendable (URL) -> Bool

    public init(
        homeDirectory: URL = DefaultPathProvider().homeDirectory(),
        isReachableDirectory: (@Sendable (URL) -> Bool)? = nil
    ) {
        self.homeDirectory = homeDirectory
        let defaultReachability: @Sendable (URL) -> Bool = { url in
            var isDirectory: ObjCBool = false
            return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
        }
        self.isReachableDirectory = isReachableDirectory ?? defaultReachability
    }

    public func build(
        generatedAt: Date = Date(),
        archiveRoot: URL,
        probeResults: [SoftwareProbeResult],
        recordingFolders: (String) -> [URL],
        historyFolders: (String) -> [URL],
        folderAccesses: [FolderAccess],
        archives: [ArchiveMetadata],
        importedTracklists: [ImportedTracklist],
        activityEvents: [ActivityEvent]
    ) -> DiagnosticsReport {
        let reachableProtectedSourceCount = probeResults.filter { result in
            recordingFolders(result.software.id).contains(where: isReachableDirectory)
        }.count

        let software = probeResults.map { result in
            DiagnosticsSoftware(
                appID: result.software.id,
                displayName: result.software.displayName,
                probeStatus: result.status,
                isRunning: result.isRunning,
                installedApplicationPaths: result.installedApplicationURLs.map { redactedPath($0.path) },
                recordingFolderPaths: recordingFolders(result.software.id).map { redactedPath($0.path) },
                historyFolderPaths: historyFolders(result.software.id).map { redactedPath($0.path) }
            )
        }

        let imports = importedTracklists
            .sorted { $0.importedAt > $1.importedAt }
            .map {
                DiagnosticsImport(
                    appID: $0.appID,
                    sourcePath: redactedPath($0.sourceURL.path),
                    importedAt: $0.importedAt,
                    trackCount: $0.tracks.count
                )
            }

        let diagnosticArchives = archives
            .sorted { $0.detectedAt > $1.detectedAt }
            .map {
                DiagnosticsArchive(
                    appID: $0.sourceAppID,
                    originalFilename: $0.originalFilename,
                    detectedAt: $0.detectedAt,
                    sourcePath: redactedPath($0.sourcePath),
                    archivePath: redactedPath($0.archivePath),
                    fileSize: $0.fileSize,
                    durationSeconds: $0.durationSeconds
                )
            }

        let activity = activityEvents
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(50)
            .map {
                DiagnosticsActivity(
                    kind: $0.kind.rawValue,
                    message: $0.message,
                    detail: $0.detail.map(redactedText(_:)),
                    createdAt: $0.createdAt
                )
            }

        return DiagnosticsReport(
            generatedAt: generatedAt,
            archiveRootPath: redactedPath(archiveRoot.path),
            software: software,
            totals: DiagnosticsTotals(
                protectedSourceCount: reachableProtectedSourceCount,
                configuredFolderCount: folderAccesses.count,
                archivedSetCount: archives.count,
                importedTracklistCount: imports.count,
                importedTrackCount: imports.reduce(0) { $0 + $1.trackCount },
                recentActivityCount: activity.count
            ),
            imports: imports,
            archives: diagnosticArchives,
            recentActivity: Array(activity)
        )
    }

    private func redactedPath(_ path: String) -> String {
        let homePath = homeDirectory.standardizedFileURL.path
        guard !homePath.isEmpty else { return path }

        if path == homePath {
            return "~"
        }

        let homePrefix = homePath.hasSuffix("/") ? homePath : "\(homePath)/"
        if path.hasPrefix(homePrefix) {
            return "~/" + path.dropFirst(homePrefix.count)
        }

        return path
    }

    private func redactedText(_ text: String) -> String {
        let homePath = homeDirectory.standardizedFileURL.path
        guard !homePath.isEmpty else { return text }

        return text.replacingOccurrences(of: homePath, with: "~")
    }
}

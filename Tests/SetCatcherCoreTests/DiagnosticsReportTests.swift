import XCTest
@testable import SetCatcherCore

final class DiagnosticsReportTests: XCTestCase {
    func testBuilderSummarizesStateWithoutTrackTitles() {
        let generatedAt = Date(timeIntervalSince1970: 1_800)
        let importedAt = Date(timeIntervalSince1970: 1_700)
        let detectedAt = Date(timeIntervalSince1970: 1_600)
        let activityAt = Date(timeIntervalSince1970: 1_750)
        let homeDirectory = URL(fileURLWithPath: "/Users/private-dj", isDirectory: true)
        let app = DJSoftware(
            id: "serato",
            displayName: "Serato DJ Pro",
            bundleIdentifiers: ["com.serato.dj"],
            defaultRecordingPaths: [],
            defaultHistoryPaths: [],
            integrationDepth: .exportImport,
            supportStatus: .supported,
            notes: "test"
        )
        let archive = ArchiveMetadata(
            sessionID: UUID(),
            sourceAppID: "serato",
            detectedAt: detectedAt,
            completedAt: nil,
            sourcePath: "/Users/private-dj/Music/_Serato_/Recording/set.wav",
            archivePath: "/Users/private-dj/Music/SetCatcher/set.wav",
            fileSize: 42,
            originalFilename: "set.wav",
            durationSeconds: nil
        )
        let imported = ImportedTracklist(
            appID: "serato",
            sourceURL: URL(fileURLWithPath: "/Users/private-dj/Music/_Serato_/History Export/private-set.csv"),
            tracks: [
                TrackPlay(
                    title: "Private Track",
                    artist: "Private Artist",
                    startTime: nil,
                    source: "private-set.csv",
                    confidence: 1.0
                )
            ],
            importedAt: importedAt
        )

        let report = DiagnosticsReportBuilder(
            homeDirectory: homeDirectory,
            isReachableDirectory: { _ in true }
        ).build(
            generatedAt: generatedAt,
            archiveRoot: URL(fileURLWithPath: "/Users/private-dj/Music/SetCatcher"),
            probeResults: [
                SoftwareProbeResult(
                    software: app,
                    installedApplicationURLs: [URL(fileURLWithPath: "/Applications/Serato DJ Pro.app")],
                    runningApplicationBundleIdentifiers: ["com.serato.dj"],
                    existingRecordingURLs: [],
                    existingHistoryURLs: []
                )
            ],
            recordingFolders: { _ in [URL(fileURLWithPath: "/Users/private-dj/Music/_Serato_/Recording")] },
            historyFolders: { _ in [URL(fileURLWithPath: "/Users/private-dj/Music/_Serato_/History Export")] },
            folderAccesses: [
                FolderAccess(
                    appID: "serato",
                    kind: .recordings,
                    url: URL(fileURLWithPath: "/Users/private-dj/Music/_Serato_/Recording"),
                    bookmarkData: nil
                )
            ],
            archives: [archive],
            importedTracklists: [imported],
            activityEvents: [
                ActivityEvent(
                    kind: .importTracklist,
                    message: "Imported 1 track",
                    detail: "/Users/private-dj/Music/_Serato_/History Export/private-set.csv",
                    createdAt: activityAt
                )
            ]
        )

        XCTAssertEqual(report.generatedAt, generatedAt)
        XCTAssertEqual(report.software.first?.probeStatus, "running")
        XCTAssertEqual(report.software.first?.isRunning, true)
        XCTAssertEqual(report.totals.protectedSourceCount, 1)
        XCTAssertEqual(report.totals.configuredFolderCount, 1)
        XCTAssertEqual(report.totals.archivedSetCount, 1)
        XCTAssertEqual(report.totals.importedTracklistCount, 1)
        XCTAssertEqual(report.totals.importedTrackCount, 1)
        XCTAssertEqual(report.archiveRootPath, "~/Music/SetCatcher")
        XCTAssertEqual(report.software.first?.recordingFolderPaths, ["~/Music/_Serato_/Recording"])
        XCTAssertEqual(report.imports.first?.sourcePath, "~/Music/_Serato_/History Export/private-set.csv")
        XCTAssertEqual(report.archives.first?.sourcePath, "~/Music/_Serato_/Recording/set.wav")
        XCTAssertEqual(report.recentActivity.first?.detail, "~/Music/_Serato_/History Export/private-set.csv")
        XCTAssertEqual(report.imports.first?.trackCount, 1)

        let encoded = try! JSONEncoder().encode(report)
        let json = String(data: encoded, encoding: .utf8)!
        XCTAssertFalse(json.contains("Private Artist"))
        XCTAssertFalse(json.contains("Private Track"))
        XCTAssertFalse(json.contains("/Users/private-dj"))
    }

    func testProtectedSourceCountExcludesUnreachableRecordingFolders() {
        let app = DJSoftware(
            id: "serato",
            displayName: "Serato DJ Pro",
            bundleIdentifiers: ["com.serato.dj"],
            defaultRecordingPaths: [],
            defaultHistoryPaths: [],
            integrationDepth: .fileWatcher,
            supportStatus: .supported,
            notes: "test"
        )
        let reachableFolder = URL(fileURLWithPath: "/Users/private-dj/Music/_Serato_/Recording")
        let missingFolder = URL(fileURLWithPath: "/Users/private-dj/Music/Missing")

        let report = DiagnosticsReportBuilder(
            homeDirectory: URL(fileURLWithPath: "/Users/private-dj", isDirectory: true),
            isReachableDirectory: { $0 == reachableFolder }
        ).build(
            archiveRoot: URL(fileURLWithPath: "/Users/private-dj/Music/SetCatcher"),
            probeResults: [
                SoftwareProbeResult(
                    software: app,
                    installedApplicationURLs: [],
                    runningApplicationBundleIdentifiers: [],
                    existingRecordingURLs: [],
                    existingHistoryURLs: []
                )
            ],
            recordingFolders: { _ in [reachableFolder, missingFolder] },
            historyFolders: { _ in [] },
            folderAccesses: [
                FolderAccess(appID: "serato", kind: .recordings, url: reachableFolder, bookmarkData: nil),
                FolderAccess(appID: "serato", kind: .recordings, url: missingFolder, bookmarkData: nil)
            ],
            archives: [],
            importedTracklists: [],
            activityEvents: []
        )

        XCTAssertEqual(report.totals.protectedSourceCount, 1)
        XCTAssertEqual(
            report.software.first?.recordingFolderPaths,
            ["~/Music/_Serato_/Recording", "~/Music/Missing"]
        )
    }
}

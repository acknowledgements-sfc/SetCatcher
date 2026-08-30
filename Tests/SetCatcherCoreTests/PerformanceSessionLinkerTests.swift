import XCTest
@testable import SetCatcherCore

final class PerformanceSessionLinkerTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    func testOverlapLinksFolderAsPrimaryAndCaptureAsBackup() {
        let capture = archive(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            app: SupportedDJSoftware.captureAppID,
            detectedAt: t0,
            completedAt: t0.addingTimeInterval(3600),
            path: "/SetCatcherCapture/XDJ-XZ/a.wav"
        )
        let folder = archive(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            app: "serato",
            detectedAt: t0.addingTimeInterval(3500),
            completedAt: t0.addingTimeInterval(3510),
            duration: 3400,
            path: "/Music/_Serato_/Recording/set.wav"
        )

        let groups = PerformanceSessionLinker.groups(from: [capture, folder])
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].id, capture.sessionID)
        XCTAssertEqual(groups[0].primary.sessionID, folder.sessionID)
        XCTAssertEqual(groups[0].hardwareBackup?.sessionID, capture.sessionID)
        XCTAssertEqual(groups[0].primary.sourcePath, folder.sourcePath)
        XCTAssertEqual(groups[0].hardwareBackup?.sourcePath, capture.sourcePath)
    }

    func testCaptureThenFolderKeepsStableEarliestId() {
        let captureID = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
        let folderID = UUID(uuidString: "00000000-0000-0000-0000-000000000011")!
        let capture = archive(id: captureID, app: SupportedDJSoftware.captureAppID, detectedAt: t0, completedAt: t0.addingTimeInterval(7200), path: "/c.wav")
        let folder = archive(id: folderID, app: "rekordbox", detectedAt: t0.addingTimeInterval(7210), completedAt: t0.addingTimeInterval(7220), path: "/r.wav")

        let afterCapture = PerformanceSessionLinker.groups(from: [capture])
        XCTAssertEqual(afterCapture[0].id, captureID)
        XCTAssertNil(afterCapture[0].hardwareBackup)

        let afterFolder = PerformanceSessionLinker.groups(from: [capture, folder])
        XCTAssertEqual(afterFolder.count, 1)
        XCTAssertEqual(afterFolder[0].id, captureID)
        XCTAssertEqual(afterFolder[0].primary.sessionID, folderID)
        XCTAssertEqual(afterFolder[0].hardwareBackup?.sessionID, captureID)
    }

    func testFolderThenCaptureStillOneGroup() {
        let folder = archive(id: UUID(), app: "serato", detectedAt: t0.addingTimeInterval(3600), completedAt: t0.addingTimeInterval(3610), duration: 3600, path: "/s.wav")
        let capture = archive(id: UUID(), app: SupportedDJSoftware.captureAppID, detectedAt: t0, completedAt: t0.addingTimeInterval(3600), path: "/c.wav")
        let groups = PerformanceSessionLinker.groups(from: [folder, capture])
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].primary.sourceAppID, "serato")
        XCTAssertEqual(groups[0].hardwareBackup?.sourceAppID, SupportedDJSoftware.captureAppID)
    }

    func testForgotRecordLeavesCaptureUnlabeledAsBackup() {
        let capture = archive(id: UUID(), app: SupportedDJSoftware.captureAppID, detectedAt: t0, completedAt: t0.addingTimeInterval(1800), path: "/c.wav")
        let groups = PerformanceSessionLinker.groups(from: [capture])
        XCTAssertEqual(groups.count, 1)
        XCTAssertNil(groups[0].hardwareBackup)
        XCTAssertEqual(groups[0].primary.sourceAppID, SupportedDJSoftware.captureAppID)
    }

    func testFolderOnlyStaysSingleton() {
        let folder = archive(id: UUID(), app: "serato", detectedAt: t0, completedAt: t0, path: "/s.wav")
        let groups = PerformanceSessionLinker.groups(from: [folder])
        XCTAssertEqual(groups.count, 1)
        XCTAssertNil(groups[0].hardwareBackup)
        XCTAssertEqual(groups[0].id, folder.sessionID)
    }

    func testTwoSequentialGigsDoNotMerge() {
        let capture1 = archive(id: UUID(), app: SupportedDJSoftware.captureAppID, detectedAt: t0, completedAt: t0.addingTimeInterval(3600), path: "/c1.wav")
        let folder1 = archive(id: UUID(), app: "serato", detectedAt: t0.addingTimeInterval(3610), completedAt: t0.addingTimeInterval(3620), path: "/s1.wav")
        let later = t0.addingTimeInterval(8 * 3600)
        let capture2 = archive(id: UUID(), app: SupportedDJSoftware.captureAppID, detectedAt: later, completedAt: later.addingTimeInterval(3600), path: "/c2.wav")
        let folder2 = archive(id: UUID(), app: "serato", detectedAt: later.addingTimeInterval(3610), completedAt: later.addingTimeInterval(3620), path: "/s2.wav")

        let groups = PerformanceSessionLinker.groups(from: [capture1, folder1, capture2, folder2])
        XCTAssertEqual(groups.count, 2)
    }

    func testNearMissJustOutsideSlackDoesNotLink() {
        let capture = archive(id: UUID(), app: SupportedDJSoftware.captureAppID, detectedAt: t0, completedAt: t0.addingTimeInterval(3600), path: "/c.wav")
        let folder = archive(
            id: UUID(),
            app: "serato",
            detectedAt: t0.addingTimeInterval(3600 + PerformanceSessionLinker.folderJoinSlack + 60),
            completedAt: t0.addingTimeInterval(3600 + PerformanceSessionLinker.folderJoinSlack + 70),
            path: "/s.wav"
        )
        let groups = PerformanceSessionLinker.groups(from: [capture, folder])
        XCTAssertEqual(groups.count, 2)
    }

    func testPairsAtMostOneFolderPerCapture() {
        let capture = archive(id: UUID(), app: SupportedDJSoftware.captureAppID, detectedAt: t0, completedAt: t0.addingTimeInterval(3600), path: "/c.wav")
        let closer = archive(id: UUID(), app: "serato", detectedAt: t0.addingTimeInterval(3610), completedAt: t0.addingTimeInterval(3620), path: "/s1.wav")
        let farther = archive(id: UUID(), app: "rekordbox", detectedAt: t0.addingTimeInterval(3800), completedAt: t0.addingTimeInterval(3810), path: "/r.wav")
        let groups = PerformanceSessionLinker.groups(from: [capture, closer, farther])
        XCTAssertEqual(groups.count, 2)
        let linked = groups.first { $0.hardwareBackup != nil }
        XCTAssertEqual(linked?.primary.sourcePath, closer.sourcePath)
    }

    func testNeverMutatesSourceOrArchivePaths() {
        let capture = archive(id: UUID(), app: SupportedDJSoftware.captureAppID, detectedAt: t0, completedAt: t0.addingTimeInterval(100), path: "/unchanged-source.wav", archive: "/unchanged-archive.wav")
        let folder = archive(id: UUID(), app: "serato", detectedAt: t0.addingTimeInterval(90), completedAt: t0.addingTimeInterval(95), path: "/folder-source.wav", archive: "/folder-archive.wav")
        let group = PerformanceSessionLinker.groups(from: [capture, folder])[0]
        XCTAssertEqual(group.primary.sourcePath, "/folder-source.wav")
        XCTAssertEqual(group.primary.archivePath, "/folder-archive.wav")
        XCTAssertEqual(group.hardwareBackup?.sourcePath, "/unchanged-source.wav")
        XCTAssertEqual(group.hardwareBackup?.archivePath, "/unchanged-archive.wav")
    }

    func testAttachmentWhenFolderJoinsExistingCapture() {
        let capture = archive(id: UUID(), app: SupportedDJSoftware.captureAppID, detectedAt: t0, completedAt: t0.addingTimeInterval(3600), path: "/c.wav")
        let folder = archive(id: UUID(), app: "serato", detectedAt: t0.addingTimeInterval(3610), completedAt: t0.addingTimeInterval(3620), path: "/s.wav")
        XCTAssertEqual(
            PerformanceSessionLinker.attachment(of: folder, existing: [capture]),
            .primaryAttached(sourceAppID: "serato")
        )
        XCTAssertEqual(
            PerformanceSessionLinker.attachment(of: capture, existing: [folder]),
            .hardwareBackupAttached
        )
        XCTAssertEqual(
            PerformanceSessionLinker.attachment(of: capture, existing: []),
            .newPerformance
        )
    }

    func testMatcherUsesGroupIdAndPrimaryForTracklist() {
        let capture = archive(id: UUID(), app: SupportedDJSoftware.captureAppID, detectedAt: t0, completedAt: t0.addingTimeInterval(3600), path: "/c.wav")
        let folder = archive(id: UUID(), app: "serato", detectedAt: t0.addingTimeInterval(3610), completedAt: t0.addingTimeInterval(3620), path: "/s.wav")
        let tracklist = ImportedTracklist(
            appID: "serato",
            sourceURL: URL(fileURLWithPath: "/tmp/history.csv"),
            tracks: [TrackPlay(title: "Track", artist: "Artist", startTime: nil, source: "history.csv", confidence: 0.9)],
            importedAt: t0.addingTimeInterval(3700)
        )
        let context = SetContext(sessionID: capture.sessionID, notes: "Kept notes")
        let summaries = LibrarySessionMatcher().summaries(
            archives: [capture, folder],
            importedTracklists: [tracklist],
            setContexts: [context]
        )
        XCTAssertEqual(summaries.count, 1)
        XCTAssertEqual(summaries[0].id, capture.sessionID)
        XCTAssertEqual(summaries[0].archive.sourceAppID, "serato")
        XCTAssertEqual(summaries[0].hardwareBackup?.sourceAppID, SupportedDJSoftware.captureAppID)
        XCTAssertEqual(summaries[0].matchedTracklist?.sourceURL.lastPathComponent, "history.csv")
        XCTAssertEqual(summaries[0].context.notes, "Kept notes")
    }

    func testManualPinSurvivesGrouping() {
        let capture = archive(id: UUID(), app: SupportedDJSoftware.captureAppID, detectedAt: t0, completedAt: t0.addingTimeInterval(3600), path: "/c.wav")
        let folder = archive(id: UUID(), app: "serato", detectedAt: t0.addingTimeInterval(3610), completedAt: t0.addingTimeInterval(3620), path: "/s.wav")
        let automatic = ImportedTracklist(
            id: UUID(),
            appID: "serato",
            sourceURL: URL(fileURLWithPath: "/tmp/auto.csv"),
            tracks: [TrackPlay(title: "A", artist: "X", startTime: nil, source: "auto.csv", confidence: 0.9)],
            importedAt: t0.addingTimeInterval(3611)
        )
        let manual = ImportedTracklist(
            id: UUID(),
            appID: "serato",
            sourceURL: URL(fileURLWithPath: "/tmp/manual.csv"),
            tracks: [TrackPlay(title: "M", artist: "Y", startTime: nil, source: "manual.csv", confidence: 0.9)],
            importedAt: t0.addingTimeInterval(4000)
        )
        let context = SetContext(sessionID: capture.sessionID, manualTracklistID: manual.id)
        let summaries = LibrarySessionMatcher().summaries(
            archives: [capture, folder],
            importedTracklists: [automatic, manual],
            setContexts: [context]
        )
        XCTAssertEqual(summaries[0].matchedTracklist?.sourceURL.lastPathComponent, "manual.csv")
    }

    func testStatisticsCountGroupsNotRawSidecars() {
        let capture = archive(
            id: UUID(),
            app: SupportedDJSoftware.captureAppID,
            detectedAt: t0,
            completedAt: t0.addingTimeInterval(3600),
            duration: 3600,
            path: "/c.wav",
            size: 100
        )
        let folder = archive(
            id: UUID(),
            app: "serato",
            detectedAt: t0.addingTimeInterval(3610),
            completedAt: t0.addingTimeInterval(3620),
            duration: 3500,
            path: "/s.wav",
            size: 200
        )
        let summaries = LibrarySessionMatcher().summaries(archives: [capture, folder], importedTracklists: [])
        let stats = LibraryStatisticsCalculator.calculate(
            archives: [capture, folder],
            summaries: summaries,
            now: t0.addingTimeInterval(3610)
        )
        XCTAssertEqual(summaries.count, 1)
        XCTAssertEqual(stats.setsThisMonth, 1)
        XCTAssertEqual(stats.totalFileSize, 300)
        XCTAssertEqual(stats.totalDurationSeconds, 3500)
        XCTAssertEqual(stats.unmatchedCount, 1)
    }

    private func archive(
        id: UUID,
        app: String,
        detectedAt: Date,
        completedAt: Date?,
        duration: Double? = nil,
        path: String,
        archive: String? = nil,
        size: Int64 = 1
    ) -> ArchiveMetadata {
        ArchiveMetadata(
            sessionID: id,
            sourceAppID: app,
            detectedAt: detectedAt,
            completedAt: completedAt,
            sourcePath: path,
            archivePath: archive ?? "/archive\(path)",
            fileSize: size,
            originalFilename: URL(fileURLWithPath: path).lastPathComponent,
            durationSeconds: duration,
            sourceFingerprint: id.uuidString
        )
    }
}

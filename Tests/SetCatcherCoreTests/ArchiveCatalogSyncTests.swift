import Foundation
import Testing
@testable import SetCatcherCore

@Suite("Archive catalog sync")
struct ArchiveCatalogSyncTests {
    @Test("Mapper omits paths from DTO")
    func mapperBuildsDTOWithoutPaths() {
        let archive = ArchiveMetadata(
            sessionID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            sourceAppID: "serato",
            detectedAt: Date(timeIntervalSince1970: 1_700_000_000),
            completedAt: Date(timeIntervalSince1970: 1_700_000_100),
            sourcePath: "/Users/rob/recordings/set.wav",
            archivePath: "/Users/rob/Library/SetCatcher/set.wav",
            fileSize: 42_000,
            originalFilename: "set.wav",
            durationSeconds: 3_600,
            sourceFingerprint: "abc",
            ingestionKind: .folderWatch,
            companionAppID: nil,
            captureRoute: nil,
            captureBackend: nil,
            captureDeviceUID: nil,
            captureDeviceName: nil,
            captureDeviceTransport: nil,
            captureInterrupted: false,
            captureInterruptionReason: nil
        )
        let context = SetContext(
            sessionID: archive.sessionID,
            eventName: "Friday Night",
            venue: "Club",
            city: "LA",
            tags: "house",
            notes: "Great crowd"
        )

        let dto = ArchiveCatalogMapper.dto(
            from: archive,
            context: context,
            platform: .macos,
            originDeviceName: "Rob's MacBook"
        )

        #expect(dto.sessionId == archive.sessionID)
        #expect(dto.platform == .macos)
        #expect(dto.sourceAppId == "serato")
        #expect(dto.originalFilename == "set.wav")
        #expect(dto.setContext?.eventName == "Friday Night")
        #expect(dto.setContext?.venue == "Club")
    }

    @Test("Merger adds remote-only stubs")
    func mergerAddsRemoteOnlyStubs() {
        let localID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let remoteID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!

        let local = ArchiveMetadata(
            sessionID: localID,
            sourceAppID: "serato",
            detectedAt: Date(timeIntervalSince1970: 1_700_000_000),
            completedAt: nil,
            sourcePath: "/tmp/local.wav",
            archivePath: "/tmp/archive/local.wav",
            fileSize: 1,
            originalFilename: "local.wav",
            durationSeconds: nil
        )

        let remote = ArchiveCatalogSessionDTO(
            sessionId: remoteID,
            platform: .ios,
            originDeviceId: nil,
            originDeviceName: "Rob's iPad",
            sourceAppId: "djay",
            detectedAt: Date(timeIntervalSince1970: 1_700_000_500),
            completedAt: nil,
            originalFilename: "ipad-set.wav",
            fileSize: 2,
            durationSeconds: nil,
            ingestionKind: nil,
            companionAppId: nil,
            captureRoute: nil,
            captureBackend: nil,
            captureDeviceName: nil,
            captureDeviceTransport: nil,
            captureInterrupted: false,
            captureInterruptionReason: nil,
            audioBackedUp: false,
            updatedAt: Date(),
            setContext: nil
        )

        let merged = ArchiveCatalogMerger().mergedArchives(localArchives: [local], remoteSessions: [remote])
        #expect(merged.count == 2)
        #expect(merged.contains { $0.sessionID == localID && !$0.archivePath.isEmpty })
        #expect(merged.contains { $0.sessionID == remoteID && $0.archivePath.isEmpty })
    }

    @Test("Catalog availability distinguishes local, remote, and synced")
    func catalogAvailability() {
        let localID = UUID()
        let remoteID = UUID()
        let remote = ArchiveCatalogSessionDTO(
            sessionId: remoteID,
            platform: .ios,
            originDeviceId: nil,
            originDeviceName: "iPad",
            sourceAppId: "djay",
            detectedAt: Date(),
            completedAt: nil,
            originalFilename: "set.wav",
            fileSize: 1,
            durationSeconds: nil,
            ingestionKind: nil,
            companionAppId: nil,
            captureRoute: nil,
            captureBackend: nil,
            captureDeviceName: nil,
            captureDeviceTransport: nil,
            captureInterrupted: false,
            captureInterruptionReason: nil,
            audioBackedUp: false,
            updatedAt: Date(),
            setContext: nil
        )

        let merger = ArchiveCatalogMerger()
        #expect(merger.catalogAvailability(for: localID, hasLocalFile: true, remoteSessions: []) == .localFile)
        #expect(
            merger.catalogAvailability(for: localID, hasLocalFile: true, remoteSessions: [
                ArchiveCatalogSessionDTO(
                    sessionId: localID,
                    platform: .macos,
                    originDeviceId: nil,
                    originDeviceName: nil,
                    sourceAppId: "serato",
                    detectedAt: Date(),
                    completedAt: nil,
                    originalFilename: "x.wav",
                    fileSize: 1,
                    durationSeconds: nil,
                    ingestionKind: nil,
                    companionAppId: nil,
                    captureRoute: nil,
                    captureBackend: nil,
                    captureDeviceName: nil,
                    captureDeviceTransport: nil,
                    captureInterrupted: false,
                    captureInterruptionReason: nil,
                    audioBackedUp: false,
                    updatedAt: Date(),
                    setContext: nil
                )
            ]) == .localAndSynced
        )
        #expect(
            merger.catalogAvailability(for: remoteID, hasLocalFile: false, remoteSessions: [remote])
                == .remoteOnly(originDeviceName: "iPad")
        )
    }

    @Test("Merged contexts prefer newer remote updates")
    func mergedContextsPreferNewerRemote() {
        let sessionID = UUID()
        let localContext = SetContext(
            sessionID: sessionID,
            eventName: "Old",
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        let remoteContext = ArchiveCatalogSetContextDTO(
            eventName: "New",
            updatedAt: Date(timeIntervalSince1970: 200)
        )
        let remote = ArchiveCatalogSessionDTO(
            sessionId: sessionID,
            platform: .macos,
            originDeviceId: nil,
            originDeviceName: nil,
            sourceAppId: "serato",
            detectedAt: Date(),
            completedAt: nil,
            originalFilename: "set.wav",
            fileSize: 1,
            durationSeconds: nil,
            ingestionKind: nil,
            companionAppId: nil,
            captureRoute: nil,
            captureBackend: nil,
            captureDeviceName: nil,
            captureDeviceTransport: nil,
            captureInterrupted: false,
            captureInterruptionReason: nil,
            audioBackedUp: false,
            updatedAt: Date(),
            setContext: remoteContext
        )

        let merged = ArchiveCatalogMerger().mergedSetContexts(
            localContexts: [localContext],
            remoteSessions: [remote],
            localArchiveIDs: [sessionID]
        )
        #expect(merged.first?.eventName == "New")
    }
}

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
        #expect(dto.audioBackedUp == false)
        #expect(dto.setContext?.eventName == "Friday Night")
        #expect(dto.setContext?.venue == "Club")

        let data = try! JSONEncoder().encode(dto)
        let json = String(decoding: data, as: UTF8.self)
        #expect(!json.contains("notes"))
        #expect(!json.contains("Great crowd"))
    }

    @Test("Legacy remote notes are ignored")
    func legacyRemoteNotesAreIgnored() throws {
        let data = Data(
            #"{"eventName":"Remote Event","venue":"Club","city":"LA","tags":"house","notes":"legacy private note","updatedAt":"2026-09-02T12:00:00Z"}"#.utf8
        )
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let dto = try decoder.decode(ArchiveCatalogSetContextDTO.self, from: data)
        let context = ArchiveCatalogMapper.setContext(from: dto, sessionID: UUID())

        #expect(context.eventName == "Remote Event")
        #expect(context.notes.isEmpty)
        #expect(context.manualTracklistID == nil)
    }

    @Test("Remote sync preserves local-only context")
    func remoteSyncPreservesLocalOnlyContext() {
        let sessionID = UUID()
        let tracklistID = UUID()
        let local = SetContext(
            sessionID: sessionID,
            eventName: "Old Event",
            venue: "Old Venue",
            city: "Oakland",
            tags: "old",
            notes: "Keep this private",
            manualTracklistID: tracklistID,
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        let remote = ArchiveCatalogSetContextDTO(
            eventName: "New Event",
            venue: "New Venue",
            city: "San Francisco",
            tags: "house",
            updatedAt: Date(timeIntervalSince1970: 200)
        )

        let merged = ArchiveCatalogMapper.mergingSyncedFields(
            from: remote,
            into: local,
            sessionID: sessionID
        )

        #expect(merged.eventName == "New Event")
        #expect(merged.venue == "New Venue")
        #expect(merged.city == "San Francisco")
        #expect(merged.tags == "house")
        #expect(merged.notes == "Keep this private")
        #expect(merged.manualTracklistID == tracklistID)
        #expect(merged.updatedAt == Date(timeIntervalSince1970: 200))
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
            notes: "Local note",
            manualTracklistID: UUID(uuidString: "00000000-0000-0000-0000-000000000004"),
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
        #expect(merged.first?.notes == "Local note")
        #expect(merged.first?.manualTracklistID == UUID(uuidString: "00000000-0000-0000-0000-000000000004"))
    }
}

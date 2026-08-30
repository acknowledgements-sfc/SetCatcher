import Foundation
import SetCatcherCore
import SwiftUI

@MainActor
enum PreviewFixtures {
    static func archive(
        id: UUID = UUID(),
        appID: String = "serato",
        filename: String = "Club Night.wav",
        duration: Double? = 3720,
        matched: Bool = true,
        event: String = "Friday Peak",
        venue: String = "Fabric",
        city: String = "London",
        notes: String = "",
        tags: String = "Techno, Peak"
    ) -> (ArchiveMetadata, LibrarySessionSummary, SetContext, ImportedTracklist?) {
        let archive = ArchiveMetadata(
            sessionID: id,
            sourceAppID: appID,
            detectedAt: Date().addingTimeInterval(-3600),
            completedAt: Date(),
            sourcePath: "/Volumes/GIG-SSD/Recordings/\(filename)",
            archivePath: "/Users/dj/Music/SetCatcher/\(filename)",
            fileSize: 84_000_000,
            originalFilename: filename,
            durationSeconds: duration,
            sourceFingerprint: id.uuidString
        )
        let tracklist: ImportedTracklist? = matched
            ? ImportedTracklist(
                id: UUID(),
                appID: appID,
                sourceURL: URL(fileURLWithPath: "/tmp/\(appID)-history.csv"),
                kind: .setHistory,
                tracks: [
                    TrackPlay(title: "Strobe", artist: "deadmau5", startTime: "0:00", source: "preview", confidence: 1),
                    TrackPlay(title: "Atmosphere", artist: "Fisher", startTime: "0:04", source: "preview", confidence: 1)
                ]
            )
            : nil
        let context = SetContext(
            sessionID: id,
            eventName: event,
            venue: venue,
            city: city,
            tags: tags,
            notes: notes,
            manualTracklistID: tracklist?.id
        )
        let summary = LibrarySessionSummary(archive: archive, matchedTracklist: tracklist, context: context)
        return (archive, summary, context, tracklist)
    }

    static func activityKinds() -> [ActivityEvent] {
        [
            ActivityEvent(kind: .scan, message: "Scan finished", detail: "3 folders"),
            ActivityEvent(kind: .archive, message: "Archived Club Night.wav", detail: "/Users/dj/Music/SetCatcher/Club Night.wav"),
            ActivityEvent(kind: .importTracklist, message: "Imported history", detail: "/tmp/serato-history.csv"),
            ActivityEvent(kind: .error, message: "Folder unreachable", detail: "serato recordings folder"),
            ActivityEvent(kind: .diagnostics, message: "Exported diagnostics", detail: "/tmp/report.json")
        ]
    }

    static func homeEmptyModel() -> AppModel {
        let model = AppModel()
        model.previewApplyProfile(DJProfile())
        return model
    }

    static func homePopulatedModel(
        profile: DJProfile = DJProfile(
            displayName: "Ada Lovelace",
            handle: "@ada",
            city: "London",
            residency: "Fabric",
            memberSince: Calendar.current.date(from: DateComponents(year: 2024, month: 3, day: 1))
        ),
        withNote: Bool = true,
        matched: Bool = true,
        nowHour: Int? = nil
    ) -> AppModel {
        let model = AppModel()
        model.previewApplyProfile(profile)
        if let nowHour {
            var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            components.hour = nowHour
            model.previewApplyNow(Calendar.current.date(from: components))
        }
        let sample = archive(matched: matched, notes: withNote ? "Kept the peak rolling." : "")
        var imported: [ImportedTracklist] = []
        if let tracklist = sample.3 {
            imported.append(tracklist)
        }
        model.previewApplyConfiguredRecordingsFolders(reachableAppIDs: ["serato", "rekordbox"])
        model.previewApplyLibrary(
            archives: [sample.0],
            summaries: [sample.1],
            activity: activityKinds(),
            imported: imported,
            contexts: [sample.2]
        )
        return model
    }

    static func framedHome(_ model: AppModel, scheme: ColorScheme) -> some View {
        ScrollView {
            HomeDashboardView()
                .padding()
        }
        .environmentObject(model)
        .frame(width: 1000, height: 900)
        .background(DJToken.content)
        .preferredColorScheme(scheme)
    }
}

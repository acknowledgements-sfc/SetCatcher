import SwiftUI
import SetCatcherCore

struct HomeLastSetPanel: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Panel(title: "Your last set", padding: 12) {
            if let summary = model.librarySummaries.sorted(by: { $0.archive.detectedAt > $1.archive.detectedAt }).first {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Badge(title: "Archived & verified", tone: .ok)
                        Spacer()
                        Button("Open in Library") {
                            model.openLibrary(sessionID: summary.id)
                        }
                        .buttonStyle(DJGhostButtonStyle())
                    }
                    Text(summary.context.eventName.isEmpty ? summary.archive.originalFilename : summary.context.eventName)
                        .font(.system(size: 15, weight: .semibold))
                    Text(HomeFormatting.lastSetSubtitle(summary))
                        .font(.system(size: DJToken.TypeSize.secondary))
                        .foregroundStyle(DJToken.mutedForeground)

                    Waveform(
                        seed: summary.archive.originalFilename,
                        barCount: 88,
                        tint: DJToken.accent(forAppID: summary.archive.sourceAppID)
                    )
                    .frame(height: 56)
                    .padding(8)
                    .background(DJToken.muted, in: RoundedRectangle(cornerRadius: DJToken.Radius.control))

                    HStack {
                        fact("Duration", HomeFormatting.formatDuration(summary.archive.durationSeconds))
                        fact("Tracks", summary.matchedTracklist == nil ? "—" : "\(summary.trackCount)")
                        fact("Size", ByteCountFormatter.string(fromByteCount: summary.archive.fileSize, countStyle: .file))
                        fact("Tracklist", summary.matchedTracklist == nil ? "Unmatched" : "Matched")
                    }

                    PathChip(path: summary.archive.archivePath)

                    if !summary.context.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        HStack(alignment: .top, spacing: 8) {
                            Rectangle().fill(DJToken.border).frame(width: 2)
                            Text("“\(summary.context.notes)”")
                                .italic()
                                .font(.system(size: DJToken.TypeSize.body))
                                .foregroundStyle(DJToken.mutedForeground)
                        }
                    }

                    HStack {
                        Button("Reveal in Finder") {
                            model.revealInFinder(URL(fileURLWithPath: summary.archive.archivePath))
                        }
                        .buttonStyle(DJSecondaryButtonStyle())
                        Button("Edit details") {
                            model.openLibrary(sessionID: summary.id)
                        }
                        .buttonStyle(DJGhostButtonStyle())
                    }
                }
            } else {
                EmptyStateView(
                    title: "No archived sets yet",
                    systemImage: "music.note",
                    description: "Once SetCatcher archives a recording, your last set will show up here.",
                    primaryTitle: "Choose Folder",
                    primaryAction: { model.selectedRoute = .protection }
                )
            }
        }
    }

    private func fact(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).microLabelStyle()
            Text(value).font(.system(size: DJToken.TypeSize.body, weight: .medium)).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

import SwiftUI
import SetCatcherCore

struct HomeRecentShelf: View {
    @EnvironmentObject private var model: AppModel
    @State private var hoveredID: UUID?

    var body: some View {
        Panel(title: "Recent sets", padding: 12) {
            if model.librarySummaries.isEmpty {
                EmptyStateView(
                    title: "No recent sets yet",
                    systemImage: "rectangle.stack",
                    description: "Archived recordings will appear here as a shelf of recent sets.",
                    primaryTitle: "Choose Folder",
                    primaryAction: { model.selectedRoute = .protection },
                    secondaryTitle: "Open Library",
                    secondaryAction: { model.openLibrary() }
                )
                .frame(minHeight: 140)
                .padding(.vertical, -12)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(model.librarySummaries.sorted(by: { $0.archive.detectedAt > $1.archive.detectedAt }).prefix(6)) { summary in
                            Button {
                                model.openLibrary(sessionID: summary.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    Waveform(
                                        seed: summary.archive.originalFilename,
                                        barCount: 28,
                                        tint: DJToken.accent(forAppID: summary.archive.djAppID)
                                    )
                                    .frame(height: 36)
                                    Text(summary.context.eventName.isEmpty ? summary.archive.originalFilename : summary.context.eventName)
                                        .font(.system(size: DJToken.TypeSize.body, weight: .medium))
                                        .foregroundStyle(DJToken.foreground)
                                        .lineLimit(1)
                                    Text([summary.context.venue, summary.context.city].filter { !$0.isEmpty }.joined(separator: ", "))
                                        .font(.system(size: DJToken.TypeSize.secondary))
                                        .foregroundStyle(DJToken.mutedForeground)
                                        .lineLimit(1)
                                    Rectangle().fill(DJToken.hairline).frame(height: 1)
                                    HStack(spacing: 6) {
                                        RoundedRectangle(cornerRadius: DJToken.Radius.swatch)
                                            .fill(DJToken.accent(forAppID: summary.archive.djAppID))
                                            .frame(width: 3, height: 10)
                                        Text(model.displayName(for: summary.archive.djAppID))
                                            .font(.system(size: DJToken.TypeSize.secondary))
                                            .foregroundStyle(DJToken.mutedForeground)
                                        Spacer()
                                        Text(HomeFormatting.formatDuration(summary.archive.durationSeconds))
                                            .font(.system(size: DJToken.TypeSize.secondary).monospacedDigit())
                                            .foregroundStyle(DJToken.mutedForeground)
                                    }
                                }
                                .padding(10)
                                .frame(width: 196, alignment: .leading)
                                .background(
                                    hoveredID == summary.id ? DJToken.secondary.opacity(0.55) : DJToken.elevated,
                                    in: RoundedRectangle(cornerRadius: DJToken.Radius.control)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: DJToken.Radius.control)
                                        .stroke(
                                            hoveredID == summary.id ? DJToken.primary.opacity(0.5) : DJToken.border,
                                            lineWidth: 1
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                            .onHover { hovering in
                                hoveredID = hovering ? summary.id : (hoveredID == summary.id ? nil : hoveredID)
                            }
                            .accessibilityIdentifier("home.recentSet.\(summary.id.uuidString)")
                        }
                    }
                }
            }
        }
    }
}

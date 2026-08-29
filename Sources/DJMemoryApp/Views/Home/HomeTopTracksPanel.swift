import SwiftUI
import DJMemoryCore

struct HomeTopTracksPanel: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        // Evaluate once per body — `topTracks` recomputes aggregation on every access.
        let tracks = model.topTracks
        Panel(title: "Your most played tracks", padding: 0) {
            if tracks.isEmpty {
                EmptyStateView(
                    title: "No matched tracklists yet",
                    systemImage: "list.number",
                    description: "Import a set history and match it to an archived recording to see top tracks here.",
                    primaryTitle: "Open Library",
                    primaryAction: { model.openLibrary() },
                    secondaryTitle: "Browse DJ apps",
                    secondaryAction: { model.selectedRoute = .protection }
                )
                .frame(minHeight: 160)
            } else {
                let maxPlays = max(tracks.first?.playCount ?? 1, 1)
                ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                    HStack(spacing: 10) {
                        Text(String(format: "%02d", index + 1))
                            .font(.system(size: DJToken.TypeSize.secondary, design: .monospaced))
                            .foregroundStyle(DJToken.mutedForeground)
                            .frame(width: 24, alignment: .leading)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(track.title.isEmpty ? "Unknown title" : track.title)
                                .font(.system(size: DJToken.TypeSize.body, weight: .medium))
                            Text(track.artist.isEmpty ? "Unknown artist" : track.artist)
                                .font(.system(size: DJToken.TypeSize.secondary))
                                .foregroundStyle(DJToken.mutedForeground)
                        }
                        Spacer()
                        Text(track.lastEventName)
                            .font(.system(size: DJToken.TypeSize.secondary))
                            .foregroundStyle(DJToken.mutedForeground)
                            .lineLimit(1)
                        ZStack(alignment: .leading) {
                            Rectangle().fill(DJToken.secondary).frame(width: 48, height: 1)
                            Rectangle()
                                .fill(DJToken.primary)
                                .frame(width: 48 * CGFloat(track.playCount) / CGFloat(maxPlays), height: 1)
                        }
                        Text("\(track.playCount)")
                            .font(.system(size: DJToken.TypeSize.secondary).monospacedDigit())
                            .frame(width: 24, alignment: .trailing)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    if index < tracks.count - 1 {
                        Rectangle().fill(DJToken.hairline).frame(height: 1)
                    }
                }
            }
        }
    }
}

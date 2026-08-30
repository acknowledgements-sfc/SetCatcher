import SwiftUI
import SetCatcherCore

struct TracklistDetailView: View {
    let tracklist: ImportedTracklist
    let appName: String
    @Binding var searchText: String
    let revealInFinder: () -> Void

    private var filteredTracks: [TrackPlay] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return tracklist.tracks }

        return tracklist.tracks.filter { track in
            track.title.localizedCaseInsensitiveContains(query)
                || track.artist.localizedCaseInsensitiveContains(query)
                || (track.startTime?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(tracklist.sourceURL.lastPathComponent)
                        .font(.headline)
                        .lineLimit(1)
                        .help(tracklist.sourceURL.path)
                    Text("\(appName) | \(kindLabel(tracklist.kind)) | \(tracklist.tracks.count) tracks")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                TextField("Search tracks", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 240)
                    .help("Filter this tracklist by title, artist, or play time.")
                    .accessibilityIdentifier("tracklistDetail.\(tracklist.id).search")

                Button(action: revealInFinder) {
                    Label("Reveal", systemImage: "arrow.up.forward.app")
                }
                .help("Reveal the source tracklist in Finder.")
                .accessibilityIdentifier("tracklistDetail.\(tracklist.id).reveal")
            }

            Table(filteredTracks) {
                TableColumn("#") { track in
                    Text(trackNumber(for: track))
                        .foregroundStyle(.secondary)
                }
                .width(min: 34, ideal: 42, max: 52)

                TableColumn("Title") { track in
                    Text(track.title.isEmpty ? "Unknown title" : track.title)
                        .help(track.title)
                }

                TableColumn("Artist") { track in
                    Text(track.artist.isEmpty ? "Unknown artist" : track.artist)
                        .foregroundStyle(track.artist.isEmpty ? .secondary : .primary)
                        .help(track.artist.isEmpty ? "No artist was included in the imported file." : track.artist)
                }

                TableColumn("Played") { track in
                    Text(playedLabel(for: track))
                        .foregroundStyle(
                            track.startTime == nil && track.playedOn == nil
                                ? DJToken.mutedForeground
                                : DJToken.foreground
                        )
                }
                .width(min: 80, ideal: 110, max: 150)
            }
            .frame(minHeight: 300)
            .overlay {
                if filteredTracks.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
        }
        .padding(.top, 4)
    }

    private func trackNumber(for track: TrackPlay) -> String {
        guard let index = tracklist.tracks.firstIndex(where: { $0.id == track.id }) else { return "-" }
        return "\(index + 1)"
    }

    private func kindLabel(_ kind: ImportedTracklistKind) -> String {
        switch kind {
        case .setHistory:
            return "Set history"
        case .collection:
            return "Collection"
        }
    }

    private func playedLabel(for track: TrackPlay) -> String {
        let time = track.startTime
        if let playedOn = track.playedOn {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            let day = formatter.string(from: playedOn)
            if let time, !time.isEmpty {
                return "\(day) · \(time)"
            }
            return day
        }
        return time ?? "Unknown"
    }
}

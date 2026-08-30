import SwiftUI
import SetCatcherCore

struct HistoryImportView: View {
    @EnvironmentObject private var model: AppModel
    let result: SoftwareProbeResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Track History")
                    .font(.headline)

                Spacer()

                Button {
                    model.importHistory(appID: result.software.id)
                } label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
                .help("Import a history or tracklist export for \(result.software.displayName).")
                .accessibilityIdentifier("historyImport.\(result.software.id).import")
            }

            let imports = model.importedTracklists(for: result.software.id)

            if !imports.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(imports) { imported in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("\(kindLabel(imported.kind)) | \(imported.tracks.count) track\(imported.tracks.count == 1 ? "" : "s") from \(imported.sourceURL.lastPathComponent)")
                                    .foregroundStyle(.secondary)

                                Spacer()

                                Button {
                                    model.deleteImportedTracklist(id: imported.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .help("Delete this imported tracklist from SetCatcher. The original file is not changed.")
                                .accessibilityIdentifier("historyImport.\(result.software.id).\(imported.id).delete")
                            }

                            ForEach(imported.tracks.prefix(5)) { track in
                                HStack {
                                    Text(track.artist.isEmpty ? "Unknown Artist" : track.artist)
                                        .frame(width: 180, alignment: .leading)
                                    Text(track.title)
                                    Spacer()
                                    if let startTime = track.startTime {
                                        Text(startTime)
                                            .font(.caption.monospacedDigit())
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .font(.callout)
                            }
                        }
                        .padding(14)
                        .background(DJToken.card, in: RoundedRectangle(cornerRadius: DJToken.Radius.control))
                        .overlay(
                            RoundedRectangle(cornerRadius: DJToken.Radius.control)
                                .stroke(DJToken.border, lineWidth: 1)
                        )
                        .help(imported.sourceURL.path)
                    }
                }
            } else {
                EmptyStateView(
                    title: "No track history imported",
                    systemImage: "list.bullet.rectangle",
                    description: historyPrompt(for: result.software.id),
                    primaryTitle: "Import",
                    primaryAction: { model.importHistory(appID: result.software.id) }
                )
                .frame(minHeight: 120)
            }
        }
    }

    private func kindLabel(_ kind: ImportedTracklistKind) -> String {
        switch kind {
        case .setHistory:
            return "Set history"
        case .collection:
            return "Collection"
        }
    }

    private func historyPrompt(for appID: String) -> String {
        switch appID {
        case "serato":
            return "Import a Serato History Export CSV or text file to preview tracklist parsing."
        case "rekordbox":
            return "Import a rekordbox XML or history export to test metadata compatibility."
        case "traktor":
            return "Import a Traktor NML history playlist to preview tracklist parsing."
        case "virtualdj":
            return "Import a VirtualDJ history, M3U, XML, or .vdjfolder file to preview tracklist parsing."
        default:
            return "History import is planned after Serato and rekordbox support."
        }
    }
}

import SwiftUI
import SetCatcherCore

struct SetDetailView: View {
    @EnvironmentObject private var model: AppModel
    let summary: LibrarySessionSummary
    let appName: String
    let candidateTracklists: [ImportedTracklist]
    let activityEvents: [ActivityEvent]
    let saveContext: (SetContext) -> Void
    let attachTracklist: (UUID?) -> Void
    let importTracklist: () -> Void
    let exportPublishPack: () -> Void
    let revealArchive: () -> Void
    let revealSource: () -> Void
    let revealHardwareBackup: () -> Void

    @State private var draftContext: SetContext
    @State private var selectedTracklistID: UUID?

    init(
        summary: LibrarySessionSummary,
        appName: String,
        candidateTracklists: [ImportedTracklist],
        activityEvents: [ActivityEvent],
        saveContext: @escaping (SetContext) -> Void,
        attachTracklist: @escaping (UUID?) -> Void,
        importTracklist: @escaping () -> Void = {},
        exportPublishPack: @escaping () -> Void = {},
        revealArchive: @escaping () -> Void,
        revealSource: @escaping () -> Void,
        revealHardwareBackup: @escaping () -> Void = {}
    ) {
        self.summary = summary
        self.appName = appName
        self.candidateTracklists = candidateTracklists
        self.activityEvents = activityEvents
        self.saveContext = saveContext
        self.attachTracklist = attachTracklist
        self.importTracklist = importTracklist
        self.exportPublishPack = exportPublishPack
        self.revealArchive = revealArchive
        self.revealSource = revealSource
        self.revealHardwareBackup = revealHardwareBackup
        _draftContext = State(initialValue: summary.context)
        _selectedTracklistID = State(initialValue: summary.matchedTracklist?.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SetDetailSourcesView(
                summary: summary,
                appName: appName,
                revealArchive: revealArchive,
                revealSource: revealSource,
                revealHardwareBackup: revealHardwareBackup
            )

            SetDetailPlaybackView(
                sessionID: summary.id,
                seed: summary.archive.originalFilename,
                tint: DJToken.accent(forAppID: summary.archive.sourceAppID),
                state: model.playbackState,
                togglePlayback: {
                    model.togglePlayback(
                        sessionID: summary.id,
                        url: URL(fileURLWithPath: summary.archive.archivePath)
                    )
                },
                seek: { model.seekPlayback(sessionID: summary.id, progress: $0) },
                retry: {
                    model.stopPlayback(sessionID: summary.id)
                    model.togglePlayback(
                        sessionID: summary.id,
                        url: URL(fileURLWithPath: summary.archive.archivePath)
                    )
                },
                openArchiveFolder: model.openArchiveFolder
            )

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    detailField("Event", text: $draftContext.eventName)
                    detailField("Venue", text: $draftContext.venue)
                }

                GridRow {
                    detailField("City", text: $draftContext.city)
                    detailField("Tags", text: $draftContext.tags)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Notes")
                    .font(.callout.weight(.medium))
                TextEditor(text: $draftContext.notes)
                    .font(.callout)
                    .frame(minHeight: 72)
                    .scrollContentBackground(.hidden)
                    .background(DJToken.muted, in: RoundedRectangle(cornerRadius: DJToken.Radius.control))
                    .overlay(
                        RoundedRectangle(cornerRadius: DJToken.Radius.control)
                            .stroke(DJToken.border, lineWidth: 1)
                    )
                    .help("Private local notes for this archived set.")
            }

            HStack {
                Picker("Tracklist", selection: $selectedTracklistID) {
                    Text(summary.matchedTracklist == nil ? "Automatic / None" : "Automatic match").tag(Optional<UUID>.none)
                    ForEach(candidateTracklists) { tracklist in
                        Text("\(tracklist.sourceURL.lastPathComponent) (\(tracklist.tracks.count))")
                            .tag(Optional(tracklist.id))
                    }
                }
                .help("Manually attach a set-history import when the automatic match is missing or wrong.")

                Button {
                    attachTracklist(selectedTracklistID)
                } label: {
                    Label("Apply Match", systemImage: "link")
                }
                .disabled(selectedTracklistID == summary.context.manualTracklistID)
                .help("Save this tracklist match for the selected archived set.")
                .accessibilityIdentifier("setDetail.\(summary.id).applyMatch")

                Button {
                    selectedTracklistID = nil
                    attachTracklist(nil)
                } label: {
                    Label("Detach", systemImage: "link.badge.minus")
                }
                .disabled(summary.matchedTracklist == nil && summary.context.manualTracklistID == nil)
                .help("Remove the manual tracklist attachment for this set.")
                .accessibilityIdentifier("setDetail.\(summary.id).detachMatch")

                Button(action: importTracklist) {
                    Label("Import Tracklist", systemImage: "square.and.arrow.down")
                }
                .help("Import a history or USB export, then attach it to this set.")
                .accessibilityIdentifier("setDetail.\(summary.id).importTracklist")

                Button(action: exportPublishPack) {
                    Label("Export Pack", systemImage: "square.and.arrow.up")
                }
                .help("Export a local publish pack. Nothing is uploaded.")
                .accessibilityIdentifier("setDetail.\(summary.id).exportPack")

                Spacer()

                Button {
                    draftContext.manualTracklistID = selectedTracklistID
                    saveContext(draftContext)
                } label: {
                    Label("Save Details", systemImage: "square.and.arrow.down")
                }
                .keyboardShortcut("s", modifiers: [.command])
                .help("Save event, venue, city, tags, notes, and manual tracklist selection.")
                .accessibilityIdentifier("setDetail.\(summary.id).saveDetails")
            }

            if let tracklist = summary.matchedTracklist {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text("Tracklist")
                            .font(.callout.weight(.medium))
                        Badge(
                            title: summary.tracklistMatchOrigin == .manual ? "Manual" : "Auto matched",
                            tone: summary.tracklistMatchOrigin == .manual ? .info : .ok
                        )
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("setDetail.\(summary.id).tracklistMatchOrigin")

                    ForEach(tracklist.tracks.prefix(6)) { track in
                        HStack {
                            Text(track.artist.isEmpty ? "Unknown Artist" : track.artist)
                                .frame(width: 180, alignment: .leading)
                                .foregroundStyle(track.artist.isEmpty ? .secondary : .primary)
                            Text(track.title.isEmpty ? "Unknown title" : track.title)
                            Spacer()
                            Text(track.startTime ?? "")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .font(.callout)
                    }
                }
            }

            if !activityEvents.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Related Activity")
                        .font(.callout.weight(.medium))

                    ForEach(activityEvents.prefix(5)) { event in
                        Text("\(event.createdAt.formatted(date: .abbreviated, time: .shortened)) - \(event.message)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .help([event.message, event.detail].compactMap { $0 }.joined(separator: "\n"))
                    }
                }
            }
        }
        .padding(14)
        .background(DJToken.card, in: RoundedRectangle(cornerRadius: DJToken.Radius.control))
        .overlay(
            RoundedRectangle(cornerRadius: DJToken.Radius.control)
                .stroke(DJToken.border, lineWidth: 1)
        )
        .onChange(of: summary.id) { oldID, _ in
            model.stopPlayback(sessionID: oldID)
            draftContext = summary.context
            selectedTracklistID = summary.matchedTracklist?.id
        }
        .onDisappear {
            model.stopPlayback(sessionID: summary.id)
        }
    }

    private func detailField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.callout.weight(.medium))
            TextField(title, text: text)
                .textFieldStyle(.roundedBorder)
                .help(title)
        }
    }
}

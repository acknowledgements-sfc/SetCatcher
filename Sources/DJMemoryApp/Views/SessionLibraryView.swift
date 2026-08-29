import SwiftUI
import DJMemoryCore

struct SessionLibraryView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selectedSessionID: LibrarySessionSummary.ID?
    @State private var selectedTracklistID: ImportedTracklist.ID?
    @State private var sessionSearch = ""
    @State private var trackSearch = ""
    @State private var segment: LibrarySegment = .archivedSets
    @State private var dateFilter: LibraryDateFilter = .all

    private enum LibrarySegment: String, CaseIterable {
        case archivedSets = "Archived Sets"
        case importedTracklists = "Imported Tracklists"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text("Library")
                    .font(.system(size: DJToken.TypeSize.title, weight: .semibold))
                    .foregroundStyle(DJToken.foreground)

                Picker("Library", selection: $segment) {
                    ForEach(LibrarySegment.allCases, id: \.self) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 360)
                .accessibilityLabel("Library")
                .accessibilityIdentifier("library.segment")

                Spacer()

                Picker("Date", selection: $dateFilter) {
                    ForEach(LibraryDateFilter.menuCases, id: \.displayName) { filter in
                        Text(filter.displayName).tag(filter)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 120)
                .accessibilityLabel("Date")
                .accessibilityIdentifier("library.dateFilter")

                TextField(segment == .archivedSets ? "Search archived sets" : "Search tracklists", text: $sessionSearch)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 260)
                    .help("Filter by recording name, event, venue, city, tags, or app.")
                    .accessibilityLabel(segment == .archivedSets ? "Search archived sets" : "Search tracklists")
                    .accessibilityIdentifier("library.archivedSets.search")
            }

            HStack(alignment: .top, spacing: 12) {
                Group {
                    if segment == .archivedSets {
                        archivedTable
                    } else {
                        tracklistTable
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                inspector
                    .frame(width: 352)
            }
            .frame(minHeight: 480)
        }
        .onChange(of: selectedTracklistID) { trackSearch = "" }
        .onChange(of: sessionSearch) {
            selectedSessionID = LibrarySelection.retainingIfPresent(
                selectedSessionID,
                among: filteredLibrarySummaries.map(\.id)
            )
        }
        .onChange(of: dateFilter) {
            selectedSessionID = LibrarySelection.retainingIfPresent(
                selectedSessionID,
                among: filteredLibrarySummaries.map(\.id)
            )
            selectedTracklistID = LibrarySelection.retainingIfPresent(
                selectedTracklistID,
                among: filteredTracklists.map(\.id)
            )
        }
        .onChange(of: model.librarySummaries.map(\.id)) { _, ids in
            selectedSessionID = LibrarySelection.retainingIfPresent(selectedSessionID, among: ids)
        }
        .onChange(of: model.allImportedTracklists.map(\.id)) { _, ids in
            selectedTracklistID = LibrarySelection.retainingIfPresent(selectedTracklistID, among: ids)
        }
        .onAppear { applyLibraryFocusIfNeeded() }
        .onChange(of: model.selectedRoute) { _, newRoute in
            if newRoute == .library {
                applyLibraryFocusIfNeeded()
            }
        }
    }

    private func applyLibraryFocusIfNeeded() {
        let focus = model.consumeLibraryFocus()
        if !focus.search.isEmpty {
            sessionSearch = focus.search
            segment = .archivedSets
        }
        if let sessionID = focus.sessionID {
            selectedSessionID = sessionID
            segment = .archivedSets
        }
    }

    @ViewBuilder
    private var archivedTable: some View {
        if model.librarySummaries.isEmpty {
            EmptyStateView(
                title: "No archived sets yet",
                systemImage: "music.note",
                description: "Choose a recordings folder and run Rescan Last 24 Hours to archive completed audio files.",
                primaryTitle: "Open Protection",
                primaryAction: { model.selectedRoute = .protection }
            )
        } else if filteredLibrarySummaries.isEmpty {
            EmptyStateView(
                title: dateFilter == .all
                    ? "Nothing matches “\(sessionSearch)”"
                    : "Nothing matches this date filter",
                systemImage: "magnifyingglass",
                description: dateFilter == .all
                    ? "Try a different recording name, event, venue, city, tag, or app."
                    : "Try All dates, or clear search."
            )
        } else {
            Table(filteredLibrarySummaries, selection: $selectedSessionID) {
                TableColumn("Recording") { summary in
                    HStack(spacing: 8) {
                        Waveform(
                            seed: summary.archive.originalFilename,
                            barCount: 28,
                            tint: DJToken.accent(forAppID: summary.archive.sourceAppID)
                        )
                        .frame(width: 56, height: 18)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(summary.archive.originalFilename)
                                .font(.system(size: DJToken.TypeSize.body, weight: .medium))
                                .lineLimit(1)
                            Text(contextLine(summary))
                                .font(.system(size: DJToken.TypeSize.secondary))
                                .foregroundStyle(DJToken.mutedForeground)
                                .lineLimit(1)
                        }
                    }
                }
                .width(min: 220)

                TableColumn("Date") { summary in
                    Text(formatArchiveDate(summary.archive.detectedAt))
                        .monospacedDigit()
                }
                .width(88)

                TableColumn("App") { summary in
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: DJToken.Radius.swatch)
                            .fill(DJToken.accent(forAppID: summary.archive.sourceAppID))
                            .frame(width: 3, height: 12)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(model.displayName(for: summary.archive.sourceAppID))
                            if summary.hardwareBackup != nil {
                                Text("2 safety nets")
                                    .font(.system(size: DJToken.TypeSize.secondary))
                                    .foregroundStyle(DJToken.mutedForeground)
                            }
                        }
                    }
                }
                .width(min: 100)

                TableColumn("Tracks") { summary in
                    Text(summary.matchedTracklist == nil ? "—" : "\(summary.trackCount)")
                        .monospacedDigit()
                }
                .width(60)

                TableColumn("Duration") { summary in
                    Text(formatDuration(summary.archive.durationSeconds))
                        .monospacedDigit()
                }
                .width(70)

                TableColumn("Size") { summary in
                    Text(formatBytes(summary.archive.fileSize))
                        .monospacedDigit()
                }
                .width(70)

                TableColumn("Matched Tracklist") { summary in
                    Badge(
                        title: summary.matchedTracklist == nil ? "Unmatched" : "Matched",
                        tone: summary.matchedTracklist == nil ? .warn : .ok
                    )
                }
                .width(110)
            }
        }
    }

    @ViewBuilder
    private var tracklistTable: some View {
        if model.allImportedTracklists.isEmpty {
            EmptyStateView(
                title: "No imported tracklists yet",
                systemImage: "list.bullet.rectangle",
                description: "Import Serato CSV/TXT or rekordbox XML files from a setup card."
            )
        } else if filteredTracklists.isEmpty {
            EmptyStateView(
                title: dateFilter == .all
                    ? "Nothing matches “\(sessionSearch)”"
                    : "Nothing matches this date filter",
                systemImage: "magnifyingglass",
                description: dateFilter == .all
                    ? "Try a different file name or app."
                    : "Try All dates, or clear search."
            )
        } else {
            Table(filteredTracklists, selection: $selectedTracklistID) {
                TableColumn("File") { tracklist in
                    Text(tracklist.sourceURL.lastPathComponent)
                        .help(tracklist.sourceURL.path)
                }
                TableColumn("Date") { tracklist in
                    Text(formatArchiveDate(tracklistDate(for: tracklist)))
                        .monospacedDigit()
                }
                .width(88)
                TableColumn("App") { tracklist in
                    Text(model.displayName(for: tracklist.appID))
                }
                TableColumn("Tracks") { tracklist in
                    Text("\(tracklist.tracks.count)").monospacedDigit()
                }
                TableColumn("Kind") { tracklist in
                    Badge(
                        title: tracklist.kind == .setHistory ? "Set History" : "Collection",
                        tone: .neutral
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var inspector: some View {
        Panel(title: "Inspector", padding: 0) {
            ScrollView {
                Group {
                    if segment == .archivedSets {
                        if let summary = selectedSession {
                            SetDetailView(
                                summary: summary,
                                appName: model.displayName(for: summary.archive.sourceAppID),
                                candidateTracklists: model.candidateTracklists(for: summary.archive),
                                activityEvents: summary.relatedActivity(in: model.activityEvents),
                                saveContext: model.saveSetContext,
                                attachTracklist: { model.attachTracklist(sessionID: summary.id, tracklistID: $0) },
                                importTracklist: { model.importHistory(appID: summary.archive.sourceAppID) },
                                exportPublishPack: { model.exportPublishPack(sessionID: summary.id) },
                                revealArchive: { model.revealInFinder(URL(fileURLWithPath: summary.archive.archivePath)) },
                                revealSource: { model.revealInFinder(URL(fileURLWithPath: summary.archive.sourcePath)) },
                                revealHardwareBackup: {
                                    guard let path = summary.hardwareBackup?.archivePath else { return }
                                    model.revealInFinder(URL(fileURLWithPath: path))
                                }
                            )
                        } else {
                            Text("Select an archived set to review details, notes, and tracklist matching.")
                                .font(.system(size: DJToken.TypeSize.body))
                                .foregroundStyle(DJToken.mutedForeground)
                                .padding(14)
                        }
                    } else if let tracklist = selectedTracklist {
                        TracklistDetailView(
                            tracklist: tracklist,
                            appName: model.displayName(for: tracklist.appID),
                            searchText: $trackSearch,
                            revealInFinder: { model.revealInFinder(tracklist.sourceURL) }
                        )
                        .padding(8)
                    } else {
                        Text("Select an imported tracklist to browse its tracks.")
                            .font(.system(size: DJToken.TypeSize.body))
                            .foregroundStyle(DJToken.mutedForeground)
                            .padding(14)
                    }
                }
            }
        }
    }

    private var filteredLibrarySummaries: [LibrarySessionSummary] {
        LibrarySessionSearch().filter(
            model.librarySummaries,
            query: sessionSearch,
            dateFilter: dateFilter,
            appDisplayName: model.displayName(for:)
        )
    }

    private var matchedSetDatesByTracklistID: [UUID: Date] {
        var map: [UUID: Date] = [:]
        for summary in model.librarySummaries {
            if let tracklist = summary.matchedTracklist {
                map[tracklist.id] = summary.archive.detectedAt
            }
        }
        return map
    }

    private var filteredTracklists: [ImportedTracklist] {
        LibrarySessionSearch().filterTracklists(
            model.allImportedTracklists,
            query: sessionSearch,
            dateFilter: dateFilter,
            matchedSetDates: matchedSetDatesByTracklistID,
            appDisplayName: model.displayName(for:)
        )
    }

    private var selectedSession: LibrarySessionSummary? {
        guard let selectedSessionID else { return nil }
        return filteredLibrarySummaries.first { $0.id == selectedSessionID }
    }

    private var selectedTracklist: ImportedTracklist? {
        guard let selectedTracklistID else { return nil }
        return filteredTracklists.first { $0.id == selectedTracklistID }
            ?? model.allImportedTracklists.first { $0.id == selectedTracklistID }
    }

    private func tracklistDate(for tracklist: ImportedTracklist) -> Date {
        if let matched = matchedSetDatesByTracklistID[tracklist.id] {
            return matched
        }
        if let playedOn = tracklist.tracks.compactMap(\.playedOn).first {
            return playedOn
        }
        return tracklist.importedAt
    }

    private func contextLine(_ summary: LibrarySessionSummary) -> String {
        let parts = [summary.context.eventName, [summary.context.venue, summary.context.city].filter { !$0.isEmpty }.joined(separator: ", ")]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? summary.archive.originalFilename : parts.joined(separator: " · ")
    }

    private func formatArchiveDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func formatDuration(_ seconds: Double?) -> String {
        guard let seconds else { return "—" }
        let totalSeconds = Int(seconds.rounded())
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let remainingSeconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        }
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

#Preview("Library no archived sets / light") {
    SessionLibraryView()
        .environmentObject(AppModel())
        .padding()
        .frame(width: 1000, height: 640)
        .preferredColorScheme(.light)
}

#Preview("Library no archived sets / dark") {
    SessionLibraryView()
        .environmentObject(AppModel())
        .padding()
        .frame(width: 1000, height: 640)
        .preferredColorScheme(.dark)
}

#Preview("Library matched + unmatched / light") {
    libraryMatchedPreview(scheme: .light)
}

#Preview("Library no search results / dark") {
    librarySeededPreview(scheme: .dark)
}

@MainActor
private func libraryMatchedPreview(scheme: ColorScheme) -> some View {
    let model = AppModel()
    let matched = PreviewFixtures.archive(id: UUID(), filename: "Matched.wav", matched: true)
    let unmatched = PreviewFixtures.archive(
        id: UUID(),
        filename: "Unmatched.wav",
        matched: false,
        event: "",
        venue: "",
        city: "",
        notes: "",
        tags: ""
    )
    let collection = ImportedTracklist(
        appID: "rekordbox",
        sourceURL: URL(fileURLWithPath: "/tmp/collection.xml"),
        kind: .collection,
        tracks: [TrackPlay(title: "A", artist: "B", startTime: nil, source: "p", confidence: 1)]
    )
    model.previewApplyLibrary(
        archives: [matched.0, unmatched.0],
        summaries: [matched.1, unmatched.1],
        imported: [matched.3, collection].compactMap { $0 },
        contexts: [matched.2, unmatched.2]
    )
    return SessionLibraryView()
        .environmentObject(model)
        .padding()
        .frame(width: 1100, height: 700)
        .preferredColorScheme(scheme)
}

@MainActor
private func librarySeededPreview(scheme: ColorScheme) -> some View {
    let model = AppModel()
    let sample = PreviewFixtures.archive()
    model.previewApplyLibrary(archives: [sample.0], summaries: [sample.1], contexts: [sample.2])
    return SessionLibraryView()
        .environmentObject(model)
        .padding()
        .frame(width: 1100, height: 700)
        .preferredColorScheme(scheme)
}

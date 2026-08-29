import SwiftUI
import DJMemoryCore

struct ActivityLogView: View {
    @EnvironmentObject private var model: AppModel
    @State private var filter: ActivityFilter = .all

    private enum ActivityFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case scans = "Scans"
        case archives = "Archives"
        case imports = "Imports"
        case errors = "Errors"
        case diagnostics = "Diagnostics"

        var id: String { rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Activity")
                    .font(.system(size: DJToken.TypeSize.title, weight: .semibold))
                    .foregroundStyle(DJToken.foreground)

                Spacer()

                Button {
                    model.exportDiagnostics()
                } label: {
                    Label("Export Diagnostics", systemImage: "doc.badge.gearshape")
                }
                .buttonStyle(DJSecondaryButtonStyle())
                .help("Save a JSON diagnostics report for troubleshooting DJMemory setup and library state.")
                .accessibilityIdentifier("activity.exportDiagnostics")

                Button {
                    model.clearActivity()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .buttonStyle(DJDangerButtonStyle())
                .disabled(model.activityEvents.isEmpty)
                .help("Clear the local activity log.")
                .accessibilityIdentifier("activity.clear")
            }

            Picker("Filter", selection: $filter) {
                ForEach(ActivityFilter.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Filter")
            .accessibilityIdentifier("activity.filter")

            if filteredEvents.isEmpty {
                EmptyStateView(
                    title: "No activity yet",
                    systemImage: "clock",
                    description: "Scans, imports, archive events, and errors will appear here."
                )
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(filteredEvents) { event in
                        activityRow(event)
                    }
                }
            }

            Text("Exported diagnostics contain paths, timings, and error messages only — no audio and no tracklist contents.")
                .font(.system(size: DJToken.TypeSize.secondary))
                .foregroundStyle(DJToken.mutedForeground)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var filteredEvents: [ActivityEvent] {
        switch filter {
        case .all:
            return model.activityEvents
        case .scans:
            return model.activityEvents.filter { $0.kind == .scan }
        case .archives:
            return model.activityEvents.filter { $0.kind == .archive || $0.kind == .capture }
        case .imports:
            return model.activityEvents.filter { $0.kind == .importTracklist }
        case .errors:
            return model.activityEvents.filter { $0.kind == .error }
        case .diagnostics:
            return model.activityEvents.filter { $0.kind == .diagnostics }
        }
    }

    private func activityRow(_ event: ActivityEvent) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbolName(for: event.kind))
                .foregroundStyle(color(for: event.kind))
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.message)
                    .font(.system(size: DJToken.TypeSize.body, weight: .medium))
                    .foregroundStyle(DJToken.foreground)

                if let detail = event.detail {
                    Text(detail)
                        .font(.system(size: DJToken.TypeSize.secondary))
                        .foregroundStyle(DJToken.mutedForeground)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
            }

            Spacer()

            if event.kind == .error {
                Button("Fix Folder") {
                    if let appID = recoveryAppID(for: event) {
                        model.selectedRoute = .recovery(appID)
                    } else {
                        model.selectedRoute = .protection
                    }
                }
                .buttonStyle(DJPrimaryButtonStyle())
                .accessibilityIdentifier("activity.error.\(event.id).fix")
            }

            Text(event.createdAt, style: .time)
                .font(.system(size: DJToken.TypeSize.secondary).monospacedDigit())
                .foregroundStyle(DJToken.mutedForeground)
        }
        .padding(12)
        .background(
            (event.kind == .error ? DJToken.danger.opacity(0.06) : DJToken.card),
            in: RoundedRectangle(cornerRadius: DJToken.Radius.control)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DJToken.Radius.control)
                .stroke(DJToken.border, lineWidth: 1)
        )
        .help([event.message, event.detail].compactMap { $0 }.joined(separator: "\n"))
    }

    private func recoveryAppID(for event: ActivityEvent) -> String? {
        let haystack = [event.message, event.detail].compactMap { $0 }.joined(separator: " ").lowercased()
        return model.probeResults.map(\.software).first { haystack.contains($0.id) || haystack.contains($0.displayName.lowercased()) }?.id
    }

    private func symbolName(for kind: ActivityEventKind) -> String {
        switch kind {
        case .archive: return "tray.and.arrow.down"
        case .importTracklist: return "list.bullet.rectangle"
        case .scan: return "waveform.badge.magnifyingglass"
        case .error: return "exclamationmark.triangle"
        case .diagnostics: return "doc.badge.gearshape"
        case .capture: return "mic.fill"
        }
    }

    private func color(for kind: ActivityEventKind) -> Color {
        switch kind {
        case .archive, .capture: return DJToken.ok
        case .importTracklist: return DJToken.primary
        case .scan, .diagnostics: return DJToken.mutedForeground
        case .error: return DJToken.danger
        }
    }
}

#Preview("Activity empty / light") {
    ActivityLogView()
        .environmentObject(AppModel())
        .padding()
        .frame(width: 720, height: 480)
        .preferredColorScheme(.light)
}

#Preview("Activity empty / dark") {
    ActivityLogView()
        .environmentObject(AppModel())
        .padding()
        .frame(width: 720, height: 480)
        .preferredColorScheme(.dark)
}

#Preview("Activity all kinds / light") {
    activityKindsPreview(scheme: .light)
}

#Preview("Activity all kinds / dark") {
    activityKindsPreview(scheme: .dark)
}

@MainActor
private func activityKindsPreview(scheme: ColorScheme) -> some View {
    let model = AppModel()
    model.previewApplyLibrary(activity: PreviewFixtures.activityKinds())
    return ActivityLogView()
        .environmentObject(model)
        .padding()
        .frame(width: 720, height: 560)
        .preferredColorScheme(scheme)
}

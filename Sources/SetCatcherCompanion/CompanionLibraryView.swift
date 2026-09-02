import SetCatcherCore
import SwiftUI

struct CompanionLibraryView: View {
    @Bindable var model: CompanionModel
    @State private var selectedSessionID: UUID?

    var body: some View {
        NavigationStack {
            Group {
                if model.sessions.isEmpty {
                    ContentUnavailableView {
                        Label("No sets archived yet", systemImage: "rectangle.stack")
                    } description: {
                        Text("Import a recording from an iPad DJ app (djay first) via Files or Share, or use Capture on this iPad. Sign in to sync set metadata across your Mac and iPad — audio stays on each device unless you enable backup.")
                    } actions: {
                        Button("Import") {
                            model.selectedRoute = .importSets
                        }
                        .accessibilityIdentifier("ipad.library.emptyImport")
                    }
                } else {
                    List(selection: $selectedSessionID) {
                        ForEach(model.sessions) { session in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.originalFilename)
                                    .font(.body.weight(.medium))
                                Text("\(MobileDJSoftware.displayName(for: session.sourceAppID)) · \(session.detectedAt.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                                if case .remoteOnly(let origin) = model.catalogAvailability(for: session.sessionID) {
                                    Text(remoteCatalogCaption(originDeviceName: origin))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .tag(Optional(session.sessionID))
                            .accessibilityIdentifier("ipad.library.row.\(session.sessionID.uuidString)")
                        }
                    }
                }
            }
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Refresh", systemImage: "arrow.clockwise") {
                        model.refresh()
                    }
                    .accessibilityIdentifier("ipad.library.refresh")
                }
            }
            .navigationDestination(item: $selectedSessionID) { sessionID in
                CompanionSetDetailView(model: model, sessionID: sessionID)
            }
        }
    }

    private func remoteCatalogCaption(originDeviceName: String?) -> String {
        if let originDeviceName, !originDeviceName.isEmpty {
            return "On another device (\(originDeviceName)). Audio is not on this iPad."
        }
        return "On another device. Audio is not on this iPad."
    }
}

#Preview("Empty") {
    CompanionLibraryView(model: CompanionModel())
}

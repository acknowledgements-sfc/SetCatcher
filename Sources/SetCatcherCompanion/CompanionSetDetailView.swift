import SetCatcherCore
import SwiftUI

struct CompanionSetDetailView: View {
    @Bindable var model: CompanionModel
    let sessionID: UUID
    @State private var draft: SetContext

    init(model: CompanionModel, sessionID: UUID) {
        self.model = model
        self.sessionID = sessionID
        _draft = State(initialValue: model.context(for: sessionID))
    }

    var body: some View {
        Form {
            if let session = model.sessions.first(where: { $0.sessionID == sessionID }) {
                Section("Recording") {
                    LabeledContent("File", value: session.originalFilename)
                    LabeledContent("App", value: MobileDJSoftware.displayName(for: session.sourceAppID))
                    LabeledContent("Size", value: ByteCountFormatter.string(fromByteCount: session.fileSize, countStyle: .file))
                    Text(session.archivePath)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }

            Section("Set details") {
                TextField("Event", text: $draft.eventName)
                TextField("Venue", text: $draft.venue)
                TextField("City", text: $draft.city)
                TextField("Tags", text: $draft.tags)
                TextField("Notes", text: $draft.notes, axis: .vertical)
                    .lineLimit(3...6)
            }
        }
        .navigationTitle("Set")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    model.saveContext(draft)
                }
                .accessibilityIdentifier("ipad.setDetail.save")
            }
        }
    }
}

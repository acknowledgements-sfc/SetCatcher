import SwiftUI
import UniformTypeIdentifiers

struct CompanionImportView: View {
    @Bindable var model: CompanionModel
    @State private var showImporter = false
    @State private var selectedApp: MobileDJSoftware = .djay

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("This iPad cannot watch Serato or other desktop DJ folders. Import recordings from Files, or use Share → Save to SetCatcher.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Source") {
                    Picker("App", selection: $selectedApp) {
                        ForEach(MobileDJSoftware.allCases.filter { $0 != .capture }) { app in
                            Text("\(app.displayName) · \(app.supportLabel)").tag(app)
                        }
                    }
                    .accessibilityIdentifier("ipad.import.appPicker")

                    Text(selectedApp.guidance)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button {
                        showImporter = true
                    } label: {
                        Label(
                            model.isImporting ? "Importing…" : "Choose Audio from Files",
                            systemImage: "folder"
                        )
                    }
                    .disabled(model.isImporting)
                    .accessibilityIdentifier("ipad.import.chooseFiles")
                }

                Section("djay tips") {
                    Text("Files → On My iPad → djay")
                        .font(.body.monospaced())
                    Text("After a set, Share the recording and choose Save to SetCatcher when the extension is installed.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Import")
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.audio, .wav, .mp3, .mpeg4Audio],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    model.importAudioURLs(urls, appID: selectedApp.id)
                case .failure(let error):
                    model.statusMessage = "Could not open Files: \(error.localizedDescription)"
                }
            }
        }
    }
}

#Preview {
    CompanionImportView(model: CompanionModel())
}

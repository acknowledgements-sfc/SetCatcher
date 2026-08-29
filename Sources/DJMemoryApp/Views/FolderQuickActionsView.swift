import SwiftUI
import DJMemoryCore

struct FolderQuickActionsView: View {
    @EnvironmentObject private var model: AppModel
    let result: SoftwareProbeResult

    var body: some View {
        HStack(spacing: 10) {
            Button {
                model.chooseFolder(appID: result.software.id, kind: .recordings)
            } label: {
                Label(recordingButtonTitle, systemImage: "folder.badge.plus")
            }
            .controlSize(.large)
            .help("Set the folder SetCatcher scans for completed recordings.")
            .accessibilityIdentifier("setup.\(result.software.id).recordingFolder")

            Button {
                model.chooseFolder(appID: result.software.id, kind: .history)
            } label: {
                Label(historyButtonTitle, systemImage: "list.bullet.rectangle")
            }
            .controlSize(.large)
            .help("Set the folder where SetCatcher can find history exports.")
            .accessibilityIdentifier("setup.\(result.software.id).historyFolder")

            Spacer()
        }
    }

    private var recordingButtonTitle: String {
        model.configuredRecordingFolders(for: result.software.id).isEmpty
            ? "Set Recording Folder"
            : "Change Recording Folder"
    }

    private var historyButtonTitle: String {
        model.historyFolders(for: result.software.id).isEmpty ? "Set History Folder" : "Change History Folder"
    }
}

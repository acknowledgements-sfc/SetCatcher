import SwiftUI
import SetCatcherCore

struct FolderSetupView: View {
    @EnvironmentObject private var model: AppModel
    let result: SoftwareProbeResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Folders")
                .font(.headline)

            FolderRow(
                title: "Recordings",
                accessibilityPrefix: "folderAccess.\(result.software.id).recordings",
                folders: model.recordingFolders(for: result.software.id),
                chooseAction: { model.chooseFolder(appID: result.software.id, kind: .recordings) },
                clearAction: { model.clearFolder(appID: result.software.id, kind: .recordings) },
                revealAction: { model.revealInFinder($0) }
            )

            FolderRow(
                title: "History",
                accessibilityPrefix: "folderAccess.\(result.software.id).history",
                folders: model.historyFolders(for: result.software.id),
                chooseAction: { model.chooseFolder(appID: result.software.id, kind: .history) },
                clearAction: { model.clearFolder(appID: result.software.id, kind: .history) },
                revealAction: { model.revealInFinder($0) }
            )
        }
    }
}

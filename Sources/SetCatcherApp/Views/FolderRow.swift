import SwiftUI
import SetCatcherCore

struct FolderRow: View {
    let title: String
    let accessibilityPrefix: String
    let folders: [URL]
    let chooseAction: () -> Void
    let clearAction: () -> Void
    let revealAction: (URL) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: DJToken.TypeSize.body, weight: .medium))
                    .foregroundStyle(DJToken.foreground)

                if folders.isEmpty {
                    PathChip(path: "No folder selected", tone: .warn)
                } else {
                    ForEach(folders, id: \.self) { folder in
                        PathChip(
                            path: folder.path,
                            tone: folderIsReachable(folder) ? .neutral : .danger
                        )
                    }
                }
            }

            Spacer()

            Button {
                chooseAction()
            } label: {
                Label("Choose", systemImage: "folder.badge.plus")
            }
            .buttonStyle(DJSecondaryButtonStyle())
            .help("Choose the \(title.lowercased()) folder SetCatcher can access.")
            .accessibilityIdentifier("\(accessibilityPrefix).choose")

            Button {
                if let folder = folders.first {
                    revealAction(folder)
                }
            } label: {
                Label("Reveal", systemImage: "arrow.up.forward.app")
            }
            .buttonStyle(DJGhostButtonStyle())
            .disabled(folders.isEmpty)
            .help("Reveal the selected \(title.lowercased()) folder in Finder.")
            .accessibilityIdentifier("\(accessibilityPrefix).reveal")

            Button {
                clearAction()
            } label: {
                Label("Clear", systemImage: "xmark.circle")
            }
            .buttonStyle(DJDangerButtonStyle())
            .disabled(folders.isEmpty)
            .help("Forget the selected \(title.lowercased()) folder. Files are not deleted.")
            .accessibilityIdentifier("\(accessibilityPrefix).clear")
        }
        .padding(14)
        .background(DJToken.card, in: RoundedRectangle(cornerRadius: DJToken.Radius.control))
        .overlay(
            RoundedRectangle(cornerRadius: DJToken.Radius.control)
                .stroke(DJToken.border, lineWidth: 1)
        )
        .help(folderRowHelp)
    }

    private var folderRowHelp: String {
        if folders.isEmpty {
            return "No \(title.lowercased()) folder is selected yet."
        }

        let inaccessible = folders.filter { !folderIsReachable($0) }
        if !inaccessible.isEmpty {
            return "Some saved folders are not reachable. Choose the folder again to recover access.\n\(inaccessible.map(\.path).joined(separator: "\n"))"
        }

        return folders.map(\.path).joined(separator: "\n")
    }

    private func folderIsReachable(_ folder: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}

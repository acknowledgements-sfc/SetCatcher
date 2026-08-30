import SwiftUI

struct AppCommands: Commands {
    @ObservedObject var model: AppModel

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") {
                model.selectedRoute = .settings
            }
            .keyboardShortcut(",", modifiers: .command)
        }

        CommandGroup(replacing: .newItem) {}

        CommandGroup(after: .newItem) {
            Button(model.isScanning ? "Scanning…" : "Scan Now") {
                model.scanNow()
            }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(model.isScanning)

            Button("Refresh") {
                model.refresh()
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])

            Button("Open Archive Folder") {
                model.openArchiveFolder()
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])
        }

        CommandGroup(after: .sidebar) {
            Button("Back") {
                model.goBack()
            }
            .keyboardShortcut("[", modifiers: .command)
            .disabled(!model.canGoBack)

            Button("Forward") {
                model.goForward()
            }
            .keyboardShortcut("]", modifiers: .command)
            .disabled(!model.canGoForward)

            Divider()

            Button("Home") {
                model.selectedRoute = .home
            }
            .keyboardShortcut("1", modifiers: .command)

            Button("Protection") {
                model.selectedRoute = .protection
            }
            .keyboardShortcut("2", modifiers: .command)

            Button("Capture") {
                model.selectedRoute = .capture
            }
            .keyboardShortcut("3", modifiers: .command)

            Button("Library") {
                model.selectedRoute = .library
            }
            .keyboardShortcut("4", modifiers: .command)

            Button("Activity") {
                model.selectedRoute = .activity
            }
            .keyboardShortcut("5", modifiers: .command)

            Button("Settings") {
                model.selectedRoute = .settings
            }
            .keyboardShortcut("6", modifiers: .command)
        }
    }
}

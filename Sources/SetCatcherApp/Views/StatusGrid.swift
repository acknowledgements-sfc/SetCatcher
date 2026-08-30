import SwiftUI
import SetCatcherCore

struct StatusGrid: View {
    let result: SoftwareProbeResult
    let setupState: AppSetupState
    let recordingFolders: [URL]
    let historyFolders: [URL]

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 12) {
            GridRow {
                StatusTile(title: "State", value: setupState.displayName, symbol: stateSymbol, tone: tone(for: setupState))
                StatusTile(title: "App", value: appStatus, symbol: "macwindow")
                StatusTile(title: "Recordings", value: recordingStatus, symbol: "waveform", tone: recordingTone)
                StatusTile(title: "History", value: historyStatus, symbol: "list.bullet.rectangle")
            }
        }
    }

    private var appStatus: String {
        if result.software.bundleIdentifiers.isEmpty {
            return "Built-in"
        }

        if result.isRunning {
            return "Running"
        }

        return result.installedApplicationURLs.isEmpty ? "Not found" : "Found"
    }

    private var recordingStatus: String {
        if recordingFolders.isEmpty {
            return "Needs folder"
        }

        let hasReachableFolder = recordingFolders.contains { folder in
            var isDirectory: ObjCBool = false
            return FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDirectory) && isDirectory.boolValue
        }

        return hasReachableFolder ? "Ready" : "Needs recovery"
    }

    private var recordingTone: StatusTone {
        if recordingFolders.isEmpty { return .warn }
        return recordingStatus == "Ready" ? .ok : .danger
    }

    private var historyStatus: String {
        historyFolders.isEmpty ? "Optional" : "Found"
    }

    private var stateSymbol: String {
        switch setupState {
        case .archived:
            return "checkmark.seal"
        case .error, .attentionNeeded:
            return "exclamationmark.triangle"
        case .needsFolderAccess:
            return "folder.badge.questionmark"
        case .appNotFound:
            return "questionmark.app"
        case .saving:
            return "waveform.badge.magnifyingglass"
        case .recordingDetected:
            return "record.circle.fill"
        case .watching:
            return "record.circle"
        }
    }

    private func tone(for state: AppSetupState) -> StatusTone {
        switch state {
        case .watching, .archived:
            return .ok
        case .saving:
            return .info
        case .recordingDetected, .needsFolderAccess, .appNotFound:
            return .warn
        case .attentionNeeded, .error:
            return .danger
        }
    }
}

import SwiftUI
import SetCatcherCore

struct ProtectionSourceRow: View {
    let result: SoftwareProbeResult
    let state: AppSetupState
    let recordingFolders: [URL]
    let historyFolders: [URL]
    let chooseRecording: () -> Void
    let openSetup: () -> Void
    var fixFolder: (() -> Void)? = nil
    var scanNow: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: DJToken.Radius.swatch)
                .fill(DJToken.accent(forAppID: result.software.id))
                .frame(width: 3, height: 36)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(result.software.displayName)
                        .font(.system(size: DJToken.TypeSize.body, weight: .medium))
                        .foregroundStyle(DJToken.foreground)
                    SupportBadge(status: result.software.supportStatus)
                }

                HStack(spacing: 6) {
                    StatusDot(tone: sourceTone)
                    Text(state.displayName)
                        .font(.system(size: DJToken.TypeSize.secondary))
                        .foregroundStyle(DJToken.mutedForeground)
                }

                if let recordingFolder = recordingFolders.first {
                    PathChip(
                        path: recordingFolder.path,
                        tone: hasReachableRecordingFolder ? .neutral : .danger
                    )
                } else {
                    PathChip(path: "No folder selected", tone: .warn)
                }
            }

            Spacer(minLength: 8)

            if state == .attentionNeeded || state == .error, let fixFolder {
                Button("Fix Folder", action: fixFolder)
                    .buttonStyle(DJPrimaryButtonStyle())
                    .accessibilityIdentifier("protectionSource.\(result.software.id).fixFolder")
            } else if state == .needsFolderAccess {
                Button("Choose Folder", action: chooseRecording)
                    .buttonStyle(DJPrimaryButtonStyle())
                    .accessibilityIdentifier("protectionSource.\(result.software.id).chooseFolderPrimary")
            } else {
                Button(action: openSetup) {
                    Label("Setup", systemImage: "slider.horizontal.3")
                }
                .buttonStyle(DJSecondaryButtonStyle())
                .help("Open setup for \(result.software.displayName).")
                .accessibilityIdentifier("protectionSource.\(result.software.id).setup")
            }

            if let scanNow, hasReachableRecordingFolder {
                Button("Scan Now", action: scanNow)
                    .buttonStyle(DJGhostButtonStyle())
                    .accessibilityIdentifier("protectionSource.\(result.software.id).scanNow")
            }

            Button(action: chooseRecording) {
                Label(recordingFolders.isEmpty ? "Choose Folder" : "Manage", systemImage: "folder.badge.plus")
            }
            .buttonStyle(DJGhostButtonStyle())
            .help("Choose the recording folder for \(result.software.displayName).")
            .accessibilityIdentifier("protectionSource.\(result.software.id).recordingFolder")
        }
        .padding(12)
        .background(DJToken.card, in: RoundedRectangle(cornerRadius: DJToken.Radius.control))
        .overlay(
            RoundedRectangle(cornerRadius: DJToken.Radius.control)
                .stroke(DJToken.border, lineWidth: 1)
        )
    }

    private var sourceTone: StatusTone {
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

    private var hasReachableRecordingFolder: Bool {
        recordingFolders.contains { folder in
            var isDirectory: ObjCBool = false
            return FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDirectory) && isDirectory.boolValue
        }
    }
}

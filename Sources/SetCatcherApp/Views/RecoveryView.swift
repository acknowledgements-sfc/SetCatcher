import SwiftUI
import SetCatcherCore

/// Folder recovery flow (HANDOFF §4.8): problem → choosing → recovered | cleared.
struct RecoveryView: View {
    @EnvironmentObject private var model: AppModel
    let appID: String

    @State private var phase: Phase

    enum Phase {
        case problem
        case choosing
        case recovered(archived: Int)
        case cleared
    }

    init(appID: String, startingPhase: Phase = .problem) {
        self.appID = appID
        _phase = State(initialValue: startingPhase)
    }

    private var result: SoftwareProbeResult? {
        model.probeResults.first { $0.software.id == appID }
    }

    private var access: FolderAccess? {
        model.recordingsAccess(appID: appID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Folder Recovery")
                .font(.system(size: DJToken.TypeSize.title, weight: .semibold))
                .foregroundStyle(DJToken.foreground)

            switch phase {
            case .problem:
                problemPhase
            case .choosing:
                choosingPhase
            case .recovered(let archived):
                recoveredPhase(archived: archived)
            case .cleared:
                clearedPhase
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("recovery.root")
    }

    private var problemPhase: some View {
        Panel(title: "Problem", tone: .danger, padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                Text(result.map { "\($0.software.displayName) folder is unavailable" } ?? "Saved folder is unavailable")
                    .font(.system(size: DJToken.TypeSize.body, weight: .semibold))
                    .foregroundStyle(DJToken.foreground)

                Text("A saved folder is unavailable, so new sets are not being archived. Everything already in your archive is safe.")
                    .font(.system(size: DJToken.TypeSize.body))
                    .foregroundStyle(DJToken.mutedForeground)
                    .fixedSize(horizontal: false, vertical: true)

                if let access {
                    PathChip(path: access.url.path, tone: .danger)
                    Text("The drive may be unplugged.")
                        .font(.system(size: DJToken.TypeSize.secondary))
                        .foregroundStyle(DJToken.mutedForeground)
                }

                HStack(spacing: 8) {
                    Button("Choose a different folder") {
                        phase = .choosing
                    }
                    .buttonStyle(DJPrimaryButtonStyle())
                    .accessibilityIdentifier("recovery.chooseDifferent")

                    Button("Clear saved folder") {
                        model.clearFolder(appID: appID, kind: .recordings)
                        phase = .cleared
                    }
                    .buttonStyle(DJDangerButtonStyle())
                    .accessibilityIdentifier("recovery.clear")

                    Button("Back to Protection") {
                        model.selectedRoute = .protection
                    }
                    .buttonStyle(DJGhostButtonStyle())
                    .accessibilityIdentifier("recovery.back")
                }
            }
        }
    }

    private var choosingPhase: some View {
        Panel(title: "Choose Folder", padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Pick the recordings folder for \(result?.software.displayName ?? "this app").")
                    .font(.system(size: DJToken.TypeSize.body))
                    .foregroundStyle(DJToken.mutedForeground)

                if let access {
                    HStack {
                        PathChip(path: access.url.path, tone: .danger)
                        Badge(title: model.isFolderAccessReachable(access) ? "Mounted" : "Not mounted", tone: model.isFolderAccessReachable(access) ? .ok : .danger)
                    }
                }

                Button("Choose Folder…") {
                    model.chooseFolder(appID: appID, kind: .recordings)
                    if !model.isConfiguredRecordingsFolderUnreachable(appID: appID) {
                        model.scanNow()
                        let archived = model.scanResults(for: appID).reduce(0) { $0 + $1.archivedSessions.count }
                        phase = .recovered(archived: archived)
                    }
                }
                .buttonStyle(DJPrimaryButtonStyle())
                .accessibilityIdentifier("recovery.choose")

                Button("Back") {
                    phase = .problem
                }
                .buttonStyle(DJGhostButtonStyle())
            }
        }
    }

    private func recoveredPhase(archived: Int) -> some View {
        Panel(title: "Recovered", tone: .ok, padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Folder access restored.")
                    .font(.system(size: DJToken.TypeSize.body, weight: .semibold))
                Text(archived == 0
                     ? "Catch-up scan finished. No new recordings were waiting."
                     : "Catch-up scan archived \(archived) recording\(archived == 1 ? "" : "s").")
                    .font(.system(size: DJToken.TypeSize.body))
                    .foregroundStyle(DJToken.mutedForeground)

                Button("Back to Protection") {
                    model.selectedRoute = .protection
                }
                .buttonStyle(DJPrimaryButtonStyle())
                .accessibilityIdentifier("recovery.done")
            }
        }
    }

    private var clearedPhase: some View {
        Panel(title: "Folder Cleared", tone: .warn, padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                Text("The saved folder was unset. Source files were not deleted.")
                    .font(.system(size: DJToken.TypeSize.body))
                    .foregroundStyle(DJToken.mutedForeground)
                Text("Choose a recordings folder again when the drive is available.")
                    .font(.system(size: DJToken.TypeSize.secondary))
                    .foregroundStyle(DJToken.mutedForeground)

                Button("Open Setup") {
                    model.selectedRoute = .app(appID)
                }
                .buttonStyle(DJPrimaryButtonStyle())
                .accessibilityIdentifier("recovery.openSetup")
            }
        }
    }
}

#Preview("Recovery problem / light") {
    recoveryPreview(phase: .problem, scheme: .light)
}

#Preview("Recovery problem / dark") {
    recoveryPreview(phase: .problem, scheme: .dark)
}

#Preview("Recovery choosing / light") {
    recoveryPreview(phase: .choosing, scheme: .light)
}

#Preview("Recovery recovered / dark") {
    recoveryPreview(phase: .recovered(archived: 2), scheme: .dark, seedUnreachable: false)
}

#Preview("Recovery cleared / light") {
    recoveryPreview(phase: .cleared, scheme: .light, seedUnreachable: false)
}

@MainActor
private func recoveryPreview(
    phase: RecoveryView.Phase,
    scheme: ColorScheme,
    seedUnreachable: Bool = true
) -> some View {
    let model = AppModel()
    if seedUnreachable {
        model.previewApplyConfiguredRecordingsFolders(
            reachableAppIDs: [],
            unreachableAppIDs: ["serato"]
        )
    }
    return RecoveryView(appID: "serato", startingPhase: phase)
        .environmentObject(model)
        .padding()
        .frame(width: 560)
        .preferredColorScheme(scheme)
}

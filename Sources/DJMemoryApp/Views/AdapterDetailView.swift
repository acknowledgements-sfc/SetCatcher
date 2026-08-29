import SwiftUI
import DJMemoryCore

struct AdapterDetailView: View {
    @EnvironmentObject private var model: AppModel

    var selectedResult: SoftwareProbeResult? {
        if let appID = model.selectedAppID {
            return model.probeResults.first { $0.software.id == appID } ?? model.probeResults.first
        }
        return model.probeResults.first
    }

    var body: some View {
        if let result = selectedResult {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text(result.software.displayName)
                        .font(.system(size: DJToken.TypeSize.title, weight: .semibold))
                    SupportBadge(status: result.software.supportStatus)
                    Spacer()
                }

                if model.isConfiguredRecordingsFolderUnreachable(appID: result.software.id) {
                    Panel(title: "Folder Unavailable", tone: .danger, padding: 12) {
                        HStack {
                            Text("A saved folder is unavailable, so new sets are not being archived. Everything already in your archive is safe.")
                                .font(.system(size: DJToken.TypeSize.body))
                                .foregroundStyle(DJToken.mutedForeground)
                            Spacer()
                            Button("Start Recovery") {
                                model.selectedRoute = .recovery(result.software.id)
                            }
                            .buttonStyle(DJPrimaryButtonStyle())
                            .accessibilityIdentifier("setup.\(result.software.id).startRecovery")
                        }
                    }
                }

                FolderQuickActionsView(result: result)

                StatusGrid(
                    result: result,
                    setupState: model.setupState(for: result),
                    recordingFolders: model.configuredRecordingFolders(for: result.software.id),
                    historyFolders: model.historyFolders(for: result.software.id)
                )

                FolderSetupView(result: result)

                HStack(alignment: .top, spacing: 12) {
                    ScanResultsView(
                        results: model.scanResults(for: result.software.id),
                        appID: result.software.id,
                        onRecover: { appID in
                            model.selectedRoute = .recovery(appID)
                        }
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Panel(title: "Privacy", padding: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Audio files stay on this Mac", systemImage: "checkmark.circle.fill")
                            Label("Full tracklists are never uploaded by default", systemImage: "checkmark.circle.fill")
                            Label("Source recordings are copied, never moved", systemImage: "checkmark.circle.fill")
                        }
                        .font(.system(size: DJToken.TypeSize.secondary))
                        .foregroundStyle(DJToken.mutedForeground)
                    }
                    .frame(width: 280)
                }

                HistoryImportView(result: result)

                if result.software.id == "virtualdj" {
                    VirtualDJNetworkControlView()
                }

                if result.software.id == SupportedDJSoftware.pioneerHardwareAppID {
                    Panel(title: "Supported hardware", padding: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(SupportedHardware.all) { profile in
                                Text("\(profile.displayName) — \(profile.adapterListCaption)")
                                    .font(.system(size: DJToken.TypeSize.secondary))
                                    .foregroundStyle(DJToken.mutedForeground)
                            }
                        }
                    }
                }

                Panel(title: "Setup", padding: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(setupSteps(for: result).enumerated()), id: \.offset) { index, step in
                            Text("\(index + 1). \(step)")
                                .font(.system(size: DJToken.TypeSize.body))
                                .foregroundStyle(DJToken.foreground)
                        }

                        if result.software.supportStatus != .supported {
                            Text("\(result.software.supportStatus.displayName): \(result.software.notes)")
                                .font(.system(size: DJToken.TypeSize.secondary))
                                .foregroundStyle(DJToken.warn)
                                .padding(.top, 4)
                        }
                    }
                }
            }
        } else {
            EmptyStateView(
                title: "No DJ app selected",
                systemImage: "music.note.list",
                description: "Choose a DJ app in the sidebar to set up recording folders and check protection status.",
                primaryTitle: "Open Protection",
                primaryAction: {
                    model.selectedRoute = .protection
                },
                secondaryTitle: "Browse first app",
                secondaryAction: {
                    if let first = model.probeResults.first {
                        model.selectedRoute = .app(first.software.id)
                    }
                }
            )
            .accessibilityIdentifier("adapter.empty")
        }
    }

    private func setupSteps(for result: SoftwareProbeResult) -> [String] {
        switch result.software.id {
        case "serato":
            return [
                "Grant access to ~/Music/_Serato_ when prompted.",
                "SetCatcher watches the Recording folder.",
                "History Export files will be used for tracklists."
            ]
        case "rekordbox":
            return [
                "Choose the folder where rekordbox saves recordings.",
                "Import rekordbox XML or history exports when available.",
                "SetCatcher preserves completed recordings in ~/Music/DJMemory."
            ]
        case "traktor":
            return [
                "SetCatcher checks ~/Music/Traktor/Recordings when it exists.",
                "Versioned Traktor History folders are detected under Native Instruments.",
                "Import Traktor .nml history playlists for tracklists."
            ]
        case "virtualdj":
            return [
                "SetCatcher checks ~/Documents/VirtualDJ when it exists.",
                "History imports support VirtualDJ text, M3U, XML, and .vdjfolder files.",
                "Use Network Control commands below to probe deeper local endpoints."
            ]
        case "pioneer-hardware":
            return [
                "Laptop + XDJ-XZ over USB: grant the Serato or rekordbox recordings folder, then leave Input Capture armed on the XZ. Forgetting Record still produces an archive.",
                "Overlapping folder and input recordings are one set. The DJ-software file is primary; Input Capture is the hardware backup. Sources are never moved, renamed, or deleted.",
                "Insert the USB stick used for MASTER REC (XDJ-RX2/RX3/XZ/AZ) only when the Mac is out of the audio path.",
                "Choose the stick or its PIONEERREC folder as the recordings folder. This path stays Manual Setup until the drive is granted and mounted.",
                "SetCatcher copies stable RECxxx.WAV files into your archive and leaves the stick unchanged.",
                "MASTER REC files have no clock — archive time uses the file modification date.",
                "CDJs need the Mac in the USB audio path, a DJM Capture path, or a PIONEERREC folder. A mixer that never reaches the Mac is Manual Setup."
            ]
        case "djmemory-capture":
            return [
                "Open Capture in the sidebar.",
                "App audio (default): pick a running DJ app, Arm, and grant Screen & System Audio Recording. Recording starts when audio is detected; idle silence saves and re-arms.",
                "Input device: on a Pioneer USB rig, Both (default) auto-selects the device and records when audio is detected so forgetting Record still produces an archive.",
                "Folder Protection still copies files the DJ app writes. Source files are never moved."
            ]
        default:
            return [
                "SetCatcher checks documented djay recording folders when they exist.",
                "Choose your djay recordings folder manually if the default folder is not found.",
                "History and session metadata support still needs verification."
            ]
        }
    }
}

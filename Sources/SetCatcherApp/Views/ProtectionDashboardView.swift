import SwiftUI
import SetCatcherCore

struct ProtectionDashboardView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            headline

            HStack(spacing: 12) {
                MetricTile(
                    label: "Protected Sources",
                    value: "\(model.protectedAdapterCount)",
                    tone: model.protectedAdapterCount > 0 ? .ok : .neutral
                )
                MetricTile(
                    label: "Archived Sets",
                    value: "\(model.librarySummaries.count)"
                )
                MetricTile(
                    label: "Imported Histories",
                    value: "\(model.allImportedTracklists.count)"
                )
            }

            if !model.hasAnyRecordingsFolderAccess {
                EmptyStateView(
                    title: "Choose a recording folder",
                    systemImage: "folder.badge.plus",
                    description: "Pick a DJ app below, then set the folder where it saves recordings.",
                    primaryTitle: "Choose Folder",
                    primaryAction: {
                        if let first = model.probeResults.first {
                            model.selectedRoute = .app(first.software.id)
                            model.chooseFolder(appID: first.software.id, kind: .recordings)
                        }
                    },
                    secondaryTitle: "Browse DJ apps",
                    secondaryAction: {
                        if let first = model.probeResults.first {
                            model.selectedRoute = .app(first.software.id)
                        }
                    }
                )
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Sources")
                    .microLabelStyle()

                ForEach(model.probeResults, id: \.software.id) { result in
                    ProtectionSourceRow(
                        result: result,
                        state: model.setupState(for: result),
                        recordingFolders: model.configuredRecordingFolders(for: result.software.id),
                        historyFolders: model.historyFolders(for: result.software.id),
                        chooseRecording: {
                            model.selectedRoute = .app(result.software.id)
                            model.chooseFolder(appID: result.software.id, kind: .recordings)
                        },
                        openSetup: {
                            model.selectedRoute = .app(result.software.id)
                        },
                        fixFolder: {
                            model.selectedRoute = .recovery(result.software.id)
                        },
                        scanNow: {
                            model.scanNow()
                        }
                    )
                }
            }

            Text("Audio files and full tracklists stay on this Mac. Nothing is uploaded.")
                .font(.system(size: DJToken.TypeSize.secondary))
                .foregroundStyle(DJToken.mutedForeground)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("protection.root")
    }

    private var headline: some View {
        let state = model.protectionState
        return HStack(alignment: .top, spacing: 14) {
            Image(systemName: headlineSymbol(state))
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(headlineTone(state).color)
                .frame(width: 40, height: 40)
                .background(
                    headlineTone(state).color.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: DJToken.Radius.control)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DJToken.Radius.control)
                        .stroke(headlineTone(state).color.opacity(0.35), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(state.headline)
                        .font(.system(size: DJToken.TypeSize.title, weight: .semibold))
                        .foregroundStyle(DJToken.foreground)
                    StatusDot(tone: headlineTone(state), pulse: state == .scanning)
                }

                Text(state.explanation)
                    .font(.system(size: DJToken.TypeSize.body))
                    .foregroundStyle(DJToken.mutedForeground)
                    .fixedSize(horizontal: false, vertical: true)

                if state == .attentionNeeded {
                    HStack(spacing: 8) {
                        ForEach(unreachableApps, id: \.id) { app in
                            Button("Fix \(app.displayName)") {
                                model.selectedRoute = .recovery(app.id)
                            }
                            .buttonStyle(DJPrimaryButtonStyle())
                            .accessibilityIdentifier("protection.fix.\(app.id)")
                        }
                    }
                    .padding(.top, 2)
                }

                if state == .needsSetup {
                    Button("Choose Folder") {
                        if let first = model.probeResults.first {
                            model.selectedRoute = .app(first.software.id)
                            model.chooseFolder(appID: first.software.id, kind: .recordings)
                        }
                    }
                    .buttonStyle(DJPrimaryButtonStyle())
                    .accessibilityIdentifier("protection.chooseFolder")
                }

                if state == .scanning || state == .protected {
                    Button {
                        model.scanNow()
                    } label: {
                        Label(model.isScanning ? "Scanning" : "Rescan Last 24 Hours", systemImage: "waveform.badge.magnifyingglass")
                    }
                    .buttonStyle(DJSecondaryButtonStyle())
                    .disabled(model.isScanning)
                    .accessibilityIdentifier("protection.scanNow")
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var unreachableApps: [DJSoftware] {
        let ids = Set(model.unreachableRecordingAccesses().map(\.appID))
        return model.probeResults
            .map(\.software)
            .filter { ids.contains($0.id) }
    }

    private func headlineSymbol(_ state: ProtectionState) -> String {
        switch state {
        case .protected:
            return "checkmark.shield.fill"
        case .needsSetup:
            return "folder.badge.plus"
        case .scanning:
            return "waveform.badge.magnifyingglass"
        case .attentionNeeded:
            return "exclamationmark.triangle.fill"
        }
    }

    private func headlineTone(_ state: ProtectionState) -> StatusTone {
        switch state {
        case .protected:
            return .ok
        case .needsSetup:
            return .warn
        case .scanning:
            return .info
        case .attentionNeeded:
            return .danger
        }
    }
}

#Preview("Protection · Needs Setup / light") {
    ProtectionDashboardView()
        .environmentObject(AppModel())
        .padding()
        .frame(width: 900, height: 640)
        .preferredColorScheme(.light)
}

#Preview("Protection · Needs Setup / dark") {
    ProtectionDashboardView()
        .environmentObject(AppModel())
        .padding()
        .frame(width: 900, height: 640)
        .preferredColorScheme(.dark)
}

#Preview("Protection · Protected / light") {
    protectionPreview(reachable: ["serato", "rekordbox"], scheme: .light)
}

#Preview("Protection · Scanning / dark") {
    protectionPreview(reachable: ["serato"], scanning: true, scheme: .dark)
}

#Preview("Protection · Attention Needed / light") {
    protectionPreview(unreachable: ["serato"], scheme: .light)
}

#Preview("Protection · empty no sources / dark") {
    ProtectionDashboardView()
        .environmentObject(AppModel())
        .padding()
        .frame(width: 900, height: 640)
        .preferredColorScheme(.dark)
}

@MainActor
private func protectionPreview(
    reachable: [String] = [],
    unreachable: [String] = [],
    scanning: Bool = false,
    scheme: ColorScheme
) -> some View {
    let model = AppModel()
    model.previewApplyConfiguredRecordingsFolders(
        reachableAppIDs: reachable,
        unreachableAppIDs: unreachable
    )
    if scanning {
        model.previewSetScanning(true)
    }
    return ProtectionDashboardView()
        .environmentObject(model)
        .padding()
        .frame(width: 900, height: 640)
        .preferredColorScheme(scheme)
}

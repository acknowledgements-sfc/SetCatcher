import SwiftUI
import DJMemoryCore

struct SidebarView: View {
    @EnvironmentObject private var model: AppModel
    @State private var isAddAppPresented = false
    var initiallyPresentAddApp: Bool = false

    private var libraryCount: Int {
        model.librarySummaries.count + model.allImportedTracklists.count
    }

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $model.selectedRoute) {
                Section("SetCatcher") {
                    Label("Home", systemImage: "house")
                        .tag(Route.home)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Home")
                        .accessibilityIdentifier("sidebar.home")
                    Label("Protection", systemImage: model.protectionSymbolName)
                        .tag(Route.protection)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Protection")
                        .accessibilityIdentifier("sidebar.protection")
                    Label("Capture", systemImage: "mic.fill")
                        .tag(Route.capture)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Capture")
                        .accessibilityIdentifier("sidebar.capture")
                    libraryRow
                        .tag(Route.library)
                        .accessibilityIdentifier("sidebar.library")
                    Label("Activity", systemImage: "clock.arrow.circlepath")
                        .tag(Route.activity)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Activity")
                        .accessibilityIdentifier("sidebar.activity")
                }

                Section {
                    if model.configuredProbeResults.isEmpty {
                        Text("No DJ apps set up yet. Use + to add one.")
                            .font(.system(size: DJToken.TypeSize.micro))
                            .foregroundStyle(DJToken.mutedForeground)
                            .fixedSize(horizontal: false, vertical: true)
                            .listRowSeparator(.hidden)
                    } else {
                        ForEach(model.configuredProbeResults, id: \.software.id) { result in
                            configuredAppRow(result)
                                .tag(Route.app(result.software.id))
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel(sidebarAppAccessibilityLabel(result))
                                .accessibilityIdentifier("sidebar.app.\(result.software.id)")
                        }
                    }
                } header: {
                    djAppsHeader
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            statusStrip
                .padding(.horizontal, 8)
                .padding(.bottom, 6)

            List(selection: $model.selectedRoute) {
                Label("Settings", systemImage: "gearshape")
                    .tag(Route.settings)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Settings")
                    .accessibilityIdentifier("sidebar.settings")
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .frame(height: 44)
        }
        .background(.ultraThinMaterial)
        .navigationTitle("SetCatcher")
        .onAppear {
            if initiallyPresentAddApp {
                isAddAppPresented = true
            }
        }
    }

    private var libraryRow: some View {
        HStack(spacing: 8) {
            Label("Library", systemImage: "music.note.list")
            Spacer(minLength: 0)
            Text("\(libraryCount)")
                .font(.system(size: DJToken.TypeSize.micro, weight: .semibold).monospacedDigit())
                .foregroundStyle(
                    model.selectedRoute == .library ? DJToken.foreground : DJToken.mutedForeground
                )
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(
                    model.selectedRoute == .library ? DJToken.secondary.opacity(0.8) : DJToken.secondary,
                    in: RoundedRectangle(cornerRadius: DJToken.Radius.badge)
                )
                .accessibilityIdentifier("sidebar.library.count")
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Library")
        .accessibilityValue("\(libraryCount)")
    }

    private var djAppsHeader: some View {
        HStack(spacing: 4) {
            Text("DJ Apps")
            Spacer(minLength: 0)
            Button {
                isAddAppPresented.toggle()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .foregroundStyle(isAddAppPresented ? DJToken.foreground : DJToken.mutedForeground)
            .background(
                isAddAppPresented ? DJToken.secondary : Color.clear,
                in: RoundedRectangle(cornerRadius: DJToken.Radius.badge)
            )
            .help("Add a DJ app")
            .accessibilityLabel("Add a DJ app")
            .accessibilityIdentifier("sidebar.addApp")
            .popover(isPresented: $isAddAppPresented, arrowEdge: .bottom) {
                AddAppPickerView(
                    options: model.unconfiguredProbeResults,
                    onPick: { appID in
                        model.selectedRoute = .app(appID)
                        isAddAppPresented = false
                    }
                )
                .frame(width: 280)
            }
        }
    }

    private var statusStrip: some View {
        let state = model.protectionState
        let tone = HomeFormatting.protectionTone(state)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "shield")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DJToken.mutedForeground)
                Text("Status")
                    .microLabelStyle()
            }
            HStack(spacing: 6) {
                StatusDot(tone: tone, pulse: state == .scanning)
                Text(state.headline)
                    .font(.system(size: DJToken.TypeSize.body, weight: .semibold))
                    .foregroundStyle(DJToken.foreground)
            }
            Text(statusDetail)
                .font(.system(size: DJToken.TypeSize.micro))
                .foregroundStyle(DJToken.mutedForeground)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DJToken.card, in: RoundedRectangle(cornerRadius: DJToken.Radius.control))
        .overlay(
            RoundedRectangle(cornerRadius: DJToken.Radius.control)
                .stroke(DJToken.border, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Status")
        .accessibilityValue("\(state.headline). \(statusDetail)")
        .accessibilityIdentifier("sidebar.statusStrip")
    }

    private var statusDetail: String {
        switch model.protectionState {
        case .scanning:
            return "Checking watched folders…"
        case .attentionNeeded:
            return "A saved folder is unavailable."
        case .needsSetup:
            let needs = model.probeResults.filter { !model.hasConfiguredRecordingsFolder(appID: $0.software.id) }.count
            return "\(needs) app\(needs == 1 ? "" : "s") still need a folder."
        case .protected:
            return "All sources watched. Nothing to do."
        }
    }

    @ViewBuilder
    private func configuredAppRow(_ result: SoftwareProbeResult) -> some View {
        let unreachable = model.isConfiguredRecordingsFolderUnreachable(appID: result.software.id)
        let tone: StatusTone = {
            if unreachable {
                return .danger
            }
            if model.isScanning {
                return .info
            }
            return .ok
        }()

        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: DJToken.Radius.swatch)
                .fill(DJToken.accent(forAppID: result.software.id))
                .frame(width: 3, height: 14)

            Text(result.software.displayName)
                .font(.system(size: DJToken.TypeSize.body, weight: .medium))
                .lineLimit(1)

            Spacer(minLength: 0)

            StatusDot(tone: tone, pulse: model.isScanning && !unreachable)
        }
    }

    private func sidebarAppAccessibilityLabel(_ result: SoftwareProbeResult) -> String {
        let name = result.software.displayName
        if model.isConfiguredRecordingsFolderUnreachable(appID: result.software.id) {
            return "\(name), folder unavailable"
        }
        if model.isScanning {
            return "\(name), scanning"
        }
        return name
    }
}

// MARK: - Previews (§4.10 sidebar sources matrix)

#Preview("Sidebar sources — none configured / light") {
    sidebarPreview(configured: [], unreachable: [])
        .preferredColorScheme(.light)
}

#Preview("Sidebar sources — none configured / dark") {
    sidebarPreview(configured: [], unreachable: [])
        .preferredColorScheme(.dark)
}

#Preview("Sidebar sources — some configured / light") {
    sidebarPreview(configured: ["serato", "rekordbox"], unreachable: [])
        .preferredColorScheme(.light)
}

#Preview("Sidebar sources — some configured / dark") {
    sidebarPreview(configured: ["serato", "rekordbox"], unreachable: [])
        .preferredColorScheme(.dark)
}

#Preview("Sidebar sources — one unreachable / light") {
    sidebarPreview(configured: ["serato"], unreachable: ["traktor"])
        .preferredColorScheme(.light)
}

#Preview("Sidebar sources — one unreachable / dark") {
    sidebarPreview(configured: ["serato"], unreachable: ["traktor"])
        .preferredColorScheme(.dark)
}

@MainActor
private func sidebarPreview(configured: [String], unreachable: [String]) -> some View {
    let model = AppModel()
    model.previewApplyConfiguredRecordingsFolders(
        reachableAppIDs: configured,
        unreachableAppIDs: unreachable
    )

    return NavigationSplitView {
        SidebarView()
            .environmentObject(model)
    } detail: {
        Text("Detail")
            .foregroundStyle(DJToken.mutedForeground)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DJToken.content)
    }
    .frame(width: 720, height: 480)
}

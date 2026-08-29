import SwiftUI
import DJMemoryCore

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    let isAccountAuthEnabled: Bool

    private let intervalOptions = [30, 60, 120, 300]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Settings")
                .font(.system(size: DJToken.TypeSize.title, weight: .semibold))
                .foregroundStyle(DJToken.foreground)

            scanningPanel
            capturePanel
            SettingsProfilePanel()
            archivePanel
            cloudSyncPanel
            currentStatePanel
            SettingsAccountPanel(isAccountAuthEnabled: isAccountAuthEnabled)
        }
    }

    private var capturePanel: some View {
        Panel(title: "Capture", padding: 14) {
            VStack(alignment: .leading, spacing: 14) {
                settingsToggle(
                    title: "Auto-arm when a DJ app is running",
                    explanation: "When on, App audio Capture arms itself for shareable DJ apps. Turning this off does not stop a session that is already watching. Disarm still suppresses re-arm until you Arm again or change mode.",
                    isOn: Binding(
                        get: { model.settings.autoArmOnDJAppFound },
                        set: { model.updateAutoArmOnDJAppFound(enabled: $0) }
                    ),
                    id: "settings.autoArmOnDJAppFound"
                )
                VStack(alignment: .leading, spacing: 6) {
                    Text("Pioneer rig safety nets")
                        .font(.system(size: DJToken.TypeSize.body, weight: .medium))
                    Picker("Pioneer rig safety nets", selection: Binding(
                        get: { model.settings.dualRoutePosture },
                        set: { model.updateDualRoutePosture($0) }
                    )) {
                        ForEach(DualRoutePosture.allCases, id: \.self) { posture in
                            Text(posture.displayName).tag(posture)
                        }
                    }
                    .accessibilityLabel("Pioneer rig safety nets")
                    .accessibilityIdentifier("settings.dualRoutePosture")
                    Text(model.settings.dualRoutePosture.explanation)
                        .font(.system(size: DJToken.TypeSize.secondary))
                        .foregroundStyle(DJToken.mutedForeground)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("Capture writes 16-bit / 48 kHz stereo WAV. Audio stays on this Mac.")
                    .font(.system(size: DJToken.TypeSize.secondary))
                    .foregroundStyle(DJToken.mutedForeground)
            }
        }
    }

    private var cloudSyncPanel: some View {
        Panel(title: "Cloud Sync (opt-in)", padding: 14) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Off by default. Local protection never depends on an account. Audio and full tracklists are never uploaded automatically.")
                    .font(.system(size: DJToken.TypeSize.secondary))
                    .foregroundStyle(DJToken.mutedForeground)
                settingsToggle(
                    title: "Enable cloud sync",
                    explanation: "Allows metadata sync when a backend account is connected. Does not upload audio by itself.",
                    isOn: Binding(get: { model.settings.cloudSyncEnabled }, set: { model.setCloudSyncEnabled($0) }),
                    id: "settings.cloudSync"
                )
                settingsToggle(
                    title: "Opt in to archive backup",
                    explanation: "Explicit backup of archived recordings. Requires cloud sync. Never silent.",
                    isOn: Binding(get: { model.settings.cloudArchiveBackupEnabled }, set: { model.setCloudArchiveBackupEnabled($0) }),
                    id: "settings.cloudArchiveBackup"
                )
                .disabled(!model.settings.cloudSyncEnabled)
            }
        }
    }

private var scanningPanel: some View {
        Panel(title: "Scanning", padding: 14) {
            VStack(alignment: .leading, spacing: 14) {
                settingsToggle(
                    title: "Automatic scanning",
                    explanation: "When on, DJMemory scans configured recording folders while the app is open.",
                    isOn: Binding(
                        get: { model.settings.automaticScanningEnabled },
                        set: { model.updateAutomaticScanning(enabled: $0) }
                    ),
                    id: "settings.automaticScanning"
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Scan interval")
                        .font(.system(size: DJToken.TypeSize.body, weight: .medium))
                    Text(intervalExplanation)
                        .font(.system(size: DJToken.TypeSize.secondary))
                        .foregroundStyle(DJToken.mutedForeground)
                    Picker(
                        "Scan interval",
                        selection: Binding(
                            get: { model.settings.scanIntervalSeconds },
                            set: { model.updateScanInterval(seconds: $0) }
                        )
                    ) {
                        ForEach(intervalOptions, id: \.self) { seconds in
                            Text(intervalLabel(seconds)).tag(seconds)
                        }
                    }
                    .disabled(!model.settings.automaticScanningEnabled)
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Scan interval")
                    .accessibilityIdentifier("settings.scanInterval")
                }

                settingsToggle(
                    title: "Verify each copy",
                    explanation: "After archiving, confirm the protected copy matches the source file size.",
                    isOn: Binding(
                        get: { model.settings.verifyCopies },
                        set: { model.updateVerifyCopies(enabled: $0) }
                    ),
                    id: "settings.verifyCopies"
                )

                settingsToggle(
                    title: "Notify after archiving",
                    explanation: "Show a local notification when a recording is safely copied.",
                    isOn: Binding(
                        get: { model.settings.notifyAfterArchiving },
                        set: { model.updateNotifyAfterArchiving(enabled: $0) }
                    ),
                    id: "settings.notifyAfterArchiving"
                )

                settingsToggle(
                    title: "Launch at login",
                    explanation: model.launchAtLoginNeedsApproval
                        ? "macOS still needs approval in System Settings → Login Items before DJMemory can open at sign-in."
                        : "Open DJMemory when you sign in to this Mac.",
                    isOn: Binding(
                        get: { model.settings.launchAtLogin },
                        set: { model.updateLaunchAtLogin(enabled: $0) }
                    ),
                    id: "settings.launchAtLogin"
                )

                if model.launchAtLoginNeedsApproval {
                    Button("Open Login Items…") {
                        model.openLoginItemsSettings()
                    }
                    .buttonStyle(DJSecondaryButtonStyle())
                    .accessibilityIdentifier("settings.launchAtLogin.openLoginItems")
                }

                settingsToggle(
                    title: "Open in menu bar only",
                    explanation: "Skip opening the main window at launch. DJMemory stays in the menu bar; open the window any time from there.",
                    isOn: Binding(
                        get: { model.settings.menuBarOnly },
                        set: { model.updateMenuBarOnly(enabled: $0) }
                    ),
                    id: "settings.menuBarOnly"
                )

                settingsToggle(
                    title: "Show folder scan details in menu bar",
                    explanation: "Adds Protected / Last scan / Next scan to the menu bar dropdown. Off by default to keep the quick look focused on capture.",
                    isOn: Binding(
                        get: { model.settings.showFolderScanDetailsInMenuBar },
                        set: { model.updateShowFolderScanDetailsInMenuBar(enabled: $0) }
                    ),
                    id: "settings.showFolderScanDetailsInMenuBar"
                )
            }
        }
    }

    private var archivePanel: some View {
        Panel(title: "Archive", padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    PathChip(path: model.archiveRoot.path)
                    Button("Change") { model.chooseArchiveFolder() }
                        .buttonStyle(DJSecondaryButtonStyle())
                        .accessibilityIdentifier("settings.archive.choose")
                    Button("Open") { model.openArchiveFolder() }
                        .buttonStyle(DJGhostButtonStyle())
                        .accessibilityIdentifier("settings.archive.open")
                    Button("Reset") { model.resetArchiveFolder() }
                        .buttonStyle(DJGhostButtonStyle())
                        .disabled(model.settings.archiveRootPath == nil)
                        .accessibilityIdentifier("settings.archive.reset")
                }

                TextField(
                    "Archive naming template",
                    text: Binding(
                        get: { model.settings.archiveNamingTemplate },
                        set: { model.updateArchiveNamingTemplate($0) }
                    )
                )
                .textFieldStyle(.roundedBorder)
                .help("Available tokens: {date}, {time}, {app}, {source}.")
                .accessibilityLabel("Archive naming template")
                .accessibilityIdentifier("settings.archiveNamingTemplate")

                KeyValueRow(key: "Example", value: exampleArchiveName(), mono: true, showsDivider: false)

                Text("Source recordings stay where they are. DJMemory writes protected copies and metadata sidecars here.")
                    .font(.system(size: DJToken.TypeSize.secondary))
                    .foregroundStyle(DJToken.mutedForeground)
            }
        }
    }

    private var currentStatePanel: some View {
        Panel(title: "Current State", padding: 0) {
            KeyValueRow(key: "Archive folder", value: model.archiveRoot.path, mono: true)
            KeyValueRow(key: "Protected sources", value: "\(model.protectedAdapterCount)")
            KeyValueRow(key: "Archived sets", value: "\(model.librarySummaries.count)")
            KeyValueRow(key: "Imported tracklists", value: "\(model.allImportedTracklists.count)")
            KeyValueRow(key: "Archive size on disk", value: ByteCountFormatter.string(fromByteCount: archiveSize, countStyle: .file))
            KeyValueRow(key: "Version", value: appVersion, showsDivider: false)
        }
    }

    private func settingsToggle(title: String, explanation: String, isOn: Binding<Bool>, id: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Toggle(title, isOn: isOn)
                .accessibilityIdentifier(id)
            Text(explanation)
                .font(.system(size: DJToken.TypeSize.secondary))
                .foregroundStyle(DJToken.mutedForeground)
        }
    }

    private var intervalExplanation: String {
        switch model.settings.scanIntervalSeconds {
        case 30: return "Check watched folders every 30 seconds while the app is open."
        case 60: return "Check watched folders once a minute while the app is open."
        case 120: return "Check watched folders every 2 minutes while the app is open."
        case 300: return "Check watched folders every 5 minutes while the app is open."
        default: return "How often DJMemory checks configured recording folders while automatic scanning is on."
        }
    }

    private var archiveSize: Int64 {
        model.sessions.reduce(0) { $0 + $1.fileSize }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }

    private func intervalLabel(_ seconds: Int) -> String {
        seconds < 60 ? "\(seconds)s" : "\(seconds / 60)m"
    }

    private func exampleArchiveName() -> String {
        let template = model.settings.archiveNamingTemplate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? AppSettings.defaultArchiveNamingTemplate
            : model.settings.archiveNamingTemplate
        return template
            .replacingOccurrences(of: "{date}", with: "2026-08-06")
            .replacingOccurrences(of: "{time}", with: "2230")
            .replacingOccurrences(of: "{app}", with: "Serato DJ Pro")
            .replacingOccurrences(of: "{source}", with: "Club Recording")
            + ".wav"
    }
}

#Preview("Settings empty / light") {
    ScrollView {
        SettingsView(isAccountAuthEnabled: false)
            .padding()
    }
    .environmentObject(AppModel())
    .frame(width: 640, height: 720)
    .preferredColorScheme(.light)
}

#Preview("Settings empty / dark") {
    ScrollView {
        SettingsView(isAccountAuthEnabled: false)
            .padding()
    }
    .environmentObject(AppModel())
    .frame(width: 640, height: 720)
    .preferredColorScheme(.dark)
}

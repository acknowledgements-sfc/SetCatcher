import SwiftUI
import SetCatcherCore

/// First-run onboarding: six-step setup with a compact step rail (HANDOFF §4.7).
/// Analog Mixer is a first-class branch so vinyl-only DJs are not stalled behind a DJ-app folder.
struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel
    @State private var step: Step
    @State private var analogSelected = false
    @State private var analogPath: OnboardingAnalogPath?

    enum Step: Int, CaseIterable {
        case welcome
        case djApps
        case folderAccess
        case archive
        case history
        case ready

        var title: String {
            switch self {
            case .welcome: return "Welcome"
            case .djApps: return "DJ Apps"
            case .folderAccess: return "Folder Access"
            case .archive: return "Archive"
            case .history: return "History"
            case .ready: return "Ready"
            }
        }
    }

    init(startingStep: Step = .welcome) {
        _step = State(initialValue: startingStep)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            topBar

            VStack(alignment: .leading, spacing: 8) {
                Text(step.title.uppercased())
                    .microLabelStyle()
                Text(copy.headline)
                    .font(.system(size: DJToken.TypeSize.title, weight: .semibold))
                    .foregroundStyle(DJToken.foreground)
                if let accent = copy.accent {
                    Text(accent)
                        .font(.system(size: DJToken.TypeSize.title, weight: .semibold))
                        .foregroundStyle(DJToken.primary)
                }
                Text(copy.subline)
                    .font(.system(size: DJToken.TypeSize.body))
                    .foregroundStyle(DJToken.mutedForeground)
                    .fixedSize(horizontal: false, vertical: true)
            }

            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            footer
        }
        .padding(32)
        .frame(width: 720, height: 560)
        .background(DJToken.background)
    }

    private var topBar: some View {
        OnboardingTopBar(
            stepTitles: Step.allCases.map(\.title),
            currentIndex: step.rawValue
        )
    }

    private var copy: (headline: String, accent: String?, subline: String) {
        switch step {
        case .welcome:
            return ("Every set you play,", "remembered.",
                    "Choose the folders your DJ apps already record into — or set up Analog Mixer for vinyl. SetCatcher copies completed recordings and never touches the originals.")
        case .djApps:
            if analogSelected {
                return ("Analog Mixer is", "Manual Setup.",
                        "There is no DJ app folder to watch. You will pin a rec-out once, or grant a dump folder after the gig.")
            }
            if installedCount == 0 {
                return ("No DJ apps", "installed.",
                        "Choose Analog Mixer for vinyl. Supported apps: \(supportedDJAppNamesList).")
            }
            return ("We found your", "DJ apps.",
                    "SetCatcher watches the folders these already record into. Nothing is installed, nothing is changed. Vinyl-only? Choose Analog Mixer.")
        case .folderAccess:
            if analogSelected {
                switch analogPath {
                case .booth:
                    return ("Pin the mixer", "rec-out.",
                            "Once: connect REC OUT or SESSION OUT to this Mac, then Choose rec-out. After that, recording starts when audio is detected.")
                case .dump:
                    return ("Grant the dump", "folder.",
                            "The Mac is out of the mix. After the set, grant the folder on your recorder or USB stick.")
                case nil:
                    return ("Booth or dump?", "Pick one.",
                            "Booth keeps the Mac in the loop. Dump is for handheld / stick recordings after the gig.")
                }
            }
            return ("Grant one folder, and the set", "starts to take shape.",
                    "\(grantedFolderCount) granted so far — pick another, or move on. Nothing leaves this Mac.")
        case .archive:
            return ("Protected copies land", "here.",
                    "Source recordings stay where they are. SetCatcher writes protected copies to your archive.")
        case .history:
            if analogSelected {
                return ("Track history is", "import-only.",
                        "Vinyl-only sets have no DJ-app export. Skipping this step is expected and safe.")
            }
            return ("Track history is", "optional.",
                    "Import set histories later from each app’s setup screen. Skipping this step is safe.")
        case .ready:
            if analogSelected, model.hasPinnedAnalogRecOut {
                let name = model.pinnedAnalogInputDevice?.name ?? "rec-out"
                return ("You’re", "ready.",
                        AnalogMixerPolicy.listeningSummary(deviceName: name) + " Choose how SetCatcher appears before you finish.")
            }
            if analogSelected, model.hasConfiguredRecordingsFolder(appID: SupportedDJSoftware.analogMixerAppID) {
                return ("You’re", "ready.",
                        "Watching the dump folder. SetCatcher copies stable files and leaves the originals unchanged. Choose how SetCatcher appears before you finish.")
            }
            return ("You’re", "ready.",
                    "Choose how SetCatcher appears, then finish. It will watch granted folders and copy completed recordings into your archive.")
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch step {
        case .djApps:
            softwareList(folderMode: false)

        case .folderAccess where analogSelected:
            OnboardingAnalogSetupView(analogPath: $analogPath)

        case .archive:
            VStack(alignment: .leading, spacing: 10) {
                PathChip(path: model.archiveRoot.path)
                Button("Change Archive Folder") { model.chooseArchiveFolder() }
                    .buttonStyle(DJHollowButtonStyle())
                    .accessibilityIdentifier("onboarding.reviewArchive")
            }
        case .ready:
            VStack(alignment: .leading, spacing: 14) {
                MetricTile(
                    label: "Protected sources",
                    value: "\(model.protectedAdapterCount)",
                    tone: model.protectedAdapterCount > 0 ? .ok : .warn
                )
                AppPresentationModePicker(
                    selection: Binding(
                        get: { model.settings.appPresentationMode },
                        set: { model.updateAppPresentationMode($0) }
                    ),
                    accessibilityPrefix: "onboarding"
                )
            }
        case .folderAccess:
            VStack(alignment: .leading, spacing: 10) {
                if installedCount == 0 {
                    Text("Install a DJ app, choose Analog Mixer, or use the list below to choose folders manually.")
                        .font(.system(size: DJToken.TypeSize.secondary))
                        .foregroundStyle(DJToken.warn)
                }
                softwareList(folderMode: true)
            }
        default:
            EmptyView()
        }
    }

    private func softwareList(folderMode: Bool) -> some View {
        OnboardingDJAppsList(
            results: model.onboardingDJSoftwareResults,
            analogSelected: analogSelected,
            folderMode: folderMode,
            isGranted: { model.hasConfiguredRecordingsFolder(appID: $0) },
            onSelectAnalog: {
                analogSelected = true
            },
            onSelectSoftware: {
                analogSelected = false
                analogPath = nil
            },
            onChooseFolder: { result, installation in
                analogSelected = false
                analogPath = nil
                let preferred = installation?.bestPath(ofKind: .recordings)?.url
                    ?? result.familyDiscoveredPaths.first(where: { $0.kind == .recordings })?.url
                model.chooseFolder(
                    appID: result.software.id,
                    kind: .recordings,
                    preferredDirectory: preferred
                )
            }
        )
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if step != .welcome {
                Button("Back") {
                    if let previous = Step(rawValue: step.rawValue - 1) { step = previous }
                }
                .buttonStyle(DJGhostButtonStyle())
                .accessibilityIdentifier("onboarding.back")
            }

            Button("Skip setup") { model.completeOnboarding() }
                .buttonStyle(DJGhostButtonStyle())
                .accessibilityIdentifier("onboarding.skip")

            Spacer()

            Button { advance() } label: {
                Text(step == .ready ? "Finish" : "Continue")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DJToken.foreground)
                    .padding(.horizontal, 22)
                    .frame(minHeight: 40)
                    .background(
                        DJToken.primary.opacity(canContinue ? 1 : 0.4),
                        in: RoundedRectangle(cornerRadius: DJToken.Radius.maximum)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canContinue)
            .keyboardShortcut(.defaultAction)
            .accessibilityIdentifier(step == .ready ? "onboarding.startSetup" : "onboarding.continue")
        }
    }

    private var supportedDJAppNamesList: String {
        SupportedDJSoftware.all
            .filter { $0.supportStatus == .supported }
            .map(\.displayName)
            .joined(separator: ", ")
    }

    private var installedCount: Int { model.installedOrRunningProbeCount }
    private var grantedFolderCount: Int { model.configuredRecordingsCount }

    private var analogConfigured: Bool {
        model.hasConfiguredRecordingsFolder(appID: SupportedDJSoftware.analogMixerAppID)
    }

    private var canContinue: Bool {
        switch step {
        case .djApps:
            return analogSelected || installedCount >= 1
        case .folderAccess:
            if analogSelected {
                return analogConfigured
            }
            return grantedFolderCount >= 1
        default:
            return true
        }
    }

    private func advance() {
        if step == .ready {
            if analogSelected {
                model.completeOnboarding(destinationAppID: SupportedDJSoftware.analogMixerAppID)
            } else {
                model.completeOnboarding()
            }
            model.scanNow()
            return
        }
        if let next = Step(rawValue: step.rawValue + 1) { step = next }
    }
}

#Preview("Onboarding Welcome") {
    OnboardingView(startingStep: .welcome)
        .environmentObject(AppModel())
        .preferredColorScheme(.dark)
}

#Preview("Onboarding Welcome Light") {
    OnboardingView(startingStep: .welcome)
        .environmentObject(AppModel())
        .preferredColorScheme(.light)
}

#Preview("Onboarding DJ Apps") {
    OnboardingView(startingStep: .djApps)
        .environmentObject(AppModel())
        .preferredColorScheme(.dark)
}

#Preview("Onboarding DJ Apps Light") {
    OnboardingView(startingStep: .djApps)
        .environmentObject(AppModel())
        .preferredColorScheme(.light)
}

#Preview("Onboarding Folder Access") {
    OnboardingView(startingStep: .folderAccess)
        .environmentObject(AppModel())
        .preferredColorScheme(.dark)
}

#Preview("Onboarding Folder Access Light") {
    OnboardingView(startingStep: .folderAccess)
        .environmentObject(AppModel())
        .preferredColorScheme(.light)
}

#Preview("Onboarding Archive") {
    OnboardingView(startingStep: .archive)
        .environmentObject(AppModel())
        .preferredColorScheme(.dark)
}

#Preview("Onboarding Archive Light") {
    OnboardingView(startingStep: .archive)
        .environmentObject(AppModel())
        .preferredColorScheme(.light)
}

#Preview("Onboarding History") {
    OnboardingView(startingStep: .history)
        .environmentObject(AppModel())
        .preferredColorScheme(.dark)
}

#Preview("Onboarding History Light") {
    OnboardingView(startingStep: .history)
        .environmentObject(AppModel())
        .preferredColorScheme(.light)
}

#Preview("Onboarding Ready") {
    onboardingReadyPreview()
}

#Preview("Onboarding Ready Light") {
    onboardingReadyPreview(colorScheme: .light)
}

@MainActor
private func onboardingReadyPreview(colorScheme: ColorScheme = .dark) -> some View {
    let model = AppModel()
    model.previewApplyConfiguredRecordingsFolders(reachableAppIDs: ["serato"])
    return OnboardingView(startingStep: .ready)
        .environmentObject(model)
        .preferredColorScheme(colorScheme)
}

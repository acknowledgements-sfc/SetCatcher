import SwiftUI
import DJMemoryCore

/// First-run onboarding: six-step setup with a compact step rail (HANDOFF §4.7).
struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel
    @State private var step: Step

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

            appChips

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
                    "Choose the folders your DJ apps already record into. DJMemory copies completed recordings and never touches the originals.")
        case .djApps:
            return ("We found your", "DJ apps.",
                    "DJMemory watches the folders these already record into. Nothing is installed, nothing is changed.")
        case .folderAccess:
            return ("Grant one folder, and the set", "starts to take shape.",
                    "\(grantedFolderCount) granted so far — pick another, or move on. Nothing leaves this Mac.")
        case .archive:
            return ("Protected copies land", "here.",
                    "Source recordings stay where they are. DJMemory writes protected copies to your archive.")
        case .history:
            return ("Track history is", "optional.",
                    "Import set histories later from each app’s setup screen. Skipping this step is safe.")
        case .ready:
            return ("You’re", "ready.",
                    "DJMemory will watch granted folders and copy completed recordings into your archive.")
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch step {
        case .archive:
            VStack(alignment: .leading, spacing: 10) {
                PathChip(path: model.archiveRoot.path)
                Button("Change Archive Folder") { model.chooseArchiveFolder() }
                    .buttonStyle(DJHollowButtonStyle())
                    .accessibilityIdentifier("onboarding.reviewArchive")
            }
        case .ready:
            MetricTile(
                label: "Protected sources",
                value: "\(model.protectedAdapterCount)",
                tone: model.protectedAdapterCount > 0 ? .ok : .warn
            )
        case .folderAccess where installedCount == 0:
            Text("Install a DJ app, or use the chips below to choose folders manually.")
                .font(.system(size: DJToken.TypeSize.secondary))
                .foregroundStyle(DJToken.warn)
        default:
            EmptyView()
        }
    }

    private var appChips: some View {
        HStack(spacing: 9) {
            ForEach(model.probeResults.prefix(6), id: \.software.id) { result in
                OnboardingAppChip(
                    result: result,
                    granted: model.hasConfiguredRecordingsFolder(appID: result.software.id),
                    canChooseFolder: step == .folderAccess
                ) {
                    model.chooseFolder(appID: result.software.id, kind: .recordings)
                }
            }
            Spacer(minLength: 0)
        }
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

    private var installedCount: Int { model.installedOrRunningProbeCount }
    private var grantedFolderCount: Int { model.configuredRecordingsCount }

    private var canContinue: Bool {
        switch step {
        case .djApps:
            return installedCount >= 1 || !model.probeResults.isEmpty
        case .folderAccess:
            return grantedFolderCount >= 1
        default:
            return true
        }
    }

    private func advance() {
        if step == .ready {
            model.completeOnboarding(destination: .protection)
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

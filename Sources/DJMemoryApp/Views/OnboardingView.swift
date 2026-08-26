import SwiftUI
import DJMemoryCore

/// First-run onboarding (design `1c`): setup reframed as a set coming to life. Each granted
/// folder lights another segment of a warm build-waveform. Warm-ink ground, one serif accent.
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

            HeroHeader(
                eyebrow: step.title,
                eyebrowColor: DJToken.warmGold,
                headline: copy.headline,
                accentTail: copy.accent,
                headlineSize: DJToken.TypeSize.displayOnboarding,
                subline: copy.subline
            )

            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Waveform(
                seed: "onboarding-build",
                barCount: 72,
                gradient: (DJToken.warmGold, DJToken.warmGold.opacity(0.7)),
                litFraction: litFraction
            )
            .frame(height: 84)

            appChips

            footer
        }
        .padding(32)
        .frame(width: 720, height: 560)
        .background(DJToken.Ground.onboarding)
        .preferredColorScheme(.dark)
    }

    private var topBar: some View {
        HStack(spacing: 11) {
            EQGlyph()
                .frame(width: 24, height: 24)
                .foregroundStyle(DJToken.warmGold)
            Text("DJMemory")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(white: 0.94))
            Spacer()
            Text("Step \(step.rawValue + 1) / \(Step.allCases.count)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(DJToken.warmGold.opacity(0.7))
        }
    }

    // MARK: Per-step copy

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

    // MARK: Per-step interactive detail

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

    // MARK: App chips (granted gold / found dim / not installed faint)

    private var appChips: some View {
        HStack(spacing: 9) {
            ForEach(model.probeResults.prefix(6), id: \.software.id) { result in
                chip(result)
            }
            Spacer(minLength: 0)
        }
    }

    private func chip(_ result: SoftwareProbeResult) -> some View {
        let granted = model.hasConfiguredRecordingsFolder(appID: result.software.id)
        let installed = !result.installedApplicationURLs.isEmpty
        let interactive = step == .folderAccess && !granted
        return Button {
            if interactive { model.chooseFolder(appID: result.software.id, kind: .recordings) }
        } label: {
            HStack(spacing: 7) {
                Circle()
                    .fill(granted ? DJToken.warmGold : Color.white.opacity(installed ? 0.35 : 0.15))
                    .frame(width: 7, height: 7)
                Text(result.software.displayName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(chipText(granted: granted, installed: installed))
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                (granted ? DJToken.warmGold.opacity(0.14) : Color.white.opacity(0.04)),
                in: Capsule()
            )
            .overlay(
                Capsule().stroke(
                    granted ? DJToken.warmGold.opacity(0.4) : Color.white.opacity(0.1),
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(.plain)
        .disabled(!interactive)
        .accessibilityIdentifier("onboarding.folder.\(result.software.id)")
    }

    private func chipText(granted: Bool, installed: Bool) -> Color {
        if granted { return Color(red: 0.94, green: 0.88, blue: 0.75) }
        return Color.white.opacity(installed ? 0.6 : 0.35)
    }

    // MARK: Footer

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
                    .foregroundStyle(DJToken.Ground.base)
                    .padding(.horizontal, 22)
                    .frame(minHeight: 40)
                    .background(DJToken.warmGold.opacity(canContinue ? 1 : 0.4), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!canContinue)
            .keyboardShortcut(.defaultAction)
            .accessibilityIdentifier(step == .ready ? "onboarding.startSetup" : "onboarding.continue")
        }
    }

    // MARK: Progress + gating

    private var litFraction: Double {
        let stepProgress = Double(step.rawValue) / Double(Step.allCases.count - 1)
        let folderProgress = Double(grantedFolderCount) / Double(max(1, model.probeResults.count))
        return min(1, max(folderProgress, stepProgress * 0.7))
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

#Preview("Onboarding Folder Access") {
    OnboardingView(startingStep: .folderAccess)
        .environmentObject(AppModel())
        .preferredColorScheme(.dark)
}

#Preview("Onboarding Ready") {
    onboardingReadyPreview()
}

@MainActor
private func onboardingReadyPreview() -> some View {
    let model = AppModel()
    model.previewApplyConfiguredRecordingsFolders(reachableAppIDs: ["serato"])
    return OnboardingView(startingStep: .ready)
        .environmentObject(model)
        .preferredColorScheme(.dark)
}

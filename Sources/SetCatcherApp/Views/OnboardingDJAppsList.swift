import SwiftUI
import SetCatcherCore

/// First-run software sources plus Analog Mixer (HANDOFF §4.7, analog-mixer-setup).
struct OnboardingDJAppsList: View {
    let results: [SoftwareProbeResult]
    let analogSelected: Bool
    let folderMode: Bool
    let isGranted: (String) -> Bool
    let onSelectAnalog: () -> Void
    let onSelectSoftware: () -> Void
    let onChooseFolder: (SoftwareProbeResult) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                if !folderMode {
                    analogRow
                }
                ForEach(sortedResults, id: \.software.id) { result in
                    OnboardingDJAppRow(
                        result: result,
                        granted: isGranted(result.software.id),
                        folderMode: folderMode,
                        onSelectSoftware: onSelectSoftware,
                        onChooseFolder: { onChooseFolder(result) }
                    )
                }
            }
        }
    }

    private var sortedResults: [SoftwareProbeResult] {
        results.enumerated().sorted { lhs, rhs in
            let left = presenceRank(lhs.element)
            let right = presenceRank(rhs.element)
            if left != right { return left < right }
            return lhs.offset < rhs.offset
        }.map(\.element)
    }

    private func presenceRank(_ result: SoftwareProbeResult) -> Int {
        if result.isRunning { return 0 }
        if result.isInstalled { return 1 }
        if !result.existingRecordingURLs.isEmpty { return 2 }
        return 3
    }

    private var analogRow: some View {
        Button(action: onSelectAnalog) {
            HStack(spacing: 8) {
                Circle()
                    .fill(analogSelected ? DJToken.primary : DJToken.mutedForeground.opacity(0.35))
                    .frame(width: 7, height: 7)
                Text("Analog Mixer")
                    .font(.system(size: DJToken.TypeSize.secondary, weight: .semibold))
                    .foregroundStyle(DJToken.foreground)
                SupportBadge(status: .manualSetup)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                analogSelected ? DJToken.primary.opacity(0.14) : DJToken.muted.opacity(0.6),
                in: RoundedRectangle(cornerRadius: DJToken.Radius.maximum)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DJToken.Radius.maximum)
                    .stroke(analogSelected ? DJToken.primary.opacity(0.4) : DJToken.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("onboarding.analogMixer")
    }
}

struct OnboardingDJAppRow: View {
    let result: SoftwareProbeResult
    let granted: Bool
    let folderMode: Bool
    let onSelectSoftware: () -> Void
    let onChooseFolder: () -> Void

    private var foundFolder: URL? {
        result.existingRecordingURLs.first
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Button(action: onSelectSoftware) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(dotTint)
                        .frame(width: 7, height: 7)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(result.software.displayName)
                                .font(.system(size: DJToken.TypeSize.secondary, weight: .semibold))
                                .foregroundStyle(textTint)
                                .lineLimit(1)
                            Text(result.onboardingPresenceLabel)
                                .font(.system(size: DJToken.TypeSize.micro))
                                .foregroundStyle(DJToken.mutedForeground)
                            SupportBadge(status: result.software.supportStatus)
                        }
                        if let foundFolder {
                            PathChip(path: foundFolder.path)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if folderMode {
                folderAction
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: DJToken.Radius.maximum))
        .overlay(
            RoundedRectangle(cornerRadius: DJToken.Radius.maximum)
                .stroke(granted ? DJToken.primary.opacity(0.4) : DJToken.hairline, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var folderAction: some View {
        if granted {
            Text("Granted")
                .font(.system(size: DJToken.TypeSize.micro, weight: .semibold))
                .foregroundStyle(DJToken.primary)
                .accessibilityIdentifier("onboarding.folder.\(result.software.id)")
        } else {
            Button(foundFolder == nil ? "Choose folder" : "Grant found folder") {
                onChooseFolder()
            }
            .buttonStyle(DJSecondaryButtonStyle())
            .accessibilityIdentifier("onboarding.folder.\(result.software.id)")
        }
    }

    private var dotTint: Color {
        granted ? DJToken.primary : DJToken.mutedForeground.opacity(result.isInstalled || result.isRunning ? 0.35 : 0.15)
    }

    private var textTint: Color {
        if granted { return DJToken.foreground }
        return DJToken.mutedForeground.opacity(result.isInstalled || result.isRunning ? 1 : 0.6)
    }

    private var rowBackground: Color {
        granted ? DJToken.primary.opacity(0.14) : DJToken.muted.opacity(0.6)
    }
}

#Preview("Onboarding DJ Apps none installed") {
    OnboardingDJAppsList(
        results: SupportedDJSoftware.all
            .filter { SupportedDJSoftware.isOnboardingSoftwareSource(id: $0.id) }
            .map {
                SoftwareProbeResult(
                    software: $0,
                    installedApplicationURLs: [],
                    runningApplicationBundleIdentifiers: [],
                    existingRecordingURLs: [],
                    existingHistoryURLs: []
                )
            },
        analogSelected: false,
        folderMode: false,
        isGranted: { _ in false },
        onSelectAnalog: {},
        onSelectSoftware: {},
        onChooseFolder: { _ in }
    )
    .padding()
    .frame(width: 656, height: 280)
    .background(DJToken.background)
    .preferredColorScheme(.dark)
}

#Preview("Onboarding DJ Apps none installed Light") {
    OnboardingDJAppsList(
        results: SupportedDJSoftware.all
            .filter { SupportedDJSoftware.isOnboardingSoftwareSource(id: $0.id) }
            .map {
                SoftwareProbeResult(
                    software: $0,
                    installedApplicationURLs: [],
                    runningApplicationBundleIdentifiers: [],
                    existingRecordingURLs: [],
                    existingHistoryURLs: []
                )
            },
        analogSelected: true,
        folderMode: false,
        isGranted: { _ in false },
        onSelectAnalog: {},
        onSelectSoftware: {},
        onChooseFolder: { _ in }
    )
    .padding()
    .frame(width: 656, height: 280)
    .background(DJToken.background)
    .preferredColorScheme(.light)
}

#Preview("Onboarding Serato folder found") {
    onboardingSeratoFoundPreview()
}

#Preview("Onboarding Serato folder found Light") {
    onboardingSeratoFoundPreview(colorScheme: .light)
}

@MainActor
private func onboardingSeratoFoundPreview(colorScheme: ColorScheme = .dark) -> some View {
    let serato = SupportedDJSoftware.all.first { $0.id == "serato" }!
    let others = SupportedDJSoftware.all
        .filter { SupportedDJSoftware.isOnboardingSoftwareSource(id: $0.id) && $0.id != "serato" }
        .map {
            SoftwareProbeResult(
                software: $0,
                installedApplicationURLs: [],
                runningApplicationBundleIdentifiers: [],
                existingRecordingURLs: [],
                existingHistoryURLs: []
            )
        }
    let found = SoftwareProbeResult(
        software: serato,
        installedApplicationURLs: [URL(fileURLWithPath: "/Applications/Serato DJ Pro.app")],
        runningApplicationBundleIdentifiers: [],
        existingRecordingURLs: [URL(fileURLWithPath: "/Users/dj/Music/_Serato_/Recording")],
        existingHistoryURLs: []
    )
    return OnboardingDJAppsList(
        results: [found] + others,
        analogSelected: false,
        folderMode: true,
        isGranted: { $0 == "serato" },
        onSelectAnalog: {},
        onSelectSoftware: {},
        onChooseFolder: { _ in }
    )
    .padding()
    .frame(width: 656, height: 280)
    .background(DJToken.background)
    .preferredColorScheme(colorScheme)
}

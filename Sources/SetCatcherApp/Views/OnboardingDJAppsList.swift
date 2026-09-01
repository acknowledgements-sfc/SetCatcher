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
    let onChooseFolder: (SoftwareProbeResult, DJSoftwareInstallation?) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                if !folderMode {
                    analogRow
                }
                ForEach(displayRows) { row in
                    OnboardingDJAppRow(
                        result: row.result,
                        installation: row.installation,
                        granted: isGranted(row.result.software.id),
                        folderMode: folderMode,
                        onSelectSoftware: onSelectSoftware,
                        onChooseFolder: { onChooseFolder(row.result, row.installation) }
                    )
                }
            }
        }
    }

    private struct DisplayRow: Identifiable {
        let id: String
        let result: SoftwareProbeResult
        let installation: DJSoftwareInstallation?
    }

    private var displayRows: [DisplayRow] {
        var rows: [DisplayRow] = []
        for result in sortedResults {
            if result.installations.isEmpty {
                rows.append(DisplayRow(id: result.software.id, result: result, installation: nil))
            } else {
                for installation in result.installations {
                    rows.append(
                        DisplayRow(
                            id: installation.id,
                            result: result,
                            installation: installation
                        )
                    )
                }
            }
        }
        return rows
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
    let installation: DJSoftwareInstallation?
    let granted: Bool
    let folderMode: Bool
    let onSelectSoftware: () -> Void
    let onChooseFolder: () -> Void

    private var displayTitle: String {
        installation?.variantLabel ?? result.software.displayName
    }

    private var discoveredRecordingPaths: [DiscoveredDJPath] {
        if let installation {
            return installation.discoveredPaths.filter { $0.kind == .recordings }
        }
        return result.familyDiscoveredPaths.filter { $0.kind == .recordings }
    }

    private var discoveredHistoryPaths: [DiscoveredDJPath] {
        if let installation {
            return installation.discoveredPaths.filter { $0.kind == .history }
        }
        return result.familyDiscoveredPaths.filter { $0.kind == .history }
    }

    private var bestRecordingFolder: URL? {
        (installation?.bestPath(ofKind: .recordings) ?? discoveredRecordingPaths.first)?.url
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
                            Text(displayTitle)
                                .font(.system(size: DJToken.TypeSize.secondary, weight: .semibold))
                                .foregroundStyle(textTint)
                                .lineLimit(1)
                            Text(presenceLabel)
                                .font(.system(size: DJToken.TypeSize.micro))
                                .foregroundStyle(DJToken.mutedForeground)
                            SupportBadge(status: result.software.supportStatus)
                        }
                        if let version = installation?.bundleVersion, !version.isEmpty {
                            Text(version)
                                .font(.system(size: DJToken.TypeSize.micro))
                                .foregroundStyle(DJToken.mutedForeground)
                        }
                        ForEach(discoveredRecordingPaths, id: \.url.path) { path in
                            pathChip(path)
                        }
                        if folderMode {
                            ForEach(discoveredHistoryPaths, id: \.url.path) { path in
                                pathChip(path, prefix: "History")
                            }
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
    private func pathChip(_ path: DiscoveredDJPath, prefix: String? = nil) -> some View {
        HStack(spacing: 4) {
            if let prefix {
                Text("\(prefix):")
                    .font(.system(size: DJToken.TypeSize.micro))
                    .foregroundStyle(DJToken.mutedForeground)
            }
            PathChip(path: path.url.path)
            Text(path.sourceLabel)
                .font(.system(size: DJToken.TypeSize.micro))
                .foregroundStyle(DJToken.mutedForeground)
        }
    }

    @ViewBuilder
    private var folderAction: some View {
        if granted {
            Text("Granted")
                .font(.system(size: DJToken.TypeSize.micro, weight: .semibold))
                .foregroundStyle(DJToken.primary)
                .accessibilityIdentifier("onboarding.folder.\(result.software.id)")
        } else {
            Button(bestRecordingFolder == nil ? "Choose folder" : "Grant found folder") {
                onChooseFolder()
            }
            .buttonStyle(DJSecondaryButtonStyle())
            .accessibilityIdentifier("onboarding.folder.\(result.software.id)")
        }
    }

    private var presenceLabel: String {
        if let installation, installation.isRunning {
            return "Running"
        }
        if installation != nil {
            return "Installed"
        }
        return result.onboardingPresenceLabel
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

private extension DiscoveredDJPath {
    var sourceLabel: String {
        switch source {
        case .userPreference:
            return "From app prefs"
        case .catalogDefault:
            return "Default location"
        case .filesystemProbe:
            return "Found on disk"
        }
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
        onChooseFolder: { _, _ in }
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
        onChooseFolder: { _, _ in }
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
    let recordingURL = URL(fileURLWithPath: "/Users/dj/Music/_Serato_/Recording")
    let installation = DJSoftwareInstallation(
        familyID: "serato",
        variantLabel: "Serato DJ Pro 3",
        bundleIdentifier: "com.serato.seratodj",
        bundleVersion: "3.2.1",
        appURL: URL(fileURLWithPath: "/Applications/Serato DJ Pro.app"),
        isRunning: false,
        discoveredPaths: [
            DiscoveredDJPath(
                kind: .recordings,
                url: recordingURL,
                source: .userPreference,
                note: "Serato prefs record_location"
            )
        ]
    )
    let found = SoftwareProbeResult(software: serato, installations: [installation])
    return OnboardingDJAppsList(
        results: [found] + others,
        analogSelected: false,
        folderMode: true,
        isGranted: { $0 == "serato" },
        onSelectAnalog: {},
        onSelectSoftware: {},
        onChooseFolder: { _, _ in }
    )
    .padding()
    .frame(width: 656, height: 280)
    .background(DJToken.background)
    .preferredColorScheme(colorScheme)
}

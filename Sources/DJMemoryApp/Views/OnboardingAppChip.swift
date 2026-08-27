import SwiftUI
import DJMemoryCore

struct OnboardingAppChip: View {
    let result: SoftwareProbeResult
    let granted: Bool
    let canChooseFolder: Bool
    let chooseFolder: () -> Void

    private var installed: Bool {
        !result.installedApplicationURLs.isEmpty
    }

    private var interactive: Bool {
        canChooseFolder && !granted
    }

    var body: some View {
        Button {
            if interactive {
                chooseFolder()
            }
        } label: {
            HStack(spacing: 7) {
                Circle()
                    .fill(statusTint)
                    .frame(width: 7, height: 7)
                Text(result.software.displayName)
                    .font(.system(size: DJToken.TypeSize.secondary, weight: .semibold))
                    .foregroundStyle(textTint)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(backgroundTint, in: RoundedRectangle(cornerRadius: DJToken.Radius.maximum))
            .overlay(
                RoundedRectangle(cornerRadius: DJToken.Radius.maximum)
                    .stroke(borderTint, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!interactive)
        .accessibilityIdentifier("onboarding.folder.\(result.software.id)")
    }

    private var statusTint: Color {
        granted ? DJToken.primary : DJToken.mutedForeground.opacity(installed ? 0.35 : 0.15)
    }

    private var textTint: Color {
        if granted {
            return DJToken.foreground
        }
        return DJToken.mutedForeground.opacity(installed ? 1 : 0.6)
    }

    private var backgroundTint: Color {
        granted ? DJToken.primary.opacity(0.14) : DJToken.muted.opacity(0.6)
    }

    private var borderTint: Color {
        granted ? DJToken.primary.opacity(0.4) : DJToken.hairline
    }
}

#Preview("Onboarding App Chip") {
    VStack(spacing: 8) {
        OnboardingAppChip(
            result: .init(
                software: SupportedDJSoftware.all[0],
                installedApplicationURLs: [],
                runningApplicationBundleIdentifiers: [],
                existingRecordingURLs: [],
                existingHistoryURLs: []
            ),
            granted: false,
            canChooseFolder: true
        ) {}
        OnboardingAppChip(
            result: .init(
                software: SupportedDJSoftware.all[0],
                installedApplicationURLs: [],
                runningApplicationBundleIdentifiers: [],
                existingRecordingURLs: [],
                existingHistoryURLs: []
            ),
            granted: true,
            canChooseFolder: true
        ) {}
    }
    .padding()
    .background(DJToken.background)
}

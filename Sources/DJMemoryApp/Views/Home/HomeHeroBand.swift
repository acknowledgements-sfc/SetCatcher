import SwiftUI
import DJMemoryCore

/// Home hero (design `1a`): the giant "Protected." answer to "am I protected?", a living
/// status waveform, and a row of per-app source lanes — all on the cool gradient ground.
struct HomeHeroBand: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack(alignment: .topTrailing) {
            EQGlyph()
                .frame(width: 150, height: 150)
                .foregroundStyle(accent.opacity(0.08))
                .padding(.trailing, 12)
                .padding(.top, 6)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 26) {
                HStack(alignment: .top, spacing: 16) {
                    HeroHeader(
                        eyebrow: eyebrow,
                        eyebrowColor: accent,
                        headline: headline,
                        subline: subline
                    )
                    Spacer(minLength: 16)
                    VStack(spacing: 8) {
                        Button {
                            model.scanNow()
                        } label: {
                            Label(model.isScanning ? "Scanning…" : "Scan Now", systemImage: "waveform.badge.magnifyingglass")
                        }
                        .buttonStyle(DJPrimaryButtonStyle())
                        .disabled(model.isScanning)
                        .accessibilityIdentifier("home.scanNow")

                        Button("Open Library") { model.openLibrary() }
                            .buttonStyle(DJGhostButtonStyle())
                            .accessibilityIdentifier("home.openLibrary")
                    }
                }

                Waveform(
                    seed: "protected-status",
                    barCount: 90,
                    gradient: waveGradient,
                    breathing: isLive
                )
                .frame(height: 116)

                HomeSourceLanes()
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DJToken.Ground.home, in: RoundedRectangle(cornerRadius: DJToken.Radius.maximum))
        .overlay(
            RoundedRectangle(cornerRadius: DJToken.Radius.maximum)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.hero")
    }

    private var isRecording: Bool { model.captureState.isRecording }

    private var headline: String {
        if isRecording { return "Recording…" }
        switch model.protectionState {
        case .protected: return "Protected."
        case .scanning: return "Scanning…"
        case .needsSetup: return "Needs setup."
        case .attentionNeeded: return "Attention needed."
        }
    }

    private var accent: Color {
        if isRecording { return DJToken.recordRed }
        switch model.protectionState {
        case .protected: return DJToken.signalGreen
        case .scanning: return DJToken.primary
        case .needsSetup: return DJToken.mutedForeground
        case .attentionNeeded: return DJToken.warn
        }
    }

    private var waveGradient: (top: Color, bottom: Color) {
        if isRecording { return (DJToken.recordRedBright, DJToken.recordRed) }
        switch model.protectionState {
        case .protected: return (DJToken.signalGreenBright, DJToken.signalGreenDeep)
        case .scanning: return (DJToken.primary.opacity(0.9), DJToken.primary.opacity(0.45))
        case .needsSetup: return (DJToken.mutedForeground.opacity(0.7), DJToken.mutedForeground.opacity(0.3))
        case .attentionNeeded: return (DJToken.warn, DJToken.warn.opacity(0.45))
        }
    }

    private var isLive: Bool {
        isRecording || model.protectionState == .protected || model.protectionState == .scanning
    }

    private var eyebrow: String {
        if isRecording { return "Recording in progress" }
        return "Status · \(model.lastScanDisplayText)"
    }

    private var subline: String {
        let sources = model.protectedAdapterCount
        let archived = model.librarySummaries.count
        switch model.protectionState {
        case .protected:
            return "\(sources) sources watched · \(archived) sets archived · nothing to do."
        case .scanning:
            return "Checking \(sources) watched folders for new recordings…"
        case .needsSetup:
            return "\(sources) of \(model.probeResults.count) sources watched. Finish setup to protect the rest."
        case .attentionNeeded:
            return "A saved folder is unavailable. Everything already archived is safe."
        }
    }
}

/// The brand logomark: a circle enclosing three EQ bars of different heights.
/// Inherits `foregroundStyle` (uses currentColor), so callers set the tint.
struct EQGlyph: View {
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                Circle().strokeBorder(lineWidth: max(1, s * 0.035))
                HStack(alignment: .center, spacing: s * 0.09) {
                    Capsule().frame(width: s * 0.07, height: s * 0.32)
                    Capsule().frame(width: s * 0.07, height: s * 0.54)
                    Capsule().frame(width: s * 0.07, height: s * 0.21)
                }
            }
            .frame(width: s, height: s)
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

/// Per-app source lanes under the status waveform. Each lane is glanceable (accent bar,
/// name, state micro-label, status dot) and routes to that app's setup/recovery.
struct HomeSourceLanes: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 10) {
            ForEach(model.probeResults, id: \.software.id) { result in
                lane(result)
            }
        }
    }

    private func lane(_ result: SoftwareProbeResult) -> some View {
        let state = model.setupState(for: result)
        let tone = HomeFormatting.setupTone(state)
        return Button {
            route(result)
        } label: {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: DJToken.Radius.swatch)
                    .fill(DJToken.accent(forAppID: result.software.id))
                    .frame(width: 3, height: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.software.displayName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DJToken.foreground)
                        .lineLimit(1)
                    Text(state.displayName)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .tracking(0.5)
                        .textCase(.uppercase)
                        .foregroundStyle(tone.color)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                StatusDot(tone: tone)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: DJToken.Radius.maximum))
            .overlay(
                RoundedRectangle(cornerRadius: DJToken.Radius.maximum)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.lane.\(result.software.id)")
    }

    private func route(_ result: SoftwareProbeResult) {
        let state = model.setupState(for: result)
        if model.isConfiguredRecordingsFolderUnreachable(appID: result.software.id) || state == .error {
            model.selectedRoute = .recovery(result.software.id)
        } else if state == .needsFolderAccess {
            model.selectedRoute = .app(result.software.id)
            model.chooseFolder(appID: result.software.id, kind: .recordings)
        } else {
            model.selectedRoute = .app(result.software.id)
        }
    }
}

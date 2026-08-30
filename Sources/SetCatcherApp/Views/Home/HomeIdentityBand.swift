import SwiftUI
import SetCatcherCore

/// Home identity band: protection status, scan actions, and per-app source lanes.
struct HomeIdentityBand: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Panel(padding: 16) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(eyebrow)
                            .microLabelStyle()
                        Text(headline)
                            .font(.system(size: DJToken.TypeSize.title, weight: .semibold))
                            .foregroundStyle(DJToken.foreground)
                        Text(subline)
                            .font(.system(size: DJToken.TypeSize.body))
                            .foregroundStyle(DJToken.mutedForeground)
                            .fixedSize(horizontal: false, vertical: true)
                    }
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

                HomeSourceLanes()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.identity")
    }

    private var headline: String {
        if model.captureState.isRecording { return "Recording…" }
        switch model.protectionState {
        case .protected: return "Protected"
        case .scanning: return "Scanning…"
        case .needsSetup: return "Needs setup"
        case .attentionNeeded: return "Attention needed"
        }
    }

    private var eyebrow: String {
        if model.captureState.isRecording { return "Recording in progress" }
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

/// Per-app source lanes under the status band.
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
            .background(DJToken.muted, in: RoundedRectangle(cornerRadius: DJToken.Radius.maximum))
            .overlay(
                RoundedRectangle(cornerRadius: DJToken.Radius.maximum)
                    .stroke(DJToken.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(result.software.displayName), \(state.displayName)")
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

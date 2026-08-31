import AppKit
import SetCatcherCore
import SwiftUI

/// Custom dropdown panel for the `MenuBarExtra` (`.window` style — see `SetCatcherApp.swift`).
/// Dispatch 03: 320pt panel, LiveProtectionState headlines, contextual capture actions.
struct MenuBarStatusView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var statusDotPulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            captureStatusSection

            Rectangle()
                .fill(DJToken.hairline)
                .frame(height: 1)

            MenuBarActionList()
        }
        .frame(width: 320, alignment: .leading)
        .background(DJToken.elevated)
        .overlay(
            RoundedRectangle(cornerRadius: DJToken.Radius.maximum)
                .stroke(DJToken.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DJToken.Radius.maximum))
        .shadow(color: .black.opacity(0.5), radius: 16, y: 12)
        .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
        .preferredColorScheme(.dark)
    }

    // MARK: Capture status

    @ViewBuilder
    private var captureStatusSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Protection Status")
                    .microLabelStyle()
                Spacer(minLength: 8)
                if model.cockpitSnapshot.state.primaryDisplay == .attentionNeeded {
                    Text("ATTENTION")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(DJToken.LiveState.attention)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(DJToken.LiveState.attention.opacity(0.15), in: Capsule())
                        .accessibilityIdentifier("menuBar.attentionBadge")
                }
            }
            .padding(.bottom, 8)

            HStack(spacing: 8) {
                Circle()
                    .fill(statusTint)
                    .frame(width: 7, height: 7)
                    .opacity(statusDotOpacity)
                    .animation(statusDotAnimation, value: statusDotPulse)
                    .onAppear { statusDotPulse = isCapturing }
                    .onChange(of: isCapturing) { _, capturing in
                        statusDotPulse = capturing
                    }
                Text(stateHeadline)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DJToken.foreground)
            }
            .padding(.bottom, showsAppLine ? 6 : 2)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Protection status, \(stateHeadline)")
            .accessibilityIdentifier("menuBar.captureState")

            if showsAppLine {
                Text(appLineText)
                    .font(.system(size: 11))
                    .foregroundStyle(DJToken.mutedForeground)
                    .padding(.leading, 15)
                    .padding(.bottom, 6)
            }

            if showsMeter {
                CaptureLevelMeterView(
                    level: model.cockpitSnapshot.inputLevel,
                    accessibilityID: "menuBar.levelMeter",
                    showsScaleMarks: false,
                    compact: true
                )
                .padding(.top, 4)
                .padding(.bottom, 6)
            }

            if model.recordingStartedAt != nil {
                HStack(alignment: .firstTextBaseline) {
                    Text("ELAPSED")
                        .font(.system(size: 10))
                        .textCase(.uppercase)
                        .foregroundStyle(DJToken.mutedForeground)
                    Spacer(minLength: 8)
                    Text(model.menuBarElapsedHMS ?? "00:00:00")
                        .font(.system(size: 15, design: .monospaced))
                        .foregroundStyle(DJToken.foreground)
                        .monospacedDigit()
                }
                .padding(10)
                .background(DJToken.muted, in: RoundedRectangle(cornerRadius: DJToken.Radius.control))
                .padding(.top, 8)
                .accessibilityIdentifier("menuBar.recordingElapsed")
            }

            Text(lastCaptureLine)
                .font(.system(size: 11))
                .foregroundStyle(model.lastCaptureIsFailure ? DJToken.warn : DJToken.mutedForeground)
                .padding(.top, 10)
                .overlay(alignment: .top) {
                    Rectangle().fill(DJToken.hairline).frame(height: 1)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Previous capture, \(lastCaptureLine)")
                .accessibilityIdentifier("menuBar.previousCapture")

            if let warning = model.folderHealthWarning {
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(DJToken.warn)
                    .padding(.top, 8)
                    .accessibilityIdentifier("menuBar.folderHealthWarning")
            }

            if model.settings.showFolderScanDetailsInMenuBar {
                scanDetailsSection
            }
        }
        .padding(EdgeInsets(top: 14, leading: 16, bottom: 12, trailing: 16))
    }

    private var statusTint: Color {
        DJToken.LiveState.accent(for: model.cockpitSnapshot.state)
    }

    private var stateHeadline: String {
        let cockpit = model.cockpitSnapshot
        let app = cockpit.sourceDisplayName ?? "DJ app"
        switch cockpit.state.primaryDisplay {
        case .noSource: return "No protection source"
        case .detected: return "\(app) detected"
        case .ready: return "Ready — not armed"
        case .armed, .setProtected: return "\(app) is Armed"
        case .capturing: return "Capturing…"
        case .saving: return "Saving…"
        case .attentionNeeded: return "Attention needed"
        }
    }

    private var showsAppLine: Bool {
        switch model.cockpitSnapshot.state.primaryDisplay {
        case .armed, .capturing, .ready, .setProtected: return true
        default: return false
        }
    }

    private var appLineText: String {
        let cockpit = model.cockpitSnapshot
        let app = cockpit.sourceDisplayName ?? "DJ app"
        switch cockpit.state.primaryDisplay {
        case .armed, .setProtected:
            return "\(app) — waiting for audio"
        case .capturing:
            return "Capturing from \(app)"
        case .ready:
            return "\(app) configured · arm to watch"
        default:
            return ""
        }
    }

    private var showsMeter: Bool {
        switch model.cockpitSnapshot.state.primaryDisplay {
        case .armed, .capturing, .setProtected: return true
        default: return false
        }
    }

    private var isCapturing: Bool {
        model.cockpitSnapshot.state.primaryDisplay == .capturing
    }

    private var statusDotOpacity: Double {
        if reduceMotion || !isCapturing { return 1 }
        return statusDotPulse ? 0.45 : 1
    }

    private var statusDotAnimation: Animation? {
        if reduceMotion || !isCapturing { return .default }
        return .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
    }

    private var lastCaptureLine: String {
        model.previousCaptureSummary ?? "No captures yet"
    }

    // MARK: Legacy scan details (opt-in, off by default)

    private var scanDetailsSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            scanRow("Protected", value: model.headlineStatus)
            scanRow("Last scan", value: model.lastScanDisplayText, mono: true)
            scanRow("Next scan", value: model.nextScanDisplayText, mono: true)
        }
        .padding(.top, 10)
        .overlay(alignment: .top) {
            Rectangle().fill(DJToken.hairline).frame(height: 1)
        }
        .padding(.top, 10)
    }

    private func scanRow(_ label: String, value: String, mono: Bool = false) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(DJToken.mutedForeground)
            Spacer()
            Text(value)
                .font(mono ? .system(size: 11, design: .monospaced) : .system(size: 11))
                .foregroundStyle(DJToken.foreground)
        }
        .font(.system(size: 11))
        .accessibilityIdentifier("menuBar.\(label.lowercased().replacingOccurrences(of: " ", with: ""))")
    }
}

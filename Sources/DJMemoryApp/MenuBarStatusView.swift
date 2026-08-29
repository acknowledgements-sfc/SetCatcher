import AppKit
import SwiftUI

/// Custom dropdown panel for the `MenuBarExtra` (`.window` style — see `DJMemoryApp.swift`).
/// Matches the "DJMemory Menu Bar" design handoff: an elevated dark panel with a capture-status
/// half and an actions half, rather than a native `NSMenu`.
struct MenuBarStatusView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            captureStatusSection

            Rectangle()
                .fill(DJToken.hairline)
                .frame(height: 1)

            actionsSection
        }
        .frame(width: 296, alignment: .leading)
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
            Text("Capture Status")
                .microLabelStyle()
                .padding(.bottom, 8)

            HStack(spacing: 8) {
                Circle()
                    .fill(model.menuBarState.tint ?? DJToken.MenuBarStatus.watching)
                    .frame(width: 7, height: 7)
                Text(stateHeadline)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DJToken.foreground)
            }
            .padding(.bottom, showsAppLine ? 6 : 2)
            .accessibilityIdentifier("menuBar.captureState")

            if showsAppLine {
                Text(appLineText)
                    .font(.system(size: 11))
                    .foregroundStyle(DJToken.mutedForeground)
                    .padding(.leading, 15)
                    .padding(.bottom, 6)
            }

            if model.recordingStartedAt != nil {
                HStack(alignment: .firstTextBaseline) {
                    Text("ELAPSED")
                        .font(.system(size: 10))
                        .textCase(.uppercase)
                        .foregroundStyle(DJToken.mutedForeground)
                    Spacer(minLength: 8)
                    Text(model.menuBarElapsedText ?? "0:00")
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

    private var stateHeadline: String {
        switch model.menuBarState {
        case .launching: return "Starting up…"
        case .ready: return "Watching for DJ apps"
        case .armed: return "Ready to capture"
        case .capturing: return "Capturing…"
        case .saving: return "Saving…"
        case .saved: return "Set saved"
        case .failed(let reason): return "Error: \(reason)"
        }
    }

    private var showsAppLine: Bool {
        switch model.menuBarState {
        case .armed, .capturing: return true
        default: return false
        }
    }

    private var appLineText: String {
        switch model.menuBarState {
        case .armed(let name):
            return "\(name ?? "DJ app") is open and ready"
        case .capturing(let name):
            return "Capturing from \(name ?? "DJ app")"
        default:
            return ""
        }
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

    // MARK: Actions

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if model.menuBarState.isPulsing {
                actionRow("Stop Capture", systemImage: "stop.circle", tint: DJToken.danger) {
                    model.stopCapture()
                }
                .accessibilityIdentifier("menuBar.stopCapture")
            }

            actionRow("Open Main Window", systemImage: "macwindow") {
                model.openMainWindow()
            }
            .accessibilityIdentifier("menuBar.openMainWindow")

            actionRow("View Last Capture in Main Window", systemImage: "play.rectangle") {
                model.viewLastCaptureInMainWindow()
            }
            .disabled(model.lastCaptureSession == nil)
            .accessibilityIdentifier("menuBar.viewLastCaptureInMainWindow")

            actionRow("View Last Capture in Finder", systemImage: "folder") {
                model.viewLastCaptureInFinder()
            }
            .disabled(model.lastCaptureSession == nil)
            .accessibilityIdentifier("menuBar.viewLastCaptureInFinder")

            actionRow("App Settings", systemImage: "gearshape") {
                model.openMainWindow()
                model.selectedRoute = .settings
            }
            .accessibilityIdentifier("menuBar.appSettings")

            actionRow("Quit DJMemory", systemImage: "power", tint: DJToken.danger) {
                NSApp.terminate(nil)
            }
            .accessibilityIdentifier("menuBar.quit")

            if let archivePath = model.settings.archiveRootPath {
                Text(archivePath)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(DJToken.mutedForeground)
                    .opacity(0.8)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(EdgeInsets(top: 2, leading: 34, bottom: 4, trailing: 10))
            }
        }
        .padding(6)
    }

    private func actionRow(
        _ label: String,
        systemImage: String,
        tint: Color = DJToken.foreground,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 13))
                    .foregroundStyle(DJToken.mutedForeground)
                    .frame(width: 14)
                Text(label)
                    .font(.system(size: 12.5))
                    .foregroundStyle(tint)
                Spacer(minLength: 0)
            }
            .padding(EdgeInsets(top: 7, leading: 10, bottom: 7, trailing: 10))
            .contentShape(Rectangle())
        }
        .buttonStyle(MenuRowButtonStyle())
    }
}

/// Hover/pressed background matching the design handoff's `background:var(--app-muted)` hover state.
private struct MenuRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed ? DJToken.muted : Color.clear,
                in: RoundedRectangle(cornerRadius: DJToken.Radius.control)
            )
    }
}

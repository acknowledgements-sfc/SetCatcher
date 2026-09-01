import AppKit
import SetCatcherCore
import SwiftUI

/// Bottom half of the menu bar dropdown: contextual capture actions plus window/finder/quit.
internal struct MenuBarActionList: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            contextualCaptureActions

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

            if !hidesPrefsAndQuit {
                actionRow("App Settings", systemImage: "gearshape") {
                    model.openMainWindow()
                    model.selectedRoute = .settings
                }
                .accessibilityIdentifier("menuBar.appSettings")

                actionRow("Quit SetCatcher", systemImage: "power", tint: DJToken.danger) {
                    NSApp.terminate(nil)
                }
                .accessibilityIdentifier("menuBar.quit")
            }

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

    private var hidesPrefsAndQuit: Bool {
        switch model.cockpitSnapshot.state.primaryDisplay {
        case .capturing, .saving, .attentionNeeded:
            return true
        default:
            return false
        }
    }

    @ViewBuilder
    private var contextualCaptureActions: some View {
        switch model.cockpitSnapshot.state.primaryDisplay {
        case .capturing:
            actionRow("Stop Capture", systemImage: "stop.circle", tint: DJToken.danger) {
                model.requestStopCapture()
            }
            .accessibilityIdentifier("menuBar.stopCapture")

            actionRow("Stop & Disarm", systemImage: "bolt.slash") {
                model.requestStopAndDisarmCapture()
            }
            .accessibilityIdentifier("menuBar.stopAndDisarm")

        case .armed, .setProtected:
            actionRow("Start Capture Now", systemImage: "record.circle") {
                model.startCaptureNow()
            }
            .accessibilityIdentifier("menuBar.startCaptureNow")

            actionRow("Disarm", systemImage: "bolt.slash") {
                model.requestDisarmCapture()
            }
            .accessibilityIdentifier("menuBar.disarm")

        case .ready:
            actionRow("Arm Protection", systemImage: "bolt.shield") {
                model.toggleArmFromShortcut()
            }
            .accessibilityIdentifier("menuBar.arm")

        case .detected, .noSource:
            actionRow("Choose Protection Source", systemImage: "slider.horizontal.3") {
                model.openMainWindow()
                model.selectedRoute = .capture
            }
            .accessibilityIdentifier("menuBar.chooseProtectionSource")

        case .attentionNeeded:
            actionRow("Open Live", systemImage: "bolt.shield") {
                model.openMainWindow()
                model.selectedRoute = .home
            }
            .accessibilityIdentifier("menuBar.openLive")

        case .saving:
            EmptyView()
        }
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

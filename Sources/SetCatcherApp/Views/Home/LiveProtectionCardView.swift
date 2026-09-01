import SetCatcherCore
import SwiftUI

/// Sketch-aligned live protection card for the Live route (formerly Home dashboard).
internal struct LiveProtectionCardView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let cockpit = model.cockpitSnapshot
        VStack(alignment: .leading, spacing: 0) {
            card
            if model.liveProtectionState == .setProtected {
                toast
            }
            if let event = cockpit.attentionEvent, cockpit.state.primaryDisplay == .attentionNeeded {
                LiveRecoveryPanelView(
                    event: event,
                    onPrimary: { model.handleLiveRecoveryPrimary(event) },
                    onSecondary: { title in model.handleLiveRecoverySecondary(event, title: title) }
                )
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: 420, alignment: .leading)
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.3),
            value: model.liveProtectionState == .setProtected
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.liveCard")
    }

    private var card: some View {
        let cockpit = model.cockpitSnapshot
        let display = cockpit.state.primaryDisplay
        let accent = DJToken.LiveState.accent(for: cockpit.state)

        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Image(systemName: iconName(for: display))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(accent)
                        .frame(width: 22, height: 22)
                        .accessibilityHidden(true)

                    Text(titleText)
                        .font(.system(size: 15, weight: display == .capturing ? .bold : .semibold))
                        .foregroundStyle(accent)
                        .accessibilityIdentifier("home.liveTitle")
                }

                if let since = sinceText {
                    Text(since)
                        .font(.system(size: 13))
                        .foregroundStyle(DJToken.mutedForeground)
                        .padding(.leading, 32)
                        .accessibilityIdentifier("home.liveSince")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(accent.opacity(0.06))

            DJToken.hairline.frame(height: 1)

            if showsMeter {
                CaptureLevelMeterView(
                    level: cockpit.inputLevel,
                    accessibilityID: "home.liveMeter",
                    showsScaleMarks: false
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }

            HStack {
                Spacer(minLength: 0)
                Text(lastFooterText)
                    .font(.system(size: DJToken.TypeSize.secondary).monospacedDigit())
                    .foregroundStyle(DJToken.mutedForeground)
                    .accessibilityIdentifier("home.liveLast")
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            .padding(.top, showsMeter ? 0 : 8)
        }
        .background(DJToken.elevated, in: RoundedRectangle(cornerRadius: DJToken.Radius.maximum))
        .overlay(
            RoundedRectangle(cornerRadius: DJToken.Radius.maximum)
                .stroke(DJToken.border, lineWidth: 1)
        )
    }

    private var toast: some View {
        Button {
            model.dismissProtectedToast()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text("Set protected")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DJToken.LiveState.protected)

                if let receipt = model.liveProtectionReceipt {
                    Text(receipt.filename)
                        .font(.system(size: DJToken.TypeSize.body, weight: .medium))
                        .foregroundStyle(DJToken.foreground)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(receipt.durationText)
                        Text("·")
                        Text(receipt.sizeText)
                    }
                    .font(.system(size: DJToken.TypeSize.secondary).monospacedDigit())
                    .foregroundStyle(DJToken.mutedForeground)

                    Text(receipt.archivePath)
                        .font(.system(size: DJToken.TypeSize.micro, design: .monospaced))
                        .foregroundStyle(DJToken.mutedForeground)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text(model.liveProtectedToastText)
                        .font(.system(size: DJToken.TypeSize.body))
                        .foregroundStyle(DJToken.mutedForeground)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(DJToken.LiveState.protected.opacity(0.08), in: RoundedRectangle(cornerRadius: DJToken.Radius.control))
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
        // Dispatch-04: 300ms slide/fade in; dismiss is 200ms fade (via transition removal).
        .transition(toastTransition)
        .accessibilityIdentifier("home.liveToast")
        .accessibilityHint("Dismisses the set protected toast")
    }

    private var toastTransition: AnyTransition {
        guard !reduceMotion else { return .identity }
        return .asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity)
                    .animation(.easeOut(duration: 0.3)),
                removal: .opacity.animation(.easeIn(duration: 0.2))
        )
    }

    private var titleText: String {
        let cockpit = model.cockpitSnapshot
        let app = cockpit.sourceDisplayName ?? "SetCatcher"
        switch cockpit.state.primaryDisplay {
        case .noSource:
            return "No protection source"
        case .detected:
            return "\(app) detected"
        case .ready:
            return "\(app) is Ready"
        case .armed, .setProtected:
            return "\(app) is Armed"
        case .capturing:
            return "\(app) is Capturing"
        case .saving:
            return "Saving set…"
        case .attentionNeeded:
            return "Attention needed"
        }
    }

    private var sinceText: String? {
        let cockpit = model.cockpitSnapshot
        switch cockpit.state.primaryDisplay {
        case .armed, .setProtected:
            return cockpit.armedSinceText.map { "since \($0)" }
        case .capturing:
            return model.menuBarElapsedText.map { "\($0) elapsed" }
        case .saving:
            return "archiving…"
        case .attentionNeeded:
            return model.folderHealthWarning
        case .ready:
            return "configured · not armed"
        case .detected:
            return "found · set up to protect"
        case .noSource:
            return "add a source to begin"
        }
    }

    private var showsMeter: Bool {
        switch model.cockpitSnapshot.state.primaryDisplay {
        case .armed, .capturing, .setProtected:
            return true
        default:
            return false
        }
    }

    private var lastFooterText: String {
        if let last = model.cockpitSnapshot.lastProtectedFooterText {
            return last
        }
        return "No sets protected yet"
    }

    private func iconName(for state: LiveProtectionState) -> String {
        switch state {
        case .noSource: return "shield"
        case .detected: return "shield.lefthalf.filled"
        case .ready: return "checkmark.shield"
        case .armed, .setProtected: return "bolt.shield"
        case .capturing: return "record.circle"
        case .saving: return "arrow.down.circle"
        case .attentionNeeded: return "exclamationmark.triangle"
        }
    }
}

#Preview("Live — armed") {
    LiveProtectionCardView()
        .environmentObject(AppModel())
        .padding()
        .background(DJToken.background)
        .preferredColorScheme(.dark)
}

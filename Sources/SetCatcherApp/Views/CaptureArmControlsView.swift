import SetCatcherCore
import SwiftUI

/// Pill arm/disarm toggle for the Capture session stack (dispatch-02).
internal struct CaptureArmToggleView: View {
    var isArmed: Bool
    var isCapturing: Bool
    var isDisabled: Bool
    var disabledHint: String? = nil
    var detail: String
    var onToggle: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 14) {
                track
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(titleColor)
                    Text(detail)
                        .font(.system(size: DJToken.TypeSize.secondary))
                        .foregroundStyle(DJToken.mutedForeground)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.55 : 1)
        .background(DJToken.elevated, in: RoundedRectangle(cornerRadius: DJToken.Radius.maximum))
        .overlay(
            RoundedRectangle(cornerRadius: DJToken.Radius.maximum)
                .stroke(DJToken.border, lineWidth: 1)
        )
        .accessibilityIdentifier("capture.armToggle")
        .accessibilityLabel(title)
        .accessibilityValue(isArmed || isCapturing ? "On" : "Off")
        .accessibilityHint(
            isDisabled
                ? (disabledHint ?? "Unavailable while Capture is busy")
                : "Arms or disarms automatic capture"
        )
    }

    private var title: String {
        if isCapturing { return "Capturing…" }
        if isArmed { return "Protection Armed" }
        return "Arm Protection"
    }

    private var titleColor: Color {
        if isCapturing { return DJToken.LiveState.capturing }
        if isArmed { return DJToken.LiveState.armed }
        return DJToken.foreground
    }

    private var track: some View {
        ZStack(alignment: (isArmed || isCapturing) ? .trailing : .leading) {
            Capsule()
                .fill(trackColor)
                .frame(width: 52, height: 28)
            Circle()
                .fill(Color.white)
                .frame(width: 22, height: 22)
                .padding(3)
        }
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.25),
            value: isArmed || isCapturing
        )
        .accessibilityHidden(true)
    }

    private var trackColor: Color {
        if isCapturing { return DJToken.LiveState.capturing }
        if isArmed { return DJToken.LiveState.armed }
        return DJToken.muted
    }
}

#Preview("Arm off") {
    CaptureArmToggleView(
        isArmed: false,
        isCapturing: false,
        isDisabled: false,
        detail: "Tap to arm protection",
        onToggle: {}
    )
    .padding()
    .frame(width: 420)
    .preferredColorScheme(.dark)
}

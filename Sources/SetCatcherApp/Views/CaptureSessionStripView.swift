import SwiftUI

/// In-progress capture strip: pulsing dot, elapsed, stop (dispatch-02).
internal struct CaptureSessionStripView: View {
    var elapsedText: String
    var sourceName: String
    var sizeText: String?
    var isSaving: Bool
    var onStop: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            PulsingCaptureDot(color: DJToken.LiveState.capturing)

            VStack(alignment: .leading, spacing: 2) {
                Text(elapsedText)
                    .font(.system(size: 20, weight: .medium, design: .monospaced))
                    .foregroundStyle(DJToken.foreground)
                    .monospacedDigit()
                    .accessibilityIdentifier("capture.strip.elapsed")
                HStack(spacing: 6) {
                    Text(isSaving ? "Saving…" : "Capturing")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DJToken.LiveState.capturing)
                    Text("·")
                        .foregroundStyle(DJToken.mutedForeground)
                    Text(sourceName)
                        .font(.system(size: 12))
                        .foregroundStyle(DJToken.mutedForeground)
                        .lineLimit(1)
                    if let sizeText {
                        Text("·")
                            .foregroundStyle(DJToken.mutedForeground)
                        Text(sizeText)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(DJToken.mutedForeground)
                            .accessibilityIdentifier("capture.strip.size")
                    }
                }
            }

            Spacer(minLength: 8)

            Button(action: onStop) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(DJToken.LiveState.capturing)
                    .frame(width: 28, height: 28)
                    .background(
                        DJToken.LiveState.capturing.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: DJToken.Radius.control)
                    )
            }
            .buttonStyle(.plain)
            .disabled(isSaving)
            .accessibilityIdentifier("capture.strip.stop")
            .accessibilityLabel("Stop capture")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            DJToken.LiveState.capturing.opacity(0.06),
            in: RoundedRectangle(cornerRadius: DJToken.Radius.maximum)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DJToken.Radius.maximum)
                .stroke(DJToken.LiveState.capturing.opacity(0.35), lineWidth: 1)
        )
        .accessibilityIdentifier("capture.strip")
    }
}

private struct PulsingCaptureDot: View {
    var color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var on = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .opacity(reduceMotion ? 1 : (on ? 1 : 0.35))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                    on = true
                }
            }
    }
}

#Preview("Strip") {
    CaptureSessionStripView(
        elapsedText: "01:23:45",
        sourceName: "Serato DJ Pro",
        sizeText: "128.4 MB",
        isSaving: false,
        onStop: {}
    )
    .padding()
    .frame(width: 420)
    .preferredColorScheme(.dark)
}

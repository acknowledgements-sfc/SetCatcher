import SwiftUI

struct WaveformScrubber: View {
    let seed: String
    let tint: Color
    let progress: Double
    let duration: TimeInterval
    let onSeek: (Double) -> Void

    var body: some View {
        GeometryReader { geometry in
            Waveform(
                seed: seed,
                barCount: 52,
                tint: tint,
                progress: clampedProgress,
                spacing: 1
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard geometry.size.width > 0 else { return }
                        onSeek(min(1, max(0, value.location.x / geometry.size.width)))
                    }
            )
        }
        .frame(height: 38)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Playback position")
        .accessibilityValue(accessibilityValue)
        .accessibilityAdjustableAction { direction in
            let step = duration > 0 ? min(1, 5 / duration) : 0
            switch direction {
            case .increment:
                onSeek(min(1, clampedProgress + step))
            case .decrement:
                onSeek(max(0, clampedProgress - step))
            @unknown default:
                break
            }
        }
    }

    private var clampedProgress: Double {
        min(1, max(0, progress))
    }

    private var accessibilityValue: String {
        guard duration > 0 else { return "Not loaded" }
        return "\(Int((clampedProgress * 100).rounded())) percent"
    }
}

#Preview("Waveform scrubber") {
    WaveformScrubber(
        seed: "Set.wav",
        tint: DJToken.primary,
        progress: 0.42,
        duration: 3_600,
        onSeek: { _ in }
    )
    .padding()
    .frame(width: 320)
    .background(DJToken.card)
}

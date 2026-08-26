import SwiftUI

/// Vertical bar waveform — the redesign's signature motif. Amplitudes are deterministic
/// per `seed` (stylized, not audio-derived — see plan: real peaks are a later follow-up).
///
/// Supports solid or vertical-gradient fill, a `litFraction` "build" state (onboarding),
/// `progress` playback shading, and an optional slow breathe. Bars centre on a shared
/// baseline, so a plain instance already reads as a mirrored, centre-out waveform.
struct Waveform: View {
    let seed: String
    var barCount: Int = 64
    var tint: Color = DJToken.primary
    /// When set, lit bars fill with a top→bottom gradient instead of `tint`.
    var gradient: (top: Color, bottom: Color)? = nil
    var progress: Double? = nil
    /// Fraction of bars (0…1) rendered "lit"; the remainder render dim/pending.
    var litFraction: Double? = nil
    /// Slow opacity breathe (0.55↔1). Disabled automatically under Reduce Motion.
    var breathing: Bool = false
    var cornerRadius: CGFloat = 1
    var spacing: CGFloat = 2

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathePhase = false

    private var clampedBarCount: Int { min(120, max(18, barCount)) }

    private var bars: [CGFloat] {
        Self.seededAmplitudes(seed: seed, count: clampedBarCount)
    }

    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .center, spacing: spacing) {
                ForEach(0..<clampedBarCount, id: \.self) { index in
                    bar(index: index, height: geo.size.height)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .opacity(breathingOpacity)
        .onAppear {
            guard breathing, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                breathePhase = true
            }
        }
        .accessibilityHidden(true)
    }

    private var breathingOpacity: Double {
        guard breathing, !reduceMotion else { return 1 }
        return breathePhase ? 1 : 0.55
    }

    @ViewBuilder
    private func bar(index: Int, height: CGFloat) -> some View {
        let amplitude = bars[index]
        let fraction = Double(index) / Double(clampedBarCount)
        let lit: Bool = litFraction.map { fraction < $0 } ?? true
        let played: Bool = progress.map { fraction <= $0 } ?? true
        let opacity: Double = {
            if litFraction != nil { return lit ? 1 : 0.28 }
            if progress == nil { return 0.28 + Double(amplitude) * 0.5 }
            return played ? 0.9 : 0.22
        }()

        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(fill(lit: lit, opacity: opacity))
            .frame(height: max(2, height * amplitude))
    }

    private func fill(lit: Bool, opacity: Double) -> AnyShapeStyle {
        if let gradient, lit {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [gradient.top, gradient.bottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .opacity(opacity)
            )
        }
        return AnyShapeStyle(tint.opacity(opacity))
    }

    /// Deterministic FNV-1a + xorshift amplitudes in 0.18…1.0 (ported from prototype `ui.tsx`
    /// and matching the "Bold Directions" design file's `wave()` seed function).
    static func seededAmplitudes(seed: String, count: Int) -> [CGFloat] {
        var hash: UInt32 = 2_166_136_261
        for unit in seed.utf8 {
            hash ^= UInt32(unit)
            hash = hash &* 16_777_619
        }

        var bars: [CGFloat] = []
        bars.reserveCapacity(count)
        for index in 0..<count {
            hash ^= hash << 13
            hash ^= hash >> 17
            hash ^= hash << 5
            let noise = CGFloat(abs(Int32(bitPattern: hash) % 1000)) / 1000
            let envelope = 0.55 + 0.45 * sin((CGFloat(index) / CGFloat(count)) * .pi)
            bars.append(0.18 + noise * 0.82 * envelope)
        }
        return bars
    }
}

/// Live capture waveform: bars react to the current input `level` with a gentle shimmer,
/// driving the immersive recording moment (design `1b`). Falls back to a static,
/// level-scaled row under Reduce Motion.
struct LiveWaveform: View {
    var level: Double
    var barCount: Int = 96
    var gradient: (top: Color, bottom: Color) = (DJToken.recordRedBright, DJToken.recordRed)
    var seed: String = "live-capture-immersive"

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var amps: [CGFloat] { Waveform.seededAmplitudes(seed: seed, count: barCount) }
    private var envelope: CGFloat { CGFloat(0.22 + min(1, max(0, level)) * 0.9) }

    var body: some View {
        if reduceMotion {
            row(shimmerAt: nil)
        } else {
            TimelineView(.animation) { context in
                row(shimmerAt: context.date.timeIntervalSinceReferenceDate)
            }
        }
    }

    private func row(shimmerAt phase: TimeInterval?) -> some View {
        GeometryReader { geo in
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<barCount, id: \.self) { index in
                    let shimmer: CGFloat = phase.map {
                        0.6 + 0.4 * (0.5 + 0.5 * CGFloat(sin($0 * 3 + Double(index) * 0.45)))
                    } ?? 1
                    let height = max(2, geo.size.height * amps[index] * envelope * shimmer)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [gradient.top, gradient.bottom],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: height)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .accessibilityHidden(true)
    }
}

#Preview("Waveform") {
    VStack(spacing: 16) {
        Waveform(
            seed: "protected-status",
            barCount: 88,
            gradient: (DJToken.signalGreenBright, DJToken.signalGreenDeep),
            breathing: true
        )
        .frame(height: 90)

        Waveform(
            seed: "onboarding-build",
            barCount: 72,
            gradient: (DJToken.warmGold, DJToken.warmGold.opacity(0.7)),
            litFraction: 0.42
        )
        .frame(height: 70)

        LiveWaveform(level: 0.7)
            .frame(height: 120)
    }
    .padding()
    .frame(width: 480)
    .background(DJToken.Ground.base)
}

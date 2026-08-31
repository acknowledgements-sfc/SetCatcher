import SetCatcherCore
import SwiftUI

/// Shared dB-scaled input meter with peak hold for Capture, Live, and menu bar.
internal struct CaptureLevelMeterView: View {
    var level: Float
    var accessibilityID: String = "capture.levelMeter"
    var showsScaleMarks: Bool = true
    /// 4px fill-only bar for the menu bar dropdown.
    var compact: Bool = false

    @State private var peakFraction: CGFloat = 0
    @State private var peakClearTask: Task<Void, Never>?

    private static let peakHoldNanos: UInt64 = 1_500_000_000

    var body: some View {
        Group {
            if compact {
                compactBar
            } else {
                labeledMeter
            }
        }
        .onChange(of: level) { _, newValue in
            updatePeak(for: newValue)
        }
        .onAppear {
            updatePeak(for: level)
        }
        .onDisappear {
            peakClearTask?.cancel()
        }
    }

    private var compactBar: some View {
        GeometryReader { geo in
            let fill = CGFloat(CaptureLevelScale.meterFraction(forInputLevel: level))
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: DJToken.Radius.swatch)
                    .fill(DJToken.muted)
                RoundedRectangle(cornerRadius: DJToken.Radius.swatch)
                    .fill(meterGradient)
                    .frame(width: max(2, geo.size.width * fill))
            }
        }
        .frame(height: 4)
        .accessibilityIdentifier(accessibilityID)
        .accessibilityLabel("Input level")
        .accessibilityValue(dbLabel)
    }

    private var labeledMeter: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("INPUT LEVEL")
                    .font(.system(size: DJToken.TypeSize.micro, weight: .medium).monospaced())
                    .foregroundStyle(DJToken.mutedForeground)
                Spacer(minLength: 8)
                if showsScaleMarks {
                    Text("−60 · −40 · −20 · −12 · 0")
                        .font(.system(size: DJToken.TypeSize.micro).monospaced())
                        .foregroundStyle(DJToken.mutedForeground)
                }
                Text(dbLabel)
                    .font(.system(size: DJToken.TypeSize.micro, weight: .medium).monospacedDigit())
                    .foregroundStyle(DJToken.foreground)
                    .accessibilityIdentifier("\(accessibilityID).db")
            }

            GeometryReader { geo in
                let fill = CGFloat(CaptureLevelScale.meterFraction(forInputLevel: level))
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: DJToken.Radius.control)
                        .fill(DJToken.muted)
                    RoundedRectangle(cornerRadius: DJToken.Radius.control)
                        .fill(meterGradient)
                        .frame(width: max(4, geo.size.width * fill))
                    Rectangle()
                        .fill(DJToken.LiveState.armed)
                        .frame(width: 2, height: geo.size.height)
                        .offset(x: max(0, geo.size.width * peakFraction - 1))
                }
            }
            .frame(height: 10)
            .accessibilityIdentifier(accessibilityID)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Input level")
        .accessibilityValue(dbLabel)
    }

    private var dbLabel: String {
        let db = CaptureLevelScale.dbFS(forInputLevel: level)
        if level <= 0.0001 { return "— dB" }
        return String(format: "%.0f dB", db)
    }

    private var meterGradient: LinearGradient {
        LinearGradient(
            colors: [DJToken.LiveState.ready, DJToken.LiveState.armed],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func updatePeak(for newLevel: Float) {
        let fraction = CGFloat(CaptureLevelScale.meterFraction(forInputLevel: newLevel))
        if fraction >= peakFraction {
            peakFraction = fraction
            peakClearTask?.cancel()
            peakClearTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: Self.peakHoldNanos)
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.35)) {
                    peakFraction = CGFloat(CaptureLevelScale.meterFraction(forInputLevel: level))
                }
            }
        }
    }
}

#Preview("Meter") {
    CaptureLevelMeterView(level: 0.35)
        .padding()
        .frame(width: 360)
        .background(DJToken.background)
        .preferredColorScheme(.dark)
}

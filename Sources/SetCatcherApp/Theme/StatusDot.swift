import SwiftUI

struct StatusDot: View {
    let tone: StatusTone
    var pulse: Bool = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.55, paused: !pulse)) { context in
            let blinkOn = !pulse || Int(context.date.timeIntervalSinceReferenceDate / 0.55) % 2 == 0
            Circle()
                .fill(tone.color)
                .frame(width: 6, height: 6)
                .opacity(blinkOn ? 1 : 0.35)
        }
        .frame(width: 8, height: 8)
        .accessibilityHidden(true)
    }
}

#Preview("StatusDot tones") {
    HStack(spacing: 12) {
        StatusDot(tone: .ok)
        StatusDot(tone: .warn)
        StatusDot(tone: .danger)
        StatusDot(tone: .info, pulse: true)
        StatusDot(tone: .neutral)
    }
    .padding()
}

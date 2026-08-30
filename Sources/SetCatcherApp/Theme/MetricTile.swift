import SwiftUI

struct MetricTile: View {
    let label: String
    let value: String
    var meta: String?
    var tone: StatusTone = .neutral

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .microLabelStyle()
            Text(value)
                .font(.system(size: DJToken.TypeSize.metric, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(tone == .neutral ? DJToken.foreground : tone.color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let meta {
                Text(meta)
                    .font(.system(size: DJToken.TypeSize.secondary))
                    .foregroundStyle(DJToken.mutedForeground)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(DJToken.card, in: RoundedRectangle(cornerRadius: DJToken.Radius.control))
        .overlay(
            RoundedRectangle(cornerRadius: DJToken.Radius.control)
                .stroke(DJToken.border, lineWidth: 1)
        )
        .help("\(label): \(value)")
    }
}

#Preview("MetricTile") {
    HStack(spacing: 8) {
        MetricTile(label: "Protected Sources", value: "3", tone: .ok)
        MetricTile(label: "Archived Sets", value: "42", meta: "12 this month")
        MetricTile(label: "Unmatched", value: "4", tone: .warn)
    }
    .padding()
    .frame(width: 480)
    .background(DJToken.content)
}

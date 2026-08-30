import SwiftUI

struct StatusTile: View {
    let title: String
    let value: String
    let symbol: String
    var tone: StatusTone = .neutral

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(.system(size: DJToken.TypeSize.secondary))
                .foregroundStyle(DJToken.mutedForeground)
            Text(value)
                .font(.system(size: DJToken.TypeSize.title, weight: .medium))
                .foregroundStyle(tone == .neutral ? DJToken.foreground : tone.color)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .padding(14)
        .background(DJToken.card, in: RoundedRectangle(cornerRadius: DJToken.Radius.control))
        .overlay(
            RoundedRectangle(cornerRadius: DJToken.Radius.control)
                .stroke(DJToken.border, lineWidth: 1)
        )
        .help("\(title): \(value)")
    }
}

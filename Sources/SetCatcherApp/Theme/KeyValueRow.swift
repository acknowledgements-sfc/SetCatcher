import SwiftUI

struct KeyValueRow: View {
    let key: String
    let value: String
    var mono: Bool = false
    var showsDivider: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text(key)
                    .font(.system(size: DJToken.TypeSize.body))
                    .foregroundStyle(DJToken.mutedForeground)
                Spacer(minLength: 8)
                Text(value)
                    .font(
                        mono
                            ? .system(size: DJToken.TypeSize.secondary, design: .monospaced)
                            : .system(size: DJToken.TypeSize.body)
                    )
                    .foregroundStyle(DJToken.foreground)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
                    .truncationMode(mono ? .head : .tail)
                    .help(value)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            if showsDivider {
                Rectangle()
                    .fill(DJToken.hairline)
                    .frame(height: 1)
            }
        }
    }
}

#Preview("KeyValueRow") {
    Panel(title: "Facts") {
        KeyValueRow(key: "Duration", value: "1h 12m")
        KeyValueRow(key: "Tracks", value: "28")
        KeyValueRow(key: "Archive", value: "/Users/dj/Archives/set.wav", mono: true, showsDivider: false)
    }
    .padding()
    .frame(width: 360)
    .background(DJToken.content)
}

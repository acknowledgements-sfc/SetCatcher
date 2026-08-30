import SwiftUI

struct SettingsStatusRow: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .frame(width: 18)
                .foregroundStyle(DJToken.mutedForeground)
            Text(title)
                .font(.system(size: DJToken.TypeSize.body, weight: .medium))
                .foregroundStyle(DJToken.foreground)
            Spacer()
            Text(value)
                .font(.system(size: DJToken.TypeSize.body))
                .foregroundStyle(DJToken.mutedForeground)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(value)
        }
        .padding(12)
        .background(DJToken.card, in: RoundedRectangle(cornerRadius: DJToken.Radius.control))
        .overlay(
            RoundedRectangle(cornerRadius: DJToken.Radius.control)
                .stroke(DJToken.border, lineWidth: 1)
        )
        .help("\(title): \(value)")
    }
}

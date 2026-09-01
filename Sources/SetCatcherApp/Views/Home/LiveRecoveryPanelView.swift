import SetCatcherCore
import SwiftUI

/// Inline recovery panel under the Live card when attention is needed (dispatch-04).
internal struct LiveRecoveryPanelView: View {
    let event: AttentionEvent
    var onPrimary: () -> Void
    var onSecondary: ((String) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(event.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DJToken.LiveState.attention)

            Text(event.body)
                .font(.system(size: DJToken.TypeSize.body, weight: .medium))
                .foregroundStyle(DJToken.foreground)
                .fixedSize(horizontal: false, vertical: true)

            if let warning = event.warning {
                Text(warning)
                    .font(.system(size: DJToken.TypeSize.secondary))
                    .foregroundStyle(DJToken.warn)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(event.reassurance)
                .font(.system(size: DJToken.TypeSize.secondary))
                .foregroundStyle(DJToken.mutedForeground)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button(event.primaryActionTitle, action: onPrimary)
                    .buttonStyle(DJPrimaryButtonStyle())
                    .accessibilityIdentifier("home.recovery.primary")

                ForEach(event.secondaryActionTitles, id: \.self) { title in
                    Button(title) { onSecondary?(title) }
                        .accessibilityIdentifier("home.recovery.secondary.\(slug(title))")
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DJToken.LiveState.attention.opacity(0.08), in: RoundedRectangle(cornerRadius: DJToken.Radius.maximum))
        .overlay(
            RoundedRectangle(cornerRadius: DJToken.Radius.maximum)
                .stroke(DJToken.LiveState.attention.opacity(0.35), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.recoveryPanel")
    }

    private func slug(_ title: String) -> String {
        title.lowercased()
            .replacingOccurrences(of: "…", with: "")
            .replacingOccurrences(of: " ", with: "")
    }
}

#Preview("Recovery — folder missing") {
    LiveRecoveryPanelView(
        event: .folderMissing(appID: "serato", appName: "Serato DJ Pro", path: "/Music/DJ Sets"),
        onPrimary: {}
    )
    .padding()
    .frame(width: 420)
    .background(DJToken.background)
    .preferredColorScheme(.dark)
}

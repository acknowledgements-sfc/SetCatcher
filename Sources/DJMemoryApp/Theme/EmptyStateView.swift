import SwiftUI

struct EmptyStateView: View {
    let title: String
    let systemImage: String
    let description: String
    var primaryTitle: String?
    var primaryAction: (() -> Void)?
    var secondaryTitle: String?
    var secondaryAction: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(DJToken.mutedForeground)
                .frame(width: 36, height: 36)
                .background(DJToken.muted.opacity(0.7), in: RoundedRectangle(cornerRadius: DJToken.Radius.control))
                .overlay(
                    RoundedRectangle(cornerRadius: DJToken.Radius.control)
                        .stroke(DJToken.border, lineWidth: 1)
                )

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DJToken.foreground)

            Text(description)
                .font(.system(size: DJToken.TypeSize.body))
                .foregroundStyle(DJToken.mutedForeground)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)

            if primaryTitle != nil || secondaryTitle != nil {
                HStack(spacing: 8) {
                    if let secondaryTitle, let secondaryAction {
                        Button(secondaryTitle, action: secondaryAction)
                            .buttonStyle(DJGhostButtonStyle())
                    }
                    if let primaryTitle, let primaryAction {
                        Button(primaryTitle, action: primaryAction)
                            .buttonStyle(DJPrimaryButtonStyle())
                    }
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 180)
        .padding(.horizontal, 32)
        .padding(.vertical, 40)
    }
}

#Preview("EmptyStateView") {
    EmptyStateView(
        title: "No archived sets yet",
        systemImage: "archivebox",
        description: "Once SetCatcher archives a recording, it will show up here.",
        primaryTitle: "Open Protection",
        primaryAction: {},
        secondaryTitle: "Browse DJ apps",
        secondaryAction: {}
    )
    .background(DJToken.content)
}

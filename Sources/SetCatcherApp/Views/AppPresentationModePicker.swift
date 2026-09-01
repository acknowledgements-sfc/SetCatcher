import SetCatcherCore
import SwiftUI

/// Shared three-way picker for menu bar / main window presentation (Settings + onboarding).
internal struct AppPresentationModePicker: View {
    @Binding var selection: AppPresentationMode
    var accessibilityPrefix: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How SetCatcher appears")
                .font(.system(size: DJToken.TypeSize.body, weight: .semibold))
                .foregroundStyle(DJToken.foreground)

            Text("Choose menu bar only, main window only, or both. You can change this later in Settings.")
                .font(.system(size: DJToken.TypeSize.secondary))
                .foregroundStyle(DJToken.mutedForeground)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(AppPresentationMode.allCases, id: \.self) { mode in
                    modeRow(mode)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("\(accessibilityPrefix).appPresentationMode")
        }
    }

    private func modeRow(_ mode: AppPresentationMode) -> some View {
        let selected = selection == mode
        return Button {
            selection = mode
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(selected ? DJToken.primary : DJToken.mutedForeground)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.title)
                        .font(.system(size: DJToken.TypeSize.body, weight: .medium))
                        .foregroundStyle(DJToken.foreground)
                    Text(mode.explanation)
                        .font(.system(size: DJToken.TypeSize.secondary))
                        .foregroundStyle(DJToken.mutedForeground)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                selected ? DJToken.primary.opacity(0.10) : DJToken.elevated,
                in: RoundedRectangle(cornerRadius: DJToken.Radius.control)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DJToken.Radius.control)
                    .stroke(selected ? DJToken.primary.opacity(0.45) : DJToken.border, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(rowAccessibilityID(for: mode))
        .accessibilityLabel(mode.title)
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func rowAccessibilityID(for mode: AppPresentationMode) -> String {
        // Preserve the former Settings toggle id on the menu-bar-only option.
        if accessibilityPrefix == "settings", mode == .menuBarOnly {
            return "settings.menuBarOnly"
        }
        return "\(accessibilityPrefix).appPresentationMode.\(mode.rawValue)"
    }
}

#Preview("Presentation picker") {
    AppPresentationModePicker(
        selection: .constant(.menuBarAndMainWindow),
        accessibilityPrefix: "settings"
    )
    .padding()
    .frame(width: 420)
    .background(DJToken.background)
    .preferredColorScheme(.dark)
}

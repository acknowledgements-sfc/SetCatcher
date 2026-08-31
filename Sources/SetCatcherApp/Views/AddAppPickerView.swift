import SwiftUI
import SetCatcherCore

struct AddAppPickerView: View {
    let options: [SoftwareProbeResult]
    let onPick: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Add a DJ app")
                .microLabelStyle()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(DJToken.muted.opacity(0.6))

            if options.isEmpty {
                Text("Every supported DJ app is already set up.")
                    .font(.system(size: DJToken.TypeSize.secondary))
                    .foregroundStyle(DJToken.mutedForeground)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(options.enumerated()), id: \.element.software.id) { index, result in
                        Button {
                            onPick(result.software.id)
                        } label: {
                            HStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: DJToken.Radius.swatch)
                                    .fill(DJToken.accent(forAppID: result.software.id))
                                    .frame(width: 3, height: 14)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(result.software.displayName)
                                        .font(.system(size: DJToken.TypeSize.body, weight: .medium))
                                        .foregroundStyle(DJToken.foreground)
                                        .lineLimit(1)

                                    if result.installedApplicationURLs.isEmpty {
                                        Text("Not installed on this Mac")
                                            .font(.system(size: DJToken.TypeSize.micro))
                                            .foregroundStyle(DJToken.mutedForeground)
                                    }
                                }

                                Spacer(minLength: 0)

                                SupportBadge(status: result.software.supportStatus)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("sidebar.addApp.\(result.software.id)")

                        if index < options.count - 1 {
                            Rectangle()
                                .fill(DJToken.hairline)
                                .frame(height: 1)
                        }
                    }
                }
            }

            Rectangle()
                .fill(DJToken.hairline)
                .frame(height: 1)

            Text(footerLine)
                .font(.system(size: DJToken.TypeSize.micro))
                .foregroundStyle(DJToken.mutedForeground)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
        }
        .background(DJToken.elevated)
    }

    private var footerLine: String {
        let hasAnalog = options.contains { $0.software.id == SupportedDJSoftware.analogMixerAppID }
        if hasAnalog {
            return "DJ apps: choose a recordings folder. Analog Mixer: pin rec-out or grant a dump folder. Nothing is uploaded."
        }
        return "Setting one up means choosing its recordings folder. Nothing is uploaded."
    }
}

#Preview("Add-app picker — options available / light") {
    AddAppPickerView(
        options: SoftwareProbe().probeAll().filter { $0.software.id != "serato" },
        onPick: { _ in }
    )
    .frame(width: 280)
    .preferredColorScheme(.light)
}

#Preview("Add-app picker — options available / dark") {
    AddAppPickerView(
        options: SoftwareProbe().probeAll().filter { $0.software.id != "serato" },
        onPick: { _ in }
    )
    .frame(width: 280)
    .preferredColorScheme(.dark)
}

#Preview("Add-app picker — all apps configured / light") {
    AddAppPickerView(options: [], onPick: { _ in })
        .frame(width: 280)
        .preferredColorScheme(.light)
}

#Preview("Add-app picker — all apps configured / dark") {
    AddAppPickerView(options: [], onPick: { _ in })
        .frame(width: 280)
        .preferredColorScheme(.dark)
}

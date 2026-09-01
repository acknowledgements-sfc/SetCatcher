import SwiftUI
import SetCatcherCore

struct HeaderView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: model.cockpitSymbolName)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(HomeFormatting.liveTone(model.cockpitSnapshot.state).color)

            VStack(alignment: .leading, spacing: 4) {
                Text("Protection status")
                    .microLabelStyle()
                Text(model.cockpitHeadline)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(DJToken.foreground)
                Text(model.cockpitStatusDetail)
                    .font(.system(size: DJToken.TypeSize.body))
                    .foregroundStyle(DJToken.mutedForeground)
                    .help(model.cockpitStatusDetail)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("Archive")
                    .font(.system(size: DJToken.TypeSize.secondary))
                    .foregroundStyle(DJToken.mutedForeground)
                HStack(spacing: 8) {
                    PathChip(path: model.archiveRoot.path)
                        .frame(maxWidth: 280)

                    Button {
                        model.openArchiveFolder()
                    } label: {
                        Label("Open", systemImage: "folder")
                    }
                    .buttonStyle(DJSecondaryButtonStyle())
                    .help("Open the SetCatcher archive folder in Finder.")
                    .accessibilityIdentifier("header.openArchiveFolder")
                }
            }
        }
    }
}

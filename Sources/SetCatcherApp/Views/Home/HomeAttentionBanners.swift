import SwiftUI
import SetCatcherCore

struct HomeAttentionBanners: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ForEach(model.unreachableRecordingAccesses(), id: \.id) { access in
            Panel(tone: .danger, padding: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(DJToken.danger)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(model.displayName(for: access.appID)) folder is unavailable")
                            .font(.system(size: DJToken.TypeSize.body, weight: .semibold))
                        PathChip(path: access.url.path, tone: .danger)
                        Text("The drive may be unplugged.")
                            .font(.system(size: DJToken.TypeSize.secondary))
                            .foregroundStyle(DJToken.mutedForeground)
                    }
                    Spacer()
                    Button("Fix Folder") {
                        model.selectedRoute = .recovery(access.appID)
                    }
                    .buttonStyle(DJPrimaryButtonStyle())
                    .accessibilityIdentifier("home.fix.\(access.appID)")
                }
            }
        }
    }
}

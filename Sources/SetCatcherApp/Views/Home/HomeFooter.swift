import SwiftUI
import SetCatcherCore

struct HomeFooter: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack {
            Spacer()
            if model.protectionState == .protected {
                Image(systemName: "checkmark.shield.fill").foregroundStyle(DJToken.ok)
            }
            Text("Audio files and full tracklists stay on this Mac. Nothing is uploaded.")
                .font(.system(size: DJToken.TypeSize.secondary))
                .foregroundStyle(DJToken.mutedForeground)
            Spacer()
        }
        .padding(.top, 8)
    }
}

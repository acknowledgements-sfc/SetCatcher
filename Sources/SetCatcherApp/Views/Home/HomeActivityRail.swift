import SwiftUI
import SetCatcherCore

struct HomeActivityRail: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Panel(
            title: "Latest activity",
            padding: 0,
            headerActions: {
                Button("All activity") { model.selectedRoute = .activity }
                    .buttonStyle(DJGhostButtonStyle())
            }
        ) {
            ForEach(model.activityEvents.prefix(5)) { event in
                HStack(spacing: 8) {
                    StatusDot(tone: event.kind == .error ? .danger : .neutral)
                    Text(event.message)
                        .font(.system(size: DJToken.TypeSize.body))
                        .lineLimit(1)
                    Spacer()
                    Text(event.createdAt, style: .time)
                        .font(.system(size: DJToken.TypeSize.secondary, design: .monospaced))
                        .foregroundStyle(DJToken.mutedForeground)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(event.kind == .error ? DJToken.danger.opacity(0.06) : Color.clear)
            }
        }
    }
}

import SwiftUI
import SetCatcherCore

struct HomeTagsPanel: View {
    @EnvironmentObject private var model: AppModel
    @State private var hoveredTag: String?

    var body: some View {
        Panel(title: "Your tags", padding: 12) {
            Text("From set details you wrote.")
                .font(.system(size: DJToken.TypeSize.secondary))
                .foregroundStyle(DJToken.mutedForeground)

            if model.tagCounts.isEmpty {
                EmptyStateView(
                    title: "No tags yet",
                    systemImage: "tag",
                    description: "Tags you add on archived sets will collect here.",
                    primaryTitle: "Open Library",
                    primaryAction: { model.openLibrary() }
                )
                .frame(minHeight: 120)
                .padding(.vertical, -8)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 72), spacing: 6, alignment: .leading)],
                    alignment: .leading,
                    spacing: 6
                ) {
                    ForEach(Array(model.tagCounts.prefix(12)), id: \.display) { tag in
                        Button {
                            model.openLibrary(search: tag.display)
                        } label: {
                            Badge(title: "\(tag.display) · \(tag.count)", tone: .neutral)
                                .opacity(hoveredTag == tag.display ? 1 : 0.92)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DJToken.Radius.badge)
                                        .stroke(
                                            hoveredTag == tag.display ? DJToken.primary.opacity(0.45) : Color.clear,
                                            lineWidth: 1
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                        .onHover { hovering in
                            hoveredTag = hovering ? tag.display : (hoveredTag == tag.display ? nil : hoveredTag)
                        }
                        .accessibilityIdentifier("home.tag.\(tag.display)")
                    }
                }
            }
        }
    }
}

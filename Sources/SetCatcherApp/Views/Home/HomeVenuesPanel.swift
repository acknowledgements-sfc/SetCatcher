import SwiftUI
import SetCatcherCore

struct HomeVenuesPanel: View {
    @EnvironmentObject private var model: AppModel
    @State private var hoveredName: String?

    var body: some View {
        Panel(title: "Where you play most", padding: 12) {
            if model.venueCounts.isEmpty {
                EmptyStateView(
                    title: "No venues yet",
                    systemImage: "mappin.and.ellipse",
                    description: "Add a venue in set details and it will show up here.",
                    primaryTitle: "Open Library",
                    primaryAction: { model.openLibrary() }
                )
                .frame(minHeight: 140)
                .padding(.vertical, -12)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                    ForEach(model.venueCounts, id: \.name) { venue in
                        Button {
                            model.openLibrary(search: venue.name)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(venue.name)
                                    .font(.system(size: DJToken.TypeSize.body, weight: .medium))
                                    .foregroundStyle(DJToken.foreground)
                                Text(venue.city)
                                    .font(.system(size: DJToken.TypeSize.secondary))
                                    .foregroundStyle(DJToken.mutedForeground)
                                Text("\(venue.setCount) sets")
                                    .font(.system(size: DJToken.TypeSize.secondary).monospacedDigit())
                                    .foregroundStyle(DJToken.mutedForeground)
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                hoveredName == venue.name ? DJToken.secondary.opacity(0.55) : DJToken.muted,
                                in: RoundedRectangle(cornerRadius: DJToken.Radius.control)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: DJToken.Radius.control)
                                    .stroke(
                                        hoveredName == venue.name ? DJToken.primary.opacity(0.45) : Color.clear,
                                        lineWidth: 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .onHover { hovering in
                            hoveredName = hovering ? venue.name : (hoveredName == venue.name ? nil : hoveredName)
                        }
                        .accessibilityIdentifier("home.venue.\(venue.name)")
                    }
                }
            }
        }
    }
}

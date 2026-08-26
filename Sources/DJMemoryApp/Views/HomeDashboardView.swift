import SwiftUI
import DJMemoryCore

struct HomeDashboardView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HomeHeroBand()
            HomeAttentionBanners()
            HStack(alignment: .top, spacing: 12) {
                HomeLastSetPanel()
                    .frame(maxWidth: .infinity)
                HomeGlanceTiles()
                    .frame(width: 296)
            }
            HomeRecentShelf()
            HStack(alignment: .top, spacing: 12) {
                HomeTopTracksPanel()
                    .frame(maxWidth: .infinity)
                HomeActivityRail()
                    .frame(width: 320)
            }
            HStack(alignment: .top, spacing: 12) {
                HomeVenuesPanel()
                    .frame(maxWidth: .infinity)
                HomeTagsPanel()
                    .frame(width: 320)
            }
            HomeFooter()
        }
        .frame(maxWidth: 1180, alignment: .leading)
        .accessibilityIdentifier("home.root")
    }
}

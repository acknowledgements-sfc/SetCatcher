import SwiftUI
import SetCatcherCore

struct HomeGlanceTiles: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let stats = model.libraryStatistics
        VStack(spacing: 8) {
            MetricTile(label: "Sets protected", value: "\(model.librarySummaries.count)", meta: "\(stats.setsThisMonth) this month", tone: .ok)
            MetricTile(
                label: "Hours archived",
                value: String(format: "%.1fh", stats.totalDurationSeconds / 3600),
                meta: ByteCountFormatter.string(fromByteCount: stats.totalFileSize, countStyle: .file)
            )
            MetricTile(
                label: "Sources watched",
                value: "\(model.protectedAdapterCount)/\(model.probeResults.count)",
                tone: model.protectionState == .attentionNeeded ? .danger : .neutral
            )
            MetricTile(
                label: "Unmatched sets",
                value: "\(stats.unmatchedCount)",
                tone: stats.unmatchedCount > 0 ? .warn : .neutral
            )
        }
    }
}

import SwiftUI

struct ProtectionMetric: View {
    let title: String
    let value: String
    var meta: String? = nil
    var tone: StatusTone = .neutral

    var body: some View {
        MetricTile(label: title, value: value, meta: meta, tone: tone)
    }
}

import SwiftUI

struct OnboardingMetric: View {
    let title: String
    let value: String
    var tone: StatusTone = .neutral

    var body: some View {
        MetricTile(label: title, value: value, tone: tone)
    }
}

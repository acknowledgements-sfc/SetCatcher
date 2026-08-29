import SwiftUI

struct OnboardingTopBar: View {
    let stepTitles: [String]
    let currentIndex: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 11) {
                EQGlyph()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(DJToken.primary)
                Text("SetCatcher")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DJToken.foreground)
                Spacer()
            }

            HStack(spacing: 0) {
                ForEach(Array(stepTitles.enumerated()), id: \.offset) { index, title in
                    if index > 0 {
                        Rectangle()
                            .fill(DJToken.border)
                            .frame(height: 1)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 4)
                    }
                    stepMark(index: index, title: title)
                }
            }
        }
    }

    @ViewBuilder
    private func stepMark(index: Int, title: String) -> some View {
        let completed = index < currentIndex
        let current = index == currentIndex
        VStack(spacing: 4) {
            Image(systemName: completed ? "checkmark.circle.fill" : (current ? "circle.fill" : "circle"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(completed || current ? DJToken.primary : DJToken.mutedForeground)
            Text(title)
                .font(.system(size: 9, weight: current ? .semibold : .regular))
                .foregroundStyle(current ? DJToken.foreground : DJToken.mutedForeground)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(minWidth: 52)
        .accessibilityIdentifier("onboarding.step.\(index)")
        .accessibilityLabel("\(title)\(completed ? ", completed" : (current ? ", current" : ""))")
    }
}

#Preview("Onboarding Top Bar Dark") {
    OnboardingTopBar(
        stepTitles: ["Welcome", "DJ Apps", "Folder Access", "Archive", "History", "Ready"],
        currentIndex: 2
    )
    .padding()
    .background(DJToken.background)
    .preferredColorScheme(.dark)
}

#Preview("Onboarding Top Bar Light") {
    OnboardingTopBar(
        stepTitles: ["Welcome", "DJ Apps", "Folder Access", "Archive", "History", "Ready"],
        currentIndex: 2
    )
    .padding()
    .background(DJToken.background)
    .preferredColorScheme(.light)
}

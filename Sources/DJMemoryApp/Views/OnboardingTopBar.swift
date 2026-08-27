import SwiftUI

struct OnboardingTopBar: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 11) {
            EQGlyph()
                .frame(width: 24, height: 24)
                .foregroundStyle(DJToken.primary)
            Text("DJMemory")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DJToken.foreground)
            Spacer()
            Text("Step \(currentStep) / \(totalSteps)")
                .font(.system(size: DJToken.TypeSize.secondary, weight: .semibold, design: .monospaced))
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(DJToken.primary.opacity(0.7))
        }
    }
}

#Preview("Onboarding Top Bar") {
    OnboardingTopBar(currentStep: 2, totalSteps: 6)
        .padding()
        .background(DJToken.background)
}

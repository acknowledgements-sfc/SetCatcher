import SwiftUI

/// The eyebrow + giant display headline + sub-line block shared by the three hero
/// moments (Home `1a`, Capture `1b`, Onboarding `1c`), so they read as one family.
///
/// `accentTail` renders in Georgia serif italic — the brand's single permitted moment
/// of warmth per hero headline (e.g. onboarding's "…starts to take shape.").
struct HeroHeader: View {
    var eyebrow: String
    var eyebrowColor: Color = DJToken.signalGreen
    var headline: String
    var accentTail: String? = nil
    var accentColor: Color = DJToken.warmGold
    var headlineSize: CGFloat = DJToken.TypeSize.displayHero
    var subline: String? = nil
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: alignment, spacing: 14) {
            Text(eyebrow)
                .font(.system(size: DJToken.TypeSize.eyebrow, weight: .semibold))
                .tracking(2)
                .textCase(.uppercase)
                .foregroundStyle(eyebrowColor)

            headlineText
                .tracking(-0.035 * headlineSize)
                .fixedSize(horizontal: false, vertical: true)

            if let subline {
                Text(subline)
                    .font(.system(size: 16))
                    .foregroundStyle(DJToken.mutedForeground)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
        .multilineTextAlignment(alignment == .center ? .center : .leading)
    }

    private var headlineText: Text {
        let head = Text(headline)
            .font(.system(size: headlineSize, weight: .semibold))
            .foregroundColor(DJToken.foreground)
        guard let accentTail else { return head }
        return head + Text(" \(accentTail)")
            .font(.custom("Georgia", size: headlineSize * 0.92).italic())
            .foregroundColor(accentColor)
    }
}

#Preview("HeroHeader") {
    VStack(alignment: .leading, spacing: 40) {
        HeroHeader(
            eyebrow: "Status · checked 42s ago",
            headline: "Protected.",
            subline: "3 sources watched · 42 sets archived · nothing to do."
        )
        HeroHeader(
            eyebrow: "Step 3 / 6",
            eyebrowColor: DJToken.warmGold,
            headline: "Grant one folder, and the set",
            accentTail: "starts to take shape.",
            headlineSize: DJToken.TypeSize.displayOnboarding,
            subline: "DJMemory watches each folder your DJ apps already record into."
        )
    }
    .padding(40)
    .frame(width: 780, alignment: .leading)
    .background(DJToken.Ground.home)
}

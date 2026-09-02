import SwiftUI

/// Plain-language disclosure for opt-in catalog sync (PV1 private beta policy).
struct CatalogSyncPrivacyDisclosure: View {
    let accessibilityIdentifier: String

    init(accessibilityIdentifier: String = "settings.privacyDisclosure") {
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            disclosureText(
                "Catalog sync includes event, venue, city, tags, filename, source app, dates, duration and size, device name, and technical capture details."
            )
            disclosureText(
                "Catalog sync never uploads audio, full tracklist contents, private notes, local file paths, or manual tracklist selections."
            )
            disclosureText("Remote archive backup is separate and is not available in this private beta.")
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private func disclosureText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: DJToken.TypeSize.secondary))
            .foregroundStyle(DJToken.mutedForeground)
            .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview("Catalog sync privacy / light") {
    CatalogSyncPrivacyDisclosure()
        .padding()
        .frame(width: 420)
        .background(DJToken.content)
        .preferredColorScheme(.light)
}

#Preview("Catalog sync privacy / dark") {
    CatalogSyncPrivacyDisclosure()
        .padding()
        .frame(width: 420)
        .background(DJToken.content)
        .preferredColorScheme(.dark)
}

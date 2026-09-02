import SwiftUI

/// Plain-language disclosure for opt-in catalog sync (PV1 private beta policy).
struct CompanionCatalogSyncPrivacyDisclosure: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            disclosureText(
                "Catalog sync includes event, venue, city, tags, filename, source app, dates, duration and size, device name, and technical capture details."
            )
            disclosureText(
                "Catalog sync never uploads audio, full tracklist contents, private notes, local file paths, or manual tracklist selections."
            )
            disclosureText("Archive backup is separate and only runs when explicitly enabled.")
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("companion.privacyDisclosure")
    }

    private func disclosureText(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview("Catalog sync privacy / light") {
    CompanionCatalogSyncPrivacyDisclosure()
        .padding()
        .preferredColorScheme(.light)
}

#Preview("Catalog sync privacy / dark") {
    CompanionCatalogSyncPrivacyDisclosure()
        .padding()
        .preferredColorScheme(.dark)
}

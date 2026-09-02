import SwiftUI

/// Plain-language disclosure for opt-in catalog sync (PV1 private beta policy).
struct CatalogSyncPrivacyDisclosure: View {
    let accessibilityIdentifier: String

    init(accessibilityIdentifier: String = "settings.privacyDisclosure") {
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            disclosureBlock(
                title: "Syncs when catalog sync is on",
                detail: "Event, venue, city, and tags, plus filename, source app, dates, duration and size, device name, and technical capture details."
            )
            disclosureBlock(
                title: "Not included in catalog sync",
                detail: "Audio files, full tracklist contents, private notes, local file paths, and manual tracklist selections are not synced by catalog sync."
            )
            disclosureBlock(
                title: "Archive backup",
                detail: "Uploading archived audio is a separate explicit opt-in. Catalog sync alone does not upload audio."
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private func disclosureBlock(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: DJToken.TypeSize.body, weight: .medium))
                .foregroundStyle(DJToken.foreground)
            Text(detail)
                .font(.system(size: DJToken.TypeSize.secondary))
                .foregroundStyle(DJToken.mutedForeground)
                .fixedSize(horizontal: false, vertical: true)
        }
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

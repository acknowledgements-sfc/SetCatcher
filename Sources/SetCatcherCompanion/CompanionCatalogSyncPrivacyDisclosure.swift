import SwiftUI

/// Plain-language disclosure for opt-in catalog sync (PV1 private beta policy).
struct CompanionCatalogSyncPrivacyDisclosure: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            disclosureBlock(
                title: "Syncs when catalog sync is on",
                detail: "Event, venue, city, and tags, plus filename, source app, dates, duration and size, and device name."
            )
            disclosureBlock(
                title: "Never leaves this device",
                detail: "Audio, full tracklist contents, private notes, local file paths, and manual tracklist selections."
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("companion.privacyDisclosure")
    }

    private func disclosureBlock(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.footnote.weight(.medium))
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    CompanionCatalogSyncPrivacyDisclosure()
        .padding()
}

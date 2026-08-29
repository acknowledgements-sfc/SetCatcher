import SwiftUI
import DJMemoryCore

/// Local DJ identity editor for Home (HANDOFF-2 G7). Blank fields stay blank — no placeholders.
struct SettingsProfilePanel: View {
    @EnvironmentObject private var model: AppModel

    @State private var displayName = ""
    @State private var handle = ""
    @State private var city = ""
    @State private var residency = ""

    var body: some View {
        Panel(title: "Profile", padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Shown on Home. Leave any field blank to hide it — SetCatcher does not invent placeholders.")
                    .font(.system(size: DJToken.TypeSize.secondary))
                    .foregroundStyle(DJToken.mutedForeground)

                profileField("Display name", text: $displayName, id: "settings.profile.displayName")
                profileField("Handle", text: $handle, id: "settings.profile.handle")
                profileField("City", text: $city, id: "settings.profile.city")
                profileField("Residency", text: $residency, id: "settings.profile.residency")

                if let since = model.profile.memberSince {
                    Text("Member since \(since.formatted(date: .abbreviated, time: .omitted))")
                        .font(.system(size: DJToken.TypeSize.secondary))
                        .foregroundStyle(DJToken.mutedForeground)
                        .accessibilityIdentifier("settings.profile.memberSince")
                }
            }
        }
        .onAppear(perform: loadFromModel)
        .onChange(of: model.profile) { _, _ in
            loadFromModel()
        }
        .onChange(of: displayName) { _, _ in saveDraft() }
        .onChange(of: handle) { _, _ in saveDraft() }
        .onChange(of: city) { _, _ in saveDraft() }
        .onChange(of: residency) { _, _ in saveDraft() }
    }

    private func profileField(_ title: String, text: Binding<String>, id: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: DJToken.TypeSize.secondary, weight: .medium))
                .foregroundStyle(DJToken.mutedForeground)
            TextField(title, text: text)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel(title)
                .accessibilityIdentifier(id)
        }
    }

    private func loadFromModel() {
        displayName = model.profile.displayName ?? ""
        handle = model.profile.handle ?? ""
        city = model.profile.city ?? ""
        residency = model.profile.residency ?? ""
    }

    private func saveDraft() {
        let nextName = displayName
        let nextHandle = handle
        let nextCity = city
        let nextResidency = residency
        let current = model.profile
        let same =
            (current.displayName ?? "") == nextName
            && (current.handle ?? "") == nextHandle
            && (current.city ?? "") == nextCity
            && (current.residency ?? "") == nextResidency
        guard !same else { return }
        model.updateProfile(
            displayName: nextName,
            handle: nextHandle,
            city: nextCity,
            residency: nextResidency
        )
    }
}

#Preview("Profile empty / light") {
    SettingsProfilePanel()
        .environmentObject(AppModel())
        .padding()
        .frame(width: 560)
        .preferredColorScheme(.light)
}

#Preview("Profile filled / dark") {
    profileFilledPreview()
}

@MainActor
private func profileFilledPreview() -> some View {
    let model = AppModel()
    model.previewApplyProfile(
        DJProfile(
            displayName: "Ada Lovelace",
            handle: "@ada",
            city: "London",
            residency: "Fabric",
            memberSince: Calendar.current.date(from: DateComponents(year: 2024, month: 3, day: 1))
        )
    )
    return SettingsProfilePanel()
        .environmentObject(model)
        .padding()
        .frame(width: 560)
        .preferredColorScheme(.dark)
}

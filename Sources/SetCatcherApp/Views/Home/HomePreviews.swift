import SwiftUI
import SetCatcherCore

#Preview("Home empty / light") {
    PreviewFixtures.framedHome(PreviewFixtures.homeEmptyModel(), scheme: .light)
}

#Preview("Home empty / dark") {
    PreviewFixtures.framedHome(PreviewFixtures.homeEmptyModel(), scheme: .dark)
}

#Preview("Home greeting morning · no name / light") {
    morningNoNameHomePreview()
}

#Preview("Home greeting afternoon · name / light") {
    PreviewFixtures.framedHome(
        PreviewFixtures.homePopulatedModel(profile: DJProfile(displayName: "Ada Lovelace"), nowHour: 14),
        scheme: .light
    )
}

#Preview("Home greeting evening · name / dark") {
    PreviewFixtures.framedHome(
        PreviewFixtures.homePopulatedModel(profile: DJProfile(displayName: "Ada Lovelace"), nowHour: 20),
        scheme: .dark
    )
}

#Preview("Home identity full profile / light") {
    PreviewFixtures.framedHome(PreviewFixtures.homePopulatedModel(), scheme: .light)
}

#Preview("Home identity name only / dark") {
    PreviewFixtures.framedHome(
        PreviewFixtures.homePopulatedModel(profile: DJProfile(displayName: "Ada Lovelace")),
        scheme: .dark
    )
}

#Preview("Home identity empty profile / light") {
    PreviewFixtures.framedHome(PreviewFixtures.homeEmptyModel(), scheme: .light)
}

#Preview("Home last-set matched with note / light") {
    PreviewFixtures.framedHome(PreviewFixtures.homePopulatedModel(withNote: true, matched: true), scheme: .light)
}

#Preview("Home last-set unmatched no note / dark") {
    PreviewFixtures.framedHome(PreviewFixtures.homePopulatedModel(withNote: false, matched: false), scheme: .dark)
}

#Preview("Home last-set empty / light") {
    PreviewFixtures.framedHome(PreviewFixtures.homeEmptyModel(), scheme: .light)
}

#Preview("Home aggregates populated / light") {
    PreviewFixtures.framedHome(PreviewFixtures.homePopulatedModel(), scheme: .light)
}

#Preview("Home aggregates zero · empty top tracks / dark") {
    PreviewFixtures.framedHome(PreviewFixtures.homeEmptyModel(), scheme: .dark)
}

#Preview("Home attention banner / light") {
    homePreview { model in
        model.previewApplyConfiguredRecordingsFolders(reachableAppIDs: ["rekordbox"], unreachableAppIDs: ["serato"])
    }
    .preferredColorScheme(.light)
}

@MainActor
private func morningNoNameHomePreview() -> some View {
    let model = PreviewFixtures.homeEmptyModel()
    model.previewApplyNow(Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()))
    return PreviewFixtures.framedHome(model, scheme: .light)
}

@MainActor
private func homePreview(configure: (AppModel) -> Void = { _ in }) -> some View {
    let model = PreviewFixtures.homePopulatedModel()
    configure(model)
    return PreviewFixtures.framedHome(model, scheme: .light)
}

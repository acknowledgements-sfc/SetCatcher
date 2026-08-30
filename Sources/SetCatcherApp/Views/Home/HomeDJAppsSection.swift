import SwiftUI
import SetCatcherCore

struct HomeDJAppsSection: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Panel(title: "Your DJ apps", padding: 12) {
            VStack(spacing: 8) {
                ForEach(model.probeResults, id: \.software.id) { result in
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: DJToken.Radius.swatch)
                            .fill(DJToken.accent(forAppID: result.software.id))
                            .frame(width: 3, height: 28)
                        Text(result.software.displayName)
                            .font(.system(size: DJToken.TypeSize.body, weight: .medium))
                        SupportBadge(status: result.software.supportStatus)
                        Spacer()
                        let state = model.setupState(for: result)
                        StatusDot(tone: HomeFormatting.setupTone(state))
                        Text("\(state.displayName) · \(model.sessions.filter { $0.sourceAppID == result.software.id }.count) sets")
                            .font(.system(size: DJToken.TypeSize.secondary))
                            .foregroundStyle(DJToken.mutedForeground)
                        Button(actionLabel(for: result)) {
                            let state = model.setupState(for: result)
                            if model.isConfiguredRecordingsFolderUnreachable(appID: result.software.id)
                                || state == .error {
                                model.selectedRoute = .recovery(result.software.id)
                            } else if state == .needsFolderAccess {
                                model.selectedRoute = .app(result.software.id)
                                model.chooseFolder(appID: result.software.id, kind: .recordings)
                            } else {
                                model.selectedRoute = .app(result.software.id)
                            }
                        }
                        .buttonStyle(DJSecondaryButtonStyle())
                        .accessibilityIdentifier("home.app.\(result.software.id)")
                    }
                }
            }
        }
    }

    private func actionLabel(for result: SoftwareProbeResult) -> String {
        let state = model.setupState(for: result)
        if model.isConfiguredRecordingsFolderUnreachable(appID: result.software.id) || state == .error {
            return "Fix"
        }
        if state == .needsFolderAccess || !model.hasConfiguredRecordingsFolder(appID: result.software.id) {
            return "Set up"
        }
        return "Manage"
    }
}

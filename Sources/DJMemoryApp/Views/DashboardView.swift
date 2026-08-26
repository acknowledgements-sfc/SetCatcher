import SwiftUI
import DJMemoryCore

struct DashboardView: View {
    @EnvironmentObject private var model: AppModel
    let isAccountAuthEnabled: Bool

    init(isAccountAuthEnabled: Bool = false) {
        self.isAccountAuthEnabled = isAccountAuthEnabled
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // On Home the hero band owns the protection status, so the shared
                // header would only duplicate it — every other route keeps it.
                if model.selectedRoute != .home {
                    HeaderView()
                }

                switch model.selectedRoute {
                case .home:
                    HomeDashboardView()
                case .protection:
                    ProtectionDashboardView()
                case .capture:
                    CaptureView()
                case .library:
                    SessionLibraryView()
                case .activity:
                    ActivityLogView()
                case .settings:
                    SettingsView(isAccountAuthEnabled: isAccountAuthEnabled)
                case .app:
                    AdapterDetailView()
                case .recovery(let appID):
                    RecoveryView(appID: appID)
                }
            }
            .padding(28)
        }
        .background(DJToken.background)
    }
}

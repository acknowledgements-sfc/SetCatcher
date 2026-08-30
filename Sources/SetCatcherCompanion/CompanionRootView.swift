import SwiftUI

public struct CompanionRootView: View {
    @Bindable public var model: CompanionModel
    private let isAccountAuthEnabled: Bool

    public init(model: CompanionModel, isAccountAuthEnabled: Bool = false) {
        self.model = model
        self.isAccountAuthEnabled = isAccountAuthEnabled
    }

    public var body: some View {
        NavigationSplitView {
            List {
                ForEach(CompanionModel.Route.allCases) { route in
                    Button {
                        model.selectedRoute = route
                    } label: {
                        Label(route.title, systemImage: route.systemImage)
                    }
                    .listRowBackground(model.selectedRoute == route ? Color.accentColor.opacity(0.15) : Color.clear)
                    .accessibilityIdentifier("ipad.sidebar.\(route.rawValue)")
                }
            }
            .navigationTitle("SetCatcher")
            .safeAreaInset(edge: .bottom) {
                Text(model.statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .accessibilityIdentifier("ipad.statusMessage")
            }
        } detail: {
            switch model.selectedRoute {
            case .library:
                CompanionLibraryView(model: model)
            case .importSets:
                CompanionImportView(model: model)
            case .capture:
                CompanionCaptureView(model: model)
            case .settings:
                CompanionSettingsView(model: model, isAccountAuthEnabled: isAccountAuthEnabled)
            }
        }
    }
}

#Preview {
    CompanionRootView(model: CompanionModel())
}

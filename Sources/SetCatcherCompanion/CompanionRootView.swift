import SwiftUI

public struct CompanionRootView: View {
    @Bindable public var model: CompanionModel
    private let isAccountAuthEnabled: Bool
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    public init(model: CompanionModel, isAccountAuthEnabled: Bool = false) {
        self.model = model
        self.isAccountAuthEnabled = isAccountAuthEnabled
    }

    public var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                compactRoot
            } else {
                regularRoot
            }
        }
    }

    private var regularRoot: some View {
        NavigationSplitView {
            sidebarList
        } detail: {
            routeDetail
        }
    }

    private var compactRoot: some View {
        TabView(selection: $model.selectedRoute) {
            ForEach(CompanionModel.Route.allCases) { route in
                routeDetail(for: route)
                    .tabItem {
                        Label(route.title, systemImage: route.systemImage)
                    }
                    .tag(route)
                    .accessibilityIdentifier("ipad.sidebar.\(route.rawValue)")
            }
        }
        .safeAreaInset(edge: .bottom) {
            statusFooter
        }
    }

    private var sidebarList: some View {
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
            statusFooter
        }
    }

    private var statusFooter: some View {
        Text(model.statusMessage)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .accessibilityIdentifier("ipad.statusMessage")
    }

    @ViewBuilder
    private var routeDetail: some View {
        routeDetail(for: model.selectedRoute)
    }

    @ViewBuilder
    private func routeDetail(for route: CompanionModel.Route) -> some View {
        switch route {
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

#Preview {
    CompanionRootView(model: CompanionModel())
}

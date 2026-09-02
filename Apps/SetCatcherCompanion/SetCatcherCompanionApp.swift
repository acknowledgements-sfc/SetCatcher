import ClerkKit
import ClerkKitUI
import SwiftUI
import SetCatcherCompanion
import SetCatcherCore

@main
struct SetCatcherCompanionApp: App {
    @State private var model = CompanionModel()

    /// Stable identity for OAuth redirects / keychain. Matches Info.plist + Clerk Native Application.
    private static let appBundleID = "app.setcatcher.SetCatcher.iPad"
    private static let oauthCallbackURL = "\(appBundleID)://callback"
    private static let clerkPublishableKey = SetCatcherAccountConfiguration.clerkPublishableKey
    private static var isAccountAuthEnabled: Bool { clerkPublishableKey != nil }

    init() {
        // Optional Account auth only — local library/import never depend on Clerk.
        if let publishableKey = Self.clerkPublishableKey {
            Clerk.configure(
                publishableKey: publishableKey,
                options: .init(
                    keychainConfig: .init(service: Self.appBundleID),
                    redirectConfig: .init(
                        redirectUrl: Self.oauthCallbackURL,
                        callbackUrlScheme: Self.appBundleID
                    )
                )
            )
        }
    }

    var body: some Scene {
        WindowGroup {
            rootView
        }
    }

    private func applySettingsDeepLink(_ url: URL) {
        let host = url.host?.lowercased()
        if host == "settings" {
            model.selectedRoute = .settings
        } else if host == "library" {
            model.selectedRoute = .library
        }
    }

    private func applyLaunchRouteIfNeeded() {
        let args = ProcessInfo.processInfo.arguments
        if args.contains(where: { $0.caseInsensitiveCompare("settings") == .orderedSame || $0 == "--settings" }) {
            model.selectedRoute = .settings
        } else if args.contains(where: { $0.caseInsensitiveCompare("library") == .orderedSame || $0 == "--library" }) {
            model.selectedRoute = .library
        }
    }

    @ViewBuilder
    private var rootView: some View {
        if Self.isAccountAuthEnabled {
            CompanionRootView(model: model, isAccountAuthEnabled: true)
                // Prefetch reads @Environment(Clerk.self) — must be inside .environment(Clerk.shared).
                .prefetchClerkImages()
                .environment(Clerk.shared)
                .onAppear {
                    applyLaunchRouteIfNeeded()
                    CompanionInbox.drain(into: model)
                }
                .onOpenURL { url in
                    applySettingsDeepLink(url)
                    Task {
                        do {
                            try await Clerk.shared.handle(url)
                        } catch {
                            // Deep-link auth failures must not block local library/import.
                        }
                        CompanionInbox.drain(into: model)
                    }
                }
        } else {
            CompanionRootView(model: model, isAccountAuthEnabled: false)
                .onAppear {
                    applyLaunchRouteIfNeeded()
                    CompanionInbox.drain(into: model)
                }
                .onOpenURL { url in
                    applySettingsDeepLink(url)
                    CompanionInbox.drain(into: model)
                }
        }
    }
}

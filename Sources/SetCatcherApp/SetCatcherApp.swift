import AppKit
import ClerkKit
import ClerkKitUI
import SwiftUI
import SetCatcherCore
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if LocalNotificationService.canUseUserNotifications {
            UNUserNotificationCenter.current().delegate = self
        }

        let menuBarOnly = (try? AppSettingsStore().load())?.menuBarOnly ?? false

        if menuBarOnly {
            // Hide dock icon and suppress the WindowGroup window —
            // user reaches the app exclusively through the menu bar icon.
            NSApp.setActivationPolicy(.accessory)
            // orderOut hides the window without destroying it; close() would
            // remove it from NSApp.windows and openMainWindow() would find nothing.
            DispatchQueue.main.async {
                NSApp.windows
                    .filter { $0.canBecomeMain }
                    .forEach { $0.orderOut(nil) }
            }
        } else {
            // SPM executables don't get .regular activation policy automatically —
            // set it explicitly so the window and dock icon appear.
            NSApp.setActivationPolicy(.regular)
            AppModel.activateApp()
        }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

@main
enum SetCatcherMain {
    static func main() {
        #if os(macOS)
        let args = Array(CommandLine.arguments.dropFirst())
        if args.first == "--app-audio-probe" {
            let parsed = AppAudioProbeRunner.parseArgs(Array(args.dropFirst()))
            AppAudioProbeRunner.run(softwareID: parsed.softwareID, seconds: parsed.seconds)
            return
        }
        #endif
        SetCatcherApplication.main()
    }
}

struct SetCatcherApplication: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    /// Stable id for the main WindowGroup so `openWindow(id:)` can create/surface it on demand.
    fileprivate static let mainWindowID = "main"

    /// Stable identity for OAuth redirects / keychain. `swift run` has no Info.plist bundle id.
    private static let appBundleID = "app.setcatcher.SetCatcher"
    private static let oauthCallbackURL = "\(appBundleID)://callback"
    private static let clerkPublishableKey = SetCatcherAccountConfiguration.clerkPublishableKey
    private static var isAccountAuthEnabled: Bool { clerkPublishableKey != nil }

    init() {
        // NOTE: Do NOT touch NSApp here. `App.init()` runs before SwiftUI creates the
        // NSApplication, so the implicitly-unwrapped `NSApp` global is still nil and any
        // access crashes. Activation policy is set in AppDelegate.applicationDidFinishLaunching,
        // where NSApp is guaranteed valid.

        // Optional Account auth only — local archive/scan/protection never depend on Clerk.
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
        WindowGroup("SetCatcher", id: Self.mainWindowID) {
            rootView
                .frame(minWidth: 980, minHeight: 640)
                .modifier(RegisterOpenMainWindow(model: model))
        }
        .defaultLaunchBehavior(.presented)
        .commands {
            AppCommands(model: model)
        }

        MenuBarExtra {
            menuBarView
        } label: {
            MenuBarIconView(state: model.menuBarState)
                .equatable()
                .modifier(LaunchMainWindowOnce(model: model))
        }
        // `.window` renders the dropdown as an arbitrary SwiftUI view instead of converting
        // it to an NSMenu — required for the design handoff's custom panel chrome
        // (rounded corners, elevated background, hover rows) rather than native menu items.
        .menuBarExtraStyle(.window)
    }

    @ViewBuilder
    private var rootView: some View {
        if Self.isAccountAuthEnabled {
            ContentView(isAccountAuthEnabled: true)
                .environmentObject(model)
                // Prefetch reads @Environment(Clerk.self) — must be inside .environment(Clerk.shared).
                .prefetchClerkImages()
                .environment(Clerk.shared)
        } else {
            ContentView(isAccountAuthEnabled: false)
                .environmentObject(model)
        }
    }

    @ViewBuilder
    private var menuBarView: some View {
        if Self.isAccountAuthEnabled {
            MenuBarStatusView()
                .environmentObject(model)
                .environment(Clerk.shared)
        } else {
            MenuBarStatusView()
                .environmentObject(model)
        }
    }
}

/// Captures SwiftUI's `openWindow` action from inside the WindowGroup and hands it to
/// `AppModel`, so non-View code can surface the main window on demand (menu bar actions,
/// the menuBarOnly toggle). Registered from the window content's `.onAppear`.
private struct RegisterOpenMainWindow: ViewModifier {
    let model: AppModel
    @Environment(\.openWindow) private var openWindow

    func body(content: Content) -> some View {
        content.onAppear {
            model.requestOpenMainWindow = { openWindow(id: SetCatcherApplication.mainWindowID) }
        }
    }
}

/// Registers `openWindow` from the menu-bar extra (always instantiated at launch) and presents
/// the main window if `.defaultLaunchBehavior(.presented)` still left it closed (window restoration
/// or a race with scene setup). No-ops when `menuBarOnly` is on.
private struct LaunchMainWindowOnce: ViewModifier {
    let model: AppModel
    @Environment(\.openWindow) private var openWindow
    @State private var didRun = false

    func body(content: Content) -> some View {
        content.onAppear {
            // Register the opener so menu-bar actions can surface the window later, too.
            model.requestOpenMainWindow = { openWindow(id: SetCatcherApplication.mainWindowID) }

            guard !didRun else { return }
            didRun = true

            // Read menuBarOnly from disk (authoritative at launch; model state may not be loaded).
            let menuBarOnly = (try? AppSettingsStore().load())?.menuBarOnly ?? false
            guard !menuBarOnly else { return }

            // If the WindowGroup already came up via defaultLaunchBehavior, leave it.
            DispatchQueue.main.async {
                if !NSApp.windows.contains(where: { $0.canBecomeKey && $0.isVisible }) {
                    openWindow(id: SetCatcherApplication.mainWindowID)
                }
            }
        }
    }
}

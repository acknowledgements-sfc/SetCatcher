import AppKit
import ClerkKit
import ClerkKitUI
import SwiftUI
import DJMemoryCore
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
            NSApp.activate(ignoringOtherApps: true)
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
enum DJMemoryMain {
    static func main() {
        #if os(macOS)
        let args = Array(CommandLine.arguments.dropFirst())
        if args.first == "--app-audio-probe" {
            let parsed = AppAudioProbeRunner.parseArgs(Array(args.dropFirst()))
            AppAudioProbeRunner.run(softwareID: parsed.softwareID, seconds: parsed.seconds)
            return
        }
        #endif
        DJMemoryApplication.main()
    }
}

struct DJMemoryApplication: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    /// Stable id for the main WindowGroup so `openWindow(id:)` can create/surface it on demand.
    fileprivate static let mainWindowID = "main"

    /// Stable identity for OAuth redirects / keychain. `swift run` has no Info.plist bundle id.
    private static let appBundleID = "app.djmemory.DJMemory"
    private static let oauthCallbackURL = "\(appBundleID)://callback"
    private static let clerkPublishableKey = DJMemoryAccountConfiguration.clerkPublishableKey
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
        .commands {
            AppCommands(model: model)
        }

        MenuBarExtra {
            menuBarView
        } label: {
            // The label is instantiated at launch (the WindowGroup window is not, when a
            // MenuBarExtra is present on macOS 15+), so it's where we trigger the launch-time
            // window open. See LaunchMainWindowOnce.
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
            model.requestOpenMainWindow = { openWindow(id: DJMemoryApplication.mainWindowID) }
        }
    }
}

/// Presents the main window once at launch. Attached to the `MenuBarExtra` label because that
/// view IS created at launch, whereas on macOS 15+ the `WindowGroup` window is suppressed when a
/// `MenuBarExtra` is present (so a modifier on the window content would never run at launch).
/// Guarded to avoid opening a duplicate on OS versions / states where the window did auto-open.
private struct LaunchMainWindowOnce: ViewModifier {
    let model: AppModel
    @Environment(\.openWindow) private var openWindow
    @State private var didRun = false

    func body(content: Content) -> some View {
        content.onAppear {
            // Register the opener so menu-bar actions can surface the window later, too.
            model.requestOpenMainWindow = { openWindow(id: DJMemoryApplication.mainWindowID) }

            guard !didRun else { return }
            didRun = true

            // Read menuBarOnly from disk (authoritative at launch; model state may not be loaded).
            let menuBarOnly = (try? AppSettingsStore().load())?.menuBarOnly ?? false
            guard !menuBarOnly else { return }

            // Defer one main-actor hop so scene setup finishes, then open the main window only
            // if it didn't already come up on its own (avoids a duplicate window).
            DispatchQueue.main.async {
                if !NSApp.windows.contains(where: { $0.canBecomeKey }) {
                    openWindow(id: DJMemoryApplication.mainWindowID)
                }
            }
        }
    }
}

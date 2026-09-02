import AppKit
import ClerkKit
import ClerkKitUI
import SwiftUI
import SetCatcherCore
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var presentationMode: AppPresentationMode {
        if ProcessInfo.processInfo.environment["SETCATCHER_FORCE_MAIN_WINDOW"] == "1" {
            return .mainWindowOnly
        }
        return (try? AppSettingsStore().load())?.appPresentationMode ?? .menuBarAndMainWindow
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        applyActivationPolicyFromSettings()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if LocalNotificationService.canUseUserNotifications {
            UNUserNotificationCenter.current().delegate = self
        }

        applyActivationPolicyFromSettings()
        let mode = presentationMode
        if !mode.opensMainWindowAtLaunch {
            // orderOut hides the window without destroying it; close() would
            // remove it from NSApp.windows and openMainWindow() would find nothing.
            DispatchQueue.main.async {
                NSApp.windows
                    .filter { $0.canBecomeMain }
                    .forEach { $0.orderOut(nil) }
            }
        } else {
            AppModel.activateApp()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        applyActivationPolicyFromSettings()
        MainActor.assumeIsolated {
            AppModel.lifecycleOwner?.handleAppBecameActive()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Synchronous release so the ProcessInfo activity ends before process exit.
        // AppModel is @MainActor; terminate runs on the main thread.
        MainActor.assumeIsolated {
            AppModel.lifecycleOwner?.releaseCaptureIdleSleepAssertion()
        }
    }

    private func applyActivationPolicyFromSettings() {
        let mode = presentationMode
        if mode.usesAccessoryActivationPolicy {
            NSApp.setActivationPolicy(.accessory)
        } else {
            NSApp.setActivationPolicy(.regular)
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

/// Clerk.configure reads the keychain synchronously. Doing that in `App.init()`
/// blocked the extra from appearing; accessing `Clerk.shared` before configure
/// traps. Configure on the next main turn and keep account UI off until then.
@MainActor
final class ClerkLaunchGate: ObservableObject {
    @Published private(set) var isConfigured = false

    init(publishableKey: String?, bundleID: String, oauthCallbackURL: String) {
        guard let publishableKey else { return }
        Task { @MainActor [weak self] in
            await Task.yield()
            try? await Task.sleep(nanoseconds: 800_000_000)
            Clerk.configure(
                publishableKey: publishableKey,
                options: .init(
                    keychainConfig: .init(service: bundleID),
                    redirectConfig: .init(
                        redirectUrl: oauthCallbackURL,
                        callbackUrlScheme: bundleID
                    )
                )
            )
            self?.isConfigured = true
        }
    }
}

struct SetCatcherApplication: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()
    @StateObject private var clerkGate: ClerkLaunchGate

    /// Stable id for the main WindowGroup so `openWindow(id:)` can create/surface it on demand.
    fileprivate static let mainWindowID = "main"

    /// Stable identity for OAuth redirects / keychain. `swift run` has no Info.plist bundle id.
    private static let appBundleID = "app.setcatcher.SetCatcher"
    private static let oauthCallbackURL = "\(appBundleID)://callback"
    private static let clerkPublishableKey = SetCatcherAccountConfiguration.clerkPublishableKey
    private static var isAccountAuthEnabled: Bool { clerkPublishableKey != nil }
    private static var forceMainWindowForVerification: Bool {
        ProcessInfo.processInfo.environment["SETCATCHER_FORCE_MAIN_WINDOW"] == "1"
    }

    init() {
        // NOTE: Do NOT touch NSApp here. `App.init()` runs before SwiftUI creates the
        // NSApplication, so the implicitly-unwrapped `NSApp` global is still nil and any
        // access crashes. Activation policy is set in AppDelegate.applicationDidFinishLaunching,
        // where NSApp is guaranteed valid.
        _clerkGate = StateObject(
            wrappedValue: ClerkLaunchGate(
                publishableKey: Self.clerkPublishableKey,
                bundleID: Self.appBundleID,
                oauthCallbackURL: Self.oauthCallbackURL
            )
        )
    }

    var body: some Scene {
        WindowGroup("SetCatcher", id: Self.mainWindowID) {
            rootView
                .frame(minWidth: 980, minHeight: 640)
                .modifier(RegisterOpenMainWindow(model: model))
        }
        .defaultLaunchBehavior(
            (Self.forceMainWindowForVerification || model.settings.appPresentationMode.opensMainWindowAtLaunch)
                ? .presented
                : .automatic
        )
        .commands {
            AppCommands(model: model)
        }

        MenuBarExtra(isInserted: menuBarExtraInserted) {
            menuBarView
        } label: {
            MenuBarIconView(
                state: model.menuBarState,
                iconOpacity: model.menuBarIconOpacity,
                labelSlideProgress: model.menuBarLabelSlideProgress
            )
                .equatable()
                .onChange(of: model.menuBarState) { _, _ in
                    model.noteMenuBarPresentationChanged()
                }
                .modifier(LaunchMainWindowOnce(model: model))
        }
        // `.window` renders the dropdown as an arbitrary SwiftUI view instead of converting
        // it to an NSMenu — required for the design handoff's custom panel chrome
        // (rounded corners, elevated background, hover rows) rather than native menu items.
        .menuBarExtraStyle(.window)
    }

    /// Drives menu bar visibility for `.mainWindowOnly` without rebuilding the Scene graph.
    private var menuBarExtraInserted: Binding<Bool> {
        Binding(
            get: { model.settings.appPresentationMode.showsMenuBarExtra },
            set: { show in
                // Control-click Remove keeps Settings as the source of truth for “main window only”.
                if !show, model.settings.appPresentationMode.showsMenuBarExtra {
                    model.updateAppPresentationMode(.mainWindowOnly)
                } else if show, model.settings.appPresentationMode == .mainWindowOnly {
                    model.updateAppPresentationMode(.menuBarAndMainWindow)
                }
            }
        )
    }

    @ViewBuilder
    private var rootView: some View {
        if Self.isAccountAuthEnabled && clerkGate.isConfigured {
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
        // MenuBarStatusView never reads Clerk. Accessing `Clerk.shared` from
        // MenuBarExtra after configure traps (EXC_BREAKPOINT in Clerk.shared.getter).
        MenuBarStatusView()
            .environmentObject(model)
    }
}

/// Captures SwiftUI's `openWindow` action from inside the WindowGroup and hands it to
/// `AppModel`, so non-View code can surface the main window on demand (menu bar actions,
/// presentation-mode changes). Registered from the window content's `.onAppear`.
private struct RegisterOpenMainWindow: ViewModifier {
    let model: AppModel
    @Environment(\.openWindow) private var openWindow

    func body(content: Content) -> some View {
        content.onAppear {
            model.requestOpenMainWindow = { openWindow(id: SetCatcherApplication.mainWindowID) }
        }
    }
}

/// Registers `openWindow` from the menu-bar extra (when present) and presents
/// the main window if launch behavior still left it closed. No-ops for menu-bar-only.
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

            let mode: AppPresentationMode
            if ProcessInfo.processInfo.environment["SETCATCHER_FORCE_MAIN_WINDOW"] == "1" {
                mode = .mainWindowOnly
            } else {
                mode = (try? AppSettingsStore().load())?.appPresentationMode ?? .menuBarAndMainWindow
            }
            guard mode.opensMainWindowAtLaunch else { return }

            // If the WindowGroup already came up via defaultLaunchBehavior, leave it.
            DispatchQueue.main.async {
                if !NSApp.windows.contains(where: { $0.canBecomeKey && $0.isVisible }) {
                    openWindow(id: SetCatcherApplication.mainWindowID)
                }
            }
        }
    }
}

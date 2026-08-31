import Foundation

/// How SetCatcher presents itself after launch (Settings + onboarding).
public enum AppPresentationMode: String, Codable, Sendable, CaseIterable, Equatable {
    /// Menu bar icon and main window (default).
    case menuBarAndMainWindow
    /// Status item only; open the window from the menu bar when needed.
    case menuBarOnly
    /// Main window only; no menu bar status item.
    case mainWindowOnly

    public var showsMenuBarExtra: Bool {
        switch self {
        case .menuBarAndMainWindow, .menuBarOnly: return true
        case .mainWindowOnly: return false
        }
    }

    public var opensMainWindowAtLaunch: Bool {
        switch self {
        case .menuBarAndMainWindow, .mainWindowOnly: return true
        case .menuBarOnly: return false
        }
    }

    /// Accessory policy hides Dock; used only for menu-bar-only.
    public var usesAccessoryActivationPolicy: Bool {
        self == .menuBarOnly
    }

    public var title: String {
        switch self {
        case .menuBarAndMainWindow: return "Menu bar and main window"
        case .menuBarOnly: return "Menu bar only"
        case .mainWindowOnly: return "Main window only"
        }
    }

    public var explanation: String {
        switch self {
        case .menuBarAndMainWindow:
            return "Keep the menu bar icon and open the main window at launch."
        case .menuBarOnly:
            return "Stay in the menu bar. Open the main window any time from the icon."
        case .mainWindowOnly:
            return "Use the main window only. No menu bar status item."
        }
    }
}

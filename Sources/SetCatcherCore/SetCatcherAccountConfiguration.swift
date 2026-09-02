import Foundation

/// Shared accounts host for Mac and iPad. Same Clerk + Supabase + Vercel stack.
/// Local archive / scan / protection / import never depend on this URL being reachable.
public enum SetCatcherAccountConfiguration {
    /// Override with `SETCATCHER_ACCOUNT_URL`. Default is the Beat Revival production host.
    public static var baseURLString: String {
        ProcessInfo.processInfo.environment["SETCATCHER_ACCOUNT_URL"]
            ?? "https://beatrevival.com"
    }

    /// Optional Clerk publishable key for native Account UI.
    /// Launch env wins. Debug device builds may also bake the same key into Info.plist
    /// so an icon tap still shows Sign in. The key is never required for local archive.
    public static var clerkPublishableKey: String? {
        normalized(ProcessInfo.processInfo.environment["SETCATCHER_CLERK_PUBLISHABLE_KEY"])
            ?? normalized(Bundle.main.object(forInfoDictionaryKey: "SETCATCHER_CLERK_PUBLISHABLE_KEY") as? String)
    }

    static func normalized(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        if value.hasPrefix("$(") { return nil }
        return value
    }
}

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
    public static var clerkPublishableKey: String? {
        let value = ProcessInfo.processInfo.environment["SETCATCHER_CLERK_PUBLISHABLE_KEY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
    }
}

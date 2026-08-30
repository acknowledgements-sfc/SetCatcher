import Foundation

/// Pure helpers for keeping library table selection aligned with visible rows.
public enum LibrarySelection {
    /// Returns `current` when it is still present in `visibleIDs`; otherwise `nil`.
    public static func retainingIfPresent<ID: Hashable>(
        _ current: ID?,
        among visibleIDs: some Collection<ID>
    ) -> ID? {
        guard let current else { return nil }
        return visibleIDs.contains(current) ? current : nil
    }
}

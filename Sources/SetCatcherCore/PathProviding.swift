import Foundation

public protocol PathProviding: Sendable {
    func applicationSupportDirectory() -> URL
    func defaultArchiveRoot() -> URL
    func homeDirectory() -> URL
}

public struct DefaultPathProvider: PathProviding {
    public init() {}

    public func applicationSupportDirectory() -> URL {
        let fileManager = FileManager.default
        #if os(macOS)
        return fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("SetCatcher", isDirectory: true)
        #else
        return fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("SetCatcher", isDirectory: true)
        #endif
    }

    public func defaultArchiveRoot() -> URL {
        let fileManager = FileManager.default
        #if os(macOS)
        return fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Music", isDirectory: true)
            .appendingPathComponent("SetCatcher", isDirectory: true)
        #else
        return fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("SetCatcher", isDirectory: true)
        #endif
    }

    public func homeDirectory() -> URL {
        let fileManager = FileManager.default
        #if os(macOS)
        return fileManager.homeDirectoryForCurrentUser
        #else
        return fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        #endif
    }
}

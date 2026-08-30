import Foundation

/// Optional local DJ identity for Home (HANDOFF-2 G7). Every field is optional — never invent placeholders.
public struct DJProfile: Codable, Equatable, Sendable {
    public var displayName: String?
    public var handle: String?
    public var city: String?
    public var residency: String?
    public var memberSince: Date?

    public init(
        displayName: String? = nil,
        handle: String? = nil,
        city: String? = nil,
        residency: String? = nil,
        memberSince: Date? = nil
    ) {
        self.displayName = displayName
        self.handle = handle
        self.city = city
        self.residency = residency
        self.memberSince = memberSince
    }

    /// Initials from display name words, max 2 characters. Nil when there is no name.
    public var initials: String? {
        guard let displayName else { return nil }
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let parts = trimmed.split(whereSeparator: \.isWhitespace)
        let letters = parts.prefix(2).compactMap { $0.first.map { String($0).uppercased() } }
        let value = letters.joined()
        return value.isEmpty ? nil : value
    }

    public var firstName: String? {
        guard let displayName else { return nil }
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.split(whereSeparator: \.isWhitespace).first ?? Substring(trimmed))
    }

    private enum CodingKeys: String, CodingKey {
        case displayName, handle, city, residency, memberSince
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        handle = try container.decodeIfPresent(String.self, forKey: .handle)
        city = try container.decodeIfPresent(String.self, forKey: .city)
        residency = try container.decodeIfPresent(String.self, forKey: .residency)
        memberSince = try container.decodeIfPresent(Date.self, forKey: .memberSince)
    }
}

public struct DJProfileStore {
    public let storageURL: URL
    private let fileManager: FileManager

    public init(
        storageURL: URL = Self.defaultStorageURL(),
        fileManager: FileManager = .default
    ) {
        self.storageURL = storageURL
        self.fileManager = fileManager
    }

    public static func defaultStorageURL() -> URL {
        DefaultPathProvider().applicationSupportDirectory()
            .appendingPathComponent("profile.json")
    }

    public func load() throws -> DJProfile {
        guard fileManager.fileExists(atPath: storageURL.path) else {
            return DJProfile()
        }
        let data = try Data(contentsOf: storageURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(DJProfile.self, from: data)
    }

    public func save(_ profile: DJProfile) throws {
        try fileManager.createDirectory(
            at: storageURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(profile).write(to: storageURL, options: [.atomic])
    }
}

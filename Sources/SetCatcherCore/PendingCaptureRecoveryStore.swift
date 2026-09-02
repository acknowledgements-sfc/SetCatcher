import Foundation

public struct PendingCaptureRecoveryRecord: Codable, Equatable, Sendable {
    public let stagingURL: URL
    public let deviceID: String
    public let deviceName: String
    public let startedAt: Date
    public let endedAt: Date
    public let sourceAppID: String
    public let companionAppID: String?
    public let captureRoute: CaptureArchiveRoute
    public let captureBackend: CaptureArchiveBackend?
    public let captureDeviceTransport: String?
    public let captureInterrupted: Bool
    public let captureInterruptionReason: String?

    public init(
        stagingURL: URL,
        deviceID: String,
        deviceName: String,
        startedAt: Date,
        endedAt: Date,
        sourceAppID: String,
        companionAppID: String? = nil,
        captureRoute: CaptureArchiveRoute,
        captureBackend: CaptureArchiveBackend?,
        captureDeviceTransport: String?,
        captureInterrupted: Bool,
        captureInterruptionReason: String?
    ) {
        self.stagingURL = stagingURL
        self.deviceID = deviceID
        self.deviceName = deviceName
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.sourceAppID = sourceAppID
        self.companionAppID = companionAppID
        self.captureRoute = captureRoute
        self.captureBackend = captureBackend
        self.captureDeviceTransport = captureDeviceTransport
        self.captureInterrupted = captureInterrupted
        self.captureInterruptionReason = captureInterruptionReason
    }
}

public struct PendingCaptureRecoveryStore {
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
            .appendingPathComponent("pending-capture-recovery.json")
    }

    public func load() throws -> PendingCaptureRecoveryRecord? {
        guard fileManager.fileExists(atPath: storageURL.path) else { return nil }
        let data = try Data(contentsOf: storageURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let record = try decoder.decode(PendingCaptureRecoveryRecord.self, from: data)

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: record.stagingURL.path, isDirectory: &isDirectory),
              !isDirectory.boolValue else {
            try? remove()
            return nil
        }
        return record
    }

    public func save(_ record: PendingCaptureRecoveryRecord) throws {
        try fileManager.createDirectory(
            at: storageURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(record).write(to: storageURL, options: [.atomic])
    }

    public func remove() throws {
        guard fileManager.fileExists(atPath: storageURL.path) else { return }
        try fileManager.removeItem(at: storageURL)
    }
}

import Foundation

/// How this archive was produced. Folder scans leave this nil; Capture fills it in.
public enum CaptureArchiveRoute: String, Codable, Equatable, Sendable {
    case appAudio
    case inputDevice
    case folder
}

/// App Audio capture engine. Nil for folder copies and Input Device Capture.
public enum CaptureArchiveBackend: String, Codable, Equatable, Sendable {
    case virtualInputDevice
    case processAudioTap
    case screenCaptureKit
    case setcatcherVirtualDriver
}

public struct ArchiveMetadata: Identifiable, Codable, Equatable, Sendable {
    public let sessionID: UUID
    public let sourceAppID: String
    public let detectedAt: Date
    public let completedAt: Date?
    public let sourcePath: String
    public let archivePath: String
    public let fileSize: Int64
    public let originalFilename: String
    public let durationSeconds: Double?
    public let sourceFingerprint: String?
    public let captureRoute: CaptureArchiveRoute?
    public let captureBackend: CaptureArchiveBackend?
    public let captureDeviceUID: String?
    public let captureDeviceName: String?
    public let captureDeviceTransport: String?
    public let captureInterrupted: Bool
    public let captureInterruptionReason: String?

    public var id: UUID { sessionID }

    private enum CodingKeys: String, CodingKey {
        case sessionID, sourceAppID, detectedAt, completedAt, sourcePath, archivePath
        case fileSize, originalFilename, durationSeconds, sourceFingerprint
        case captureRoute, captureBackend, captureDeviceUID, captureDeviceName, captureDeviceTransport
        case captureInterrupted, captureInterruptionReason
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionID = try container.decode(UUID.self, forKey: .sessionID)
        sourceAppID = try container.decode(String.self, forKey: .sourceAppID)
        detectedAt = try container.decode(Date.self, forKey: .detectedAt)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        sourcePath = try container.decode(String.self, forKey: .sourcePath)
        archivePath = try container.decode(String.self, forKey: .archivePath)
        fileSize = try container.decode(Int64.self, forKey: .fileSize)
        originalFilename = try container.decode(String.self, forKey: .originalFilename)
        durationSeconds = try container.decodeIfPresent(Double.self, forKey: .durationSeconds)
        sourceFingerprint = try container.decodeIfPresent(String.self, forKey: .sourceFingerprint)
        captureRoute = try container.decodeIfPresent(CaptureArchiveRoute.self, forKey: .captureRoute)
        captureBackend = try container.decodeIfPresent(CaptureArchiveBackend.self, forKey: .captureBackend)
        captureDeviceUID = try container.decodeIfPresent(String.self, forKey: .captureDeviceUID)
        captureDeviceName = try container.decodeIfPresent(String.self, forKey: .captureDeviceName)
        captureDeviceTransport = try container.decodeIfPresent(String.self, forKey: .captureDeviceTransport)
        captureInterrupted = try container.decodeIfPresent(Bool.self, forKey: .captureInterrupted) ?? false
        captureInterruptionReason = try container.decodeIfPresent(String.self, forKey: .captureInterruptionReason)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sessionID, forKey: .sessionID)
        try container.encode(sourceAppID, forKey: .sourceAppID)
        try container.encode(detectedAt, forKey: .detectedAt)
        try container.encodeIfPresent(completedAt, forKey: .completedAt)
        try container.encode(sourcePath, forKey: .sourcePath)
        try container.encode(archivePath, forKey: .archivePath)
        try container.encode(fileSize, forKey: .fileSize)
        try container.encode(originalFilename, forKey: .originalFilename)
        try container.encodeIfPresent(durationSeconds, forKey: .durationSeconds)
        try container.encodeIfPresent(sourceFingerprint, forKey: .sourceFingerprint)
        try container.encodeIfPresent(captureRoute, forKey: .captureRoute)
        try container.encodeIfPresent(captureBackend, forKey: .captureBackend)
        try container.encodeIfPresent(captureDeviceUID, forKey: .captureDeviceUID)
        try container.encodeIfPresent(captureDeviceName, forKey: .captureDeviceName)
        try container.encodeIfPresent(captureDeviceTransport, forKey: .captureDeviceTransport)
        if captureInterrupted {
            try container.encode(captureInterrupted, forKey: .captureInterrupted)
        }
        try container.encodeIfPresent(captureInterruptionReason, forKey: .captureInterruptionReason)
    }

    public init(session: RecordingSession, originalFilename: String) {
        self.sessionID = session.id
        self.sourceAppID = session.sourceAppID
        self.detectedAt = session.detectedAt
        self.completedAt = session.completedAt
        self.sourcePath = session.sourceURL.path
        self.archivePath = session.archiveURL?.path ?? ""
        self.fileSize = session.fileSize ?? 0
        self.originalFilename = originalFilename
        self.durationSeconds = nil
        self.sourceFingerprint = nil
        self.captureRoute = nil
        self.captureBackend = nil
        self.captureDeviceUID = nil
        self.captureDeviceName = nil
        self.captureDeviceTransport = nil
        self.captureInterrupted = false
        self.captureInterruptionReason = nil
    }

    public init(
        sessionID: UUID,
        sourceAppID: String,
        detectedAt: Date,
        completedAt: Date?,
        sourcePath: String,
        archivePath: String,
        fileSize: Int64,
        originalFilename: String,
        durationSeconds: Double?,
        sourceFingerprint: String? = nil,
        captureRoute: CaptureArchiveRoute? = nil,
        captureBackend: CaptureArchiveBackend? = nil,
        captureDeviceUID: String? = nil,
        captureDeviceName: String? = nil,
        captureDeviceTransport: String? = nil,
        captureInterrupted: Bool = false,
        captureInterruptionReason: String? = nil
    ) {
        self.sessionID = sessionID
        self.sourceAppID = sourceAppID
        self.detectedAt = detectedAt
        self.completedAt = completedAt
        self.sourcePath = sourcePath
        self.archivePath = archivePath
        self.fileSize = fileSize
        self.originalFilename = originalFilename
        self.durationSeconds = durationSeconds
        self.sourceFingerprint = sourceFingerprint
        self.captureRoute = captureRoute
        self.captureBackend = captureBackend
        self.captureDeviceUID = captureDeviceUID
        self.captureDeviceName = captureDeviceName
        self.captureDeviceTransport = captureDeviceTransport
        self.captureInterrupted = captureInterrupted
        self.captureInterruptionReason = captureInterruptionReason
    }
}

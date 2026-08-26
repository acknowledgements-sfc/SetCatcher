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
    case djmemoryVirtualDriver
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

    public var id: UUID { sessionID }

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
        captureDeviceTransport: String? = nil
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
    }
}

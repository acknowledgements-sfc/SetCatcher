import Foundation
import CryptoKit
import Darwin
import os

public enum ArchiveServiceError: Error, Equatable {
    case sourceFileMissing(URL)
    case sourceIsDirectory(URL)
    case archiveDirectoryUnavailable(URL)
    case copyVerificationFailed(source: URL, destination: URL)
}

public struct ArchiveService {
    public static let defaultNamingTemplate = AppSettings.defaultArchiveNamingTemplate
    private static let captureLifecycleLogger = Logger(
        subsystem: "app.djmemory",
        category: "capture-lifecycle"
    )

    public let archiveRoot: URL
    private let fileManager: FileManager
    private let calendar: Calendar
    private let durationReader: any AudioDurationReading
    private let namingTemplate: String
    private let archiveRootBookmarkData: Data?
    private let verifyCopies: Bool

    public init(
        archiveRoot: URL = Self.defaultArchiveRoot(),
        fileManager: FileManager = .default,
        calendar: Calendar = .current,
        durationReader: any AudioDurationReading = AudioDurationReader(),
        namingTemplate: String = Self.defaultNamingTemplate,
        archiveRootBookmarkData: Data? = nil,
        verifyCopies: Bool = true
    ) {
        self.archiveRoot = archiveRoot
        self.fileManager = fileManager
        self.calendar = calendar
        self.durationReader = durationReader
        self.namingTemplate = namingTemplate
        self.archiveRootBookmarkData = archiveRootBookmarkData
        self.verifyCopies = verifyCopies
    }

    public static func defaultArchiveRoot() -> URL {
        DefaultPathProvider().defaultArchiveRoot()
    }

    @discardableResult
    public func archive(sourceURL: URL, sourceAppID: String, detectedAt: Date = Date()) throws -> RecordingSession {
        try withSecurityScopedArchiveRoot {
            try archiveWithAccess(sourceURL: sourceURL, sourceAppID: sourceAppID, detectedAt: detectedAt)
        }
    }

    @discardableResult
    public func ingestCapture(
        stagingURL: URL,
        deviceID: String,
        deviceName: String,
        startedAt: Date,
        endedAt: Date = Date(),
        sourceAppID: String = SupportedDJSoftware.captureAppID,
        removeStagingAfterCopy: Bool = true,
        captureRoute: CaptureArchiveRoute? = nil,
        captureBackend: CaptureArchiveBackend? = nil,
        captureDeviceTransport: String? = nil
    ) throws -> RecordingSession {
        try withSecurityScopedArchiveRoot {
            try ingestCaptureWithAccess(
                stagingURL: stagingURL,
                deviceID: deviceID,
                deviceName: deviceName,
                startedAt: startedAt,
                endedAt: endedAt,
                sourceAppID: sourceAppID,
                removeStagingAfterCopy: removeStagingAfterCopy,
                captureRoute: captureRoute,
                captureBackend: captureBackend,
                captureDeviceTransport: captureDeviceTransport
            )
        }
    }

    public func ensureArchiveRootExists() throws {
        try withSecurityScopedArchiveRoot {
            try ensureArchiveRootExistsWithAccess()
        }
    }

    private func archiveWithAccess(sourceURL: URL, sourceAppID: String, detectedAt: Date) throws -> RecordingSession {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: sourceURL.path, isDirectory: &isDirectory) else {
            throw ArchiveServiceError.sourceFileMissing(sourceURL)
        }

        guard !isDirectory.boolValue else {
            throw ArchiveServiceError.sourceIsDirectory(sourceURL)
        }

        try ensureArchiveRootExistsWithAccess()

        let fileSize = try sourceURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        let sourceFingerprint = try contentFingerprint(for: sourceURL)
        let destinationURL = uniqueDestinationURL(for: sourceURL, sourceAppID: sourceAppID, detectedAt: detectedAt)

        try fileManager.copyItem(at: sourceURL, to: destinationURL)

        do {
            try verifyCopyIfNeeded(sourceURL: sourceURL, destinationURL: destinationURL, expectedSize: fileSize)
            let session = RecordingSession(
                sourceAppID: sourceAppID,
                detectedAt: detectedAt,
                completedAt: Date(),
                sourceURL: sourceURL,
                archiveURL: destinationURL,
                fileSize: Int64(fileSize),
                status: .archived
            )

            try writeMetadata(
                for: session,
                originalFilename: sourceURL.lastPathComponent,
                sourceFingerprint: sourceFingerprint
            )
            return session
        } catch {
            try? fileManager.removeItem(at: destinationURL)
            try? fileManager.removeItem(at: metadataURL(for: destinationURL))
            throw error
        }
    }

    private func ingestCaptureWithAccess(
        stagingURL: URL,
        deviceID: String,
        deviceName: String,
        startedAt: Date,
        endedAt: Date,
        sourceAppID: String,
        removeStagingAfterCopy: Bool,
        captureRoute: CaptureArchiveRoute?,
        captureBackend: CaptureArchiveBackend?,
        captureDeviceTransport: String?
    ) throws -> RecordingSession {
        logCaptureIngest(event: "archive-ingest-entered", stagingURL: stagingURL)
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: stagingURL.path, isDirectory: &isDirectory) else {
            logCaptureIngest(event: "archive-source-missing", stagingURL: stagingURL)
            throw ArchiveServiceError.sourceFileMissing(stagingURL)
        }
        guard !isDirectory.boolValue else {
            throw ArchiveServiceError.sourceIsDirectory(stagingURL)
        }
        try ensureArchiveRootExistsWithAccess()
        let sanitizedDevice = sanitizeFilenameComponent(deviceName.isEmpty ? "Capture" : deviceName)
        let syntheticSourceName = "\(sanitizedDevice).wav"
        let syntheticSourceURL = URL(fileURLWithPath: "/DJMemoryCapture/\(sanitizedDevice)/\(deviceID)/\(syntheticSourceName)")
        let fileSize = try stagingURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        let sourceFingerprint = try contentFingerprint(for: stagingURL)
        let destinationURL = uniqueDestinationURL(for: syntheticSourceURL, sourceAppID: sourceAppID, detectedAt: startedAt)
        try fileManager.copyItem(at: stagingURL, to: destinationURL)
        do {
            try verifyCopyIfNeeded(sourceURL: stagingURL, destinationURL: destinationURL, expectedSize: fileSize)
            if removeStagingAfterCopy {
                try? fileManager.removeItem(at: stagingURL)
            }
            logCaptureIngest(event: "archive-ingest-completed", stagingURL: stagingURL)
            let session = RecordingSession(
                sourceAppID: sourceAppID,
                detectedAt: startedAt,
                completedAt: endedAt,
                sourceURL: syntheticSourceURL,
                archiveURL: destinationURL,
                fileSize: Int64(fileSize),
                status: .archived
            )
            try writeMetadata(
                for: session,
                originalFilename: syntheticSourceName,
                sourceFingerprint: sourceFingerprint,
                captureRoute: captureRoute,
                captureBackend: captureBackend,
                captureDeviceUID: deviceID,
                captureDeviceName: deviceName,
                captureDeviceTransport: captureDeviceTransport
            )
            return session
        } catch {
            try? fileManager.removeItem(at: destinationURL)
            try? fileManager.removeItem(at: metadataURL(for: destinationURL))
            throw error
        }
    }

    private func ensureArchiveRootExistsWithAccess() throws {
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: archiveRoot.path, isDirectory: &isDirectory), !isDirectory.boolValue {
            throw ArchiveServiceError.archiveDirectoryUnavailable(archiveRoot)
        }

        try fileManager.createDirectory(at: archiveRoot, withIntermediateDirectories: true)

        guard fileManager.fileExists(atPath: archiveRoot.path) else {
            throw ArchiveServiceError.archiveDirectoryUnavailable(archiveRoot)
        }
    }

    public func metadataURL(for archiveURL: URL) -> URL {
        archiveURL.deletingPathExtension().appendingPathExtension("json")
    }

    public func isSourceAlreadyArchived(_ sourceURL: URL) -> Bool {
        (try? withSecurityScopedArchiveRoot {
            isSourceAlreadyArchivedWithAccess(sourceURL)
        }) ?? false
    }

    private func isSourceAlreadyArchivedWithAccess(_ sourceURL: URL) -> Bool {
        guard let metadataURLs = try? fileManager.contentsOfDirectory(
            at: archiveRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return false
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let sourcePath = sourceURL.path
        let sourceFileSize = (try? sourceURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init)
        var sourceFingerprint: String?

        return metadataURLs
            .filter { $0.pathExtension.lowercased() == "json" }
            .contains { metadataURL in
                guard
                    let data = try? Data(contentsOf: metadataURL),
                    let metadata = try? decoder.decode(ArchiveMetadata.self, from: data)
                else {
                    return false
                }

                if metadata.sourcePath == sourcePath {
                    if let sourceFileSize, metadata.fileSize > 0, metadata.fileSize != sourceFileSize {
                        return false
                    }

                    if let metadataFingerprint = metadata.sourceFingerprint {
                        if sourceFingerprint == nil {
                            sourceFingerprint = try? contentFingerprint(for: sourceURL)
                        }
                        if let sourceFingerprint, sourceFingerprint != metadataFingerprint {
                            return false
                        }
                    }

                    return true
                }

                guard
                    let sourceFileSize,
                    let metadataFingerprint = metadata.sourceFingerprint
                else {
                    return false
                }

                if sourceFingerprint == nil {
                    sourceFingerprint = try? contentFingerprint(for: sourceURL)
                }

                guard let sourceFingerprint else {
                    return false
                }

                return metadata.fileSize > 0
                    && metadata.fileSize == sourceFileSize
                    && metadataFingerprint == sourceFingerprint
            }
    }

    private func verifyCopyIfNeeded(sourceURL: URL, destinationURL: URL, expectedSize: Int) throws {
        guard verifyCopies else { return }

        let destSize = try destinationURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? -1
        guard destSize == expectedSize else {
            throw ArchiveServiceError.copyVerificationFailed(source: sourceURL, destination: destinationURL)
        }

        let sourceFingerprint = try contentFingerprint(for: sourceURL)
        let destFingerprint = try contentFingerprint(for: destinationURL)
        guard sourceFingerprint == destFingerprint else {
            throw ArchiveServiceError.copyVerificationFailed(source: sourceURL, destination: destinationURL)
        }
    }

    private func withSecurityScopedArchiveRoot<T>(_ operation: () throws -> T) throws -> T {
        try SecurityScopedAccess.withScopedArchiveRootAccess(
            bookmarkData: archiveRootBookmarkData,
            operation: operation
        )
    }

    private func writeMetadata(
        for session: RecordingSession,
        originalFilename: String,
        sourceFingerprint: String,
        captureRoute: CaptureArchiveRoute? = nil,
        captureBackend: CaptureArchiveBackend? = nil,
        captureDeviceUID: String? = nil,
        captureDeviceName: String? = nil,
        captureDeviceTransport: String? = nil
    ) throws {
        guard let archiveURL = session.archiveURL else { return }

        let metadata = ArchiveMetadata(
            sessionID: session.id,
            sourceAppID: session.sourceAppID,
            detectedAt: session.detectedAt,
            completedAt: session.completedAt,
            sourcePath: session.sourceURL.path,
            archivePath: archiveURL.path,
            fileSize: session.fileSize ?? 0,
            originalFilename: originalFilename,
            durationSeconds: durationReader.durationSeconds(for: archiveURL),
            sourceFingerprint: sourceFingerprint,
            captureRoute: captureRoute,
            captureBackend: captureBackend,
            captureDeviceUID: captureDeviceUID,
            captureDeviceName: captureDeviceName,
            captureDeviceTransport: captureDeviceTransport
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(metadata)
        try data.write(to: metadataURL(for: archiveURL), options: [.atomic])
    }

    private func uniqueDestinationURL(for sourceURL: URL, sourceAppID: String, detectedAt: Date) -> URL {
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = calendar
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let timeFormatter = DateFormatter()
        timeFormatter.calendar = calendar
        timeFormatter.dateFormat = "HHmm"

        let appName = SupportedDJSoftware.all.first { $0.id == sourceAppID }?.displayName ?? sourceAppID
        let ext = sourceURL.pathExtension
        let renderedName = namingTemplate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? Self.defaultNamingTemplate
            : namingTemplate
        let baseName = sanitizeFilenameComponent(
            renderedName
                .replacingOccurrences(of: "{date}", with: dateFormatter.string(from: detectedAt))
                .replacingOccurrences(of: "{time}", with: timeFormatter.string(from: detectedAt))
                .replacingOccurrences(of: "{app}", with: appName)
                .replacingOccurrences(of: "{source}", with: sourceURL.deletingPathExtension().lastPathComponent)
        )

        var candidate = archiveRoot.appendingPathComponent(baseName).appendingPathExtension(ext)
        var suffix = 2

        while fileManager.fileExists(atPath: candidate.path) {
            candidate = archiveRoot.appendingPathComponent("\(baseName) \(suffix)").appendingPathExtension(ext)
            suffix += 1
        }

        return candidate
    }

    private func sanitizeFilenameComponent(_ value: String) -> String {
        let invalid = CharacterSet(charactersIn: "/:")
        return value.components(separatedBy: invalid).joined(separator: "-")
    }

    private func contentFingerprint(for url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer {
            try? handle.close()
        }

        var hasher = SHA256()

        while let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty {
            hasher.update(data: chunk)
        }

        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private func logCaptureIngest(event: String, stagingURL: URL) {
        var info = stat()
        let result = stagingURL.path.withCString { lstat($0, &info) }
        let state = result == 0 ? "exists(bytes=\(info.st_size))" : "missing(errno=\(errno))"
        Self.captureLifecycleLogger.notice(
            "capture_lifecycle event=\(event, privacy: .public) path=\(stagingURL.path, privacy: .public) state=\(state, privacy: .public)"
        )
    }
}

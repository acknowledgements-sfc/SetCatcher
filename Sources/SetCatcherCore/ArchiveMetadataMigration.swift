import Foundation

/// Repairs legacy Capture sidecars that tagged `sourceAppID` as the DJ app instead of `setcatcher-capture`.
public enum ArchiveMetadataMigration {
    private static let djFamilyAppIDs: Set<String> = [
        "serato",
        "rekordbox",
        "traktor",
        "virtualdj",
        "djay",
        "denon-engine"
    ]

    /// Returns repaired metadata when a legacy mis-tag is detected; otherwise returns the input unchanged.
    public static func repairedIfNeeded(_ metadata: ArchiveMetadata) -> ArchiveMetadata {
        guard metadata.ingestionKind == nil,
              metadata.captureRoute != nil,
              metadata.sourceAppID != SupportedDJSoftware.captureAppID,
              djFamilyAppIDs.contains(metadata.sourceAppID) else {
            return metadata
        }

        return ArchiveMetadata(
            sessionID: metadata.sessionID,
            sourceAppID: SupportedDJSoftware.captureAppID,
            detectedAt: metadata.detectedAt,
            completedAt: metadata.completedAt,
            sourcePath: metadata.sourcePath,
            archivePath: metadata.archivePath,
            fileSize: metadata.fileSize,
            originalFilename: metadata.originalFilename,
            durationSeconds: metadata.durationSeconds,
            sourceFingerprint: metadata.sourceFingerprint,
            ingestionKind: .capture,
            companionAppID: metadata.sourceAppID,
            captureRoute: metadata.captureRoute,
            captureBackend: metadata.captureBackend,
            captureDeviceUID: metadata.captureDeviceUID,
            captureDeviceName: metadata.captureDeviceName,
            captureDeviceTransport: metadata.captureDeviceTransport,
            captureInterrupted: metadata.captureInterrupted,
            captureInterruptionReason: metadata.captureInterruptionReason
        )
    }

    /// Decodes, repairs if needed, and atomically rewrites the sidecar when migration applies.
    public static func loadRepaired(
        from metadataURL: URL,
        decoder: JSONDecoder,
        encoder: JSONEncoder
    ) throws -> ArchiveMetadata? {
        guard let data = try? Data(contentsOf: metadataURL),
              var metadata = try? decoder.decode(ArchiveMetadata.self, from: data) else {
            return nil
        }

        let repaired = repairedIfNeeded(metadata)
        guard repaired != metadata else {
            return metadata
        }

        metadata = repaired
        let encoded = try encoder.encode(metadata)
        try encoded.write(to: metadataURL, options: [.atomic])
        return metadata
    }
}

import SwiftUI
import DJMemoryCore

struct SetDetailSourcesView: View {
    let summary: LibrarySessionSummary
    let appName: String
    let revealArchive: () -> Void
    let revealSource: () -> Void
    let revealHardwareBackup: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Waveform(
                seed: summary.archive.originalFilename,
                barCount: 64,
                tint: DJToken.accent(forAppID: summary.archive.sourceAppID)
            )
            .frame(height: 40)
            .padding(8)
            .background(DJToken.muted, in: RoundedRectangle(cornerRadius: DJToken.Radius.control))

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(summary.archive.originalFilename)
                        .font(.headline)
                    Text("\(appName) | \(formatBytes(summary.archive.fileSize)) | \(formatDuration(summary.archive.durationSeconds))")
                        .font(.caption)
                        .foregroundStyle(DJToken.mutedForeground)
                }

                Spacer()

                Button(action: revealSource) {
                    Label("Source", systemImage: "arrow.up.forward.app")
                }
                .help(summary.archive.sourcePath)
                .accessibilityIdentifier("setDetail.\(summary.id).revealSource")

                Button(action: revealArchive) {
                    Label("Archive", systemImage: "folder")
                }
                .help(summary.archive.archivePath)
                .accessibilityIdentifier("setDetail.\(summary.id).revealArchive")
            }

            if let backup = summary.hardwareBackup {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Hardware backup")
                        .font(.callout.weight(.medium))
                    Text(hardwareBackupBody(backup))
                        .font(.caption)
                        .foregroundStyle(DJToken.mutedForeground)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Text("\(backup.originalFilename) | \(formatBytes(backup.fileSize)) | \(formatDuration(backup.durationSeconds))")
                            .font(.caption)
                            .foregroundStyle(DJToken.mutedForeground)
                        Spacer()
                        Button(action: revealHardwareBackup) {
                            Label("Archive", systemImage: "folder")
                        }
                        .help(backup.archivePath)
                        .accessibilityIdentifier("setDetail.\(summary.id).revealHardwareBackup")
                    }
                }
            }
        }
    }

    private func hardwareBackupBody(_ backup: ArchiveMetadata) -> String {
        let device = URL(fileURLWithPath: backup.originalFilename).deletingPathExtension().lastPathComponent
        let name = device.isEmpty ? "USB" : device
        return "Caught from the \(name) USB input. The source recording was not moved, renamed, or deleted."
    }

    private func formatDuration(_ seconds: Double?) -> String {
        guard let seconds else { return "Unknown duration" }
        let totalSeconds = Int(seconds.rounded())
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let remainingSeconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        }
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

#if DEBUG
#Preview("Sources grouped / dark") {
    SetDetailSourcesView(
        summary: LibrarySessionSummary(
            archive: ArchiveMetadata(
                sessionID: UUID(),
                sourceAppID: "serato",
                detectedAt: Date(),
                completedAt: Date(),
                sourcePath: "/Music/_Serato_/Recording/set.wav",
                archivePath: "/Music/DJMemory/set.wav",
                fileSize: 80_000_000,
                originalFilename: "set.wav",
                durationSeconds: 3600
            ),
            matchedTracklist: nil,
            hardwareBackup: ArchiveMetadata(
                sessionID: UUID(),
                sourceAppID: SupportedDJSoftware.captureAppID,
                detectedAt: Date().addingTimeInterval(-3600),
                completedAt: Date(),
                sourcePath: "/DJMemoryCapture/XDJ-XZ/dev/XDJ-XZ.wav",
                archivePath: "/Music/DJMemory/XDJ-XZ.wav",
                fileSize: 90_000_000,
                originalFilename: "XDJ-XZ.wav",
                durationSeconds: 3650
            )
        ),
        appName: "Serato DJ Pro",
        revealArchive: {},
        revealSource: {},
        revealHardwareBackup: {}
    )
    .padding()
    .frame(width: 352)
    .preferredColorScheme(.dark)
}

#Preview("Sources capture-only / light") {
    SetDetailSourcesView(
        summary: LibrarySessionSummary(
            archive: ArchiveMetadata(
                sessionID: UUID(),
                sourceAppID: SupportedDJSoftware.captureAppID,
                detectedAt: Date(),
                completedAt: Date(),
                sourcePath: "/DJMemoryCapture/XDJ-XZ/dev/XDJ-XZ.wav",
                archivePath: "/Music/DJMemory/XDJ-XZ.wav",
                fileSize: 90_000_000,
                originalFilename: "XDJ-XZ.wav",
                durationSeconds: 1800
            ),
            matchedTracklist: nil
        ),
        appName: "SetCatcher Capture",
        revealArchive: {},
        revealSource: {},
        revealHardwareBackup: {}
    )
    .padding()
    .frame(width: 352)
    .preferredColorScheme(.light)
}
#endif

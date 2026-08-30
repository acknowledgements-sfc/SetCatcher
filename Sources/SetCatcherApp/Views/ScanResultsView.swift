import SwiftUI
import SetCatcherCore

struct ScanResultsView: View {
    let results: [FolderScanResult]
    var appID: String?
    var onRecover: ((String) -> Void)?

    var body: some View {
        if !results.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Latest Scan")
                    .font(.system(size: DJToken.TypeSize.body, weight: .semibold))
                    .foregroundStyle(DJToken.foreground)

                ForEach(results, id: \.folderURL) { result in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            Image(systemName: scanResultSymbol(for: result))
                                .foregroundStyle(scanResultTint(for: result))

                            VStack(alignment: .leading, spacing: 3) {
                                Text(result.folderURL.path)
                                    .font(.system(size: DJToken.TypeSize.secondary).monospaced())
                                    .foregroundStyle(DJToken.foreground)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .help(result.folderURL.path)

                                if let errorDescription = result.errorDescription {
                                    Text(errorDescription)
                                        .font(.system(size: DJToken.TypeSize.secondary))
                                        .foregroundStyle(DJToken.mutedForeground)
                                        .help(errorDescription)
                                } else if !result.pendingRecordingURLs.isEmpty {
                                    Text("\(result.pendingRecordingURLs.count) active recording\(result.pendingRecordingURLs.count == 1 ? "" : "s") waiting to finish")
                                        .font(.system(size: DJToken.TypeSize.secondary))
                                        .foregroundStyle(DJToken.mutedForeground)
                                } else {
                                    Text("\(result.archivedSessions.count) new recording\(result.archivedSessions.count == 1 ? "" : "s") archived")
                                        .font(.system(size: DJToken.TypeSize.secondary))
                                        .foregroundStyle(DJToken.mutedForeground)
                                }
                            }
                        }

                        if result.errorDescription != nil, let appID, let onRecover {
                            Button("Choose Folder Again") {
                                onRecover(appID)
                            }
                            .buttonStyle(DJPrimaryButtonStyle())
                            .accessibilityIdentifier("scan.\(appID).recover")
                        }
                    }
                    .padding(12)
                    .background(DJToken.card, in: RoundedRectangle(cornerRadius: DJToken.Radius.control))
                    .overlay(
                        RoundedRectangle(cornerRadius: DJToken.Radius.control)
                            .stroke(DJToken.border, lineWidth: 1)
                    )
                    .help(scanResultHelp(for: result))
                }
            }
        }
    }

    private func scanResultHelp(for result: FolderScanResult) -> String {
        if let errorDescription = result.errorDescription {
            return "\(result.folderURL.path)\n\(errorDescription)"
        }

        if !result.pendingRecordingURLs.isEmpty {
            let names = result.pendingRecordingURLs
                .map(\.lastPathComponent)
                .joined(separator: "\n")
            return "\(result.folderURL.path)\nWaiting for recording to finish:\n\(names)"
        }

        return "\(result.folderURL.path)\n\(result.archivedSessions.count) new recording\(result.archivedSessions.count == 1 ? "" : "s") archived"
    }

    private func scanResultSymbol(for result: FolderScanResult) -> String {
        if result.errorDescription != nil { return "exclamationmark.triangle" }
        if !result.pendingRecordingURLs.isEmpty { return "record.circle.fill" }
        return "checkmark.circle"
    }

    private func scanResultTint(for result: FolderScanResult) -> Color {
        if result.errorDescription != nil { return DJToken.warn }
        if !result.pendingRecordingURLs.isEmpty { return DJToken.danger }
        return DJToken.ok
    }
}

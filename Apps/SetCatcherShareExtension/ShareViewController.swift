import UIKit
import UniformTypeIdentifiers
import SetCatcherCompanion

final class ShareViewController: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Task { await handleSharedItems() }
    }

    private func handleSharedItems() async {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            finish()
            return
        }

        var copied = 0
        for item in items {
            guard let attachments = item.attachments else { continue }
            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier(UTType.audio.identifier) {
                    do {
                        let url = try await loadFileURL(from: provider, type: UTType.audio.identifier)
                        _ = try CompanionInbox.copySharedFile(from: url)
                        copied += 1
                    } catch {
                        // Continue other attachments; surface failure via incomplete copy count.
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                    do {
                        let url = try await loadFileURL(from: provider, type: UTType.fileURL.identifier)
                        let ext = url.pathExtension.lowercased()
                        guard ["wav", "mp3", "m4a", "aiff", "caf"].contains(ext) else { continue }
                        _ = try CompanionInbox.copySharedFile(from: url)
                        copied += 1
                    } catch {}
                }
            }
        }

        if copied > 0, let openURL = URL(string: "app.setcatcher.SetCatcher.iPad://inbox") {
            _ = openURL
            // Prefer completing the extension; user opens companion to drain inbox.
        }
        finish()
    }

    private func loadFileURL(from provider: NSItemProvider, type: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: type, options: nil) { item, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                if let url = item as? URL {
                    continuation.resume(returning: url)
                } else if let data = item as? Data {
                    let temp = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension("wav")
                    do {
                        try data.write(to: temp)
                        continuation.resume(returning: temp)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                } else {
                    continuation.resume(throwing: NSError(domain: "SetCatcherShare", code: 2))
                }
            }
        }
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}

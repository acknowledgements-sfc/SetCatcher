import XCTest

/// Static scan of App sources for required accessibilityIdentifier families.
/// Does not rename or assert exact control lists — only that each family still appears.
final class AccessibilityIdentifierAuditTests: XCTestCase {
    func testRequiredIdentifierFamiliesPresentInAppSources() throws {
        let thisFile = URL(fileURLWithPath: #filePath)
        let repoRoot = thisFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourcesRoot = repoRoot.appendingPathComponent("Sources/DJMemoryApp", isDirectory: true)

        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: sourcesRoot.path, isDirectory: &isDir), isDir.boolValue else {
            XCTFail("Sources/DJMemoryApp not found at \(sourcesRoot.path)")
            return
        }

        let swiftFiles = try Self.swiftFiles(under: sourcesRoot)
        XCTAssertFalse(swiftFiles.isEmpty, "Expected Swift sources under \(sourcesRoot.path)")

        var corpus = ""
        for file in swiftFiles {
            corpus += (try String(contentsOf: file, encoding: .utf8))
            corpus += "\n"
        }

        // Plan-required families (plus onboarding/recovery/home used by smoke policy).
        let requiredPrefixes = [
            "sidebar.",
            "protection.",
            "protectionSource.",
            "setup.",
            "historyImport.",
            "library.",
            "setDetail.",
            "tracklistDetail.",
            "settings.",
            "activity.",
            "virtualdj.networkControl.check",
            "header.openArchiveFolder",
            "onboarding.",
            "recovery.",
            "home."
        ]

        var missing: [String] = []
        for prefix in requiredPrefixes {
            let needle = "accessibilityIdentifier(\"\(prefix)"
            if !corpus.contains(needle) {
                missing.append(prefix)
            }
        }

        XCTAssertTrue(
            missing.isEmpty,
            "Missing required accessibilityIdentifier families: \(missing.joined(separator: ", "))"
        )
    }

    private static func swiftFiles(under root: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        var files: [URL] = []
        while let item = enumerator.nextObject() as? URL {
            if item.pathExtension == "swift" {
                files.append(item)
            }
        }
        return files
    }
}

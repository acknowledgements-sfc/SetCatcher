import Foundation
import SetCatcherCore

let arguments = Array(CommandLine.arguments.dropFirst())

switch arguments.first {
case "probe":
    runProbe()
case "archive":
    try runArchive(arguments: arguments)
case "scan":
    try runScan(arguments: arguments)
case "watch":
    try runWatch(arguments: arguments)
case "diagnostics":
    try runDiagnostics(arguments: arguments)
case "virtualdj-network":
    runVirtualDJNetworkProbe(arguments: arguments)
case "app-audio-probe":
    runAppAudioProbeSync(arguments: arguments)
default:
    printUsage()
}

private func printUsage() {
    print("""
    Usage:
      setcatcher probe
      setcatcher archive <file> [appID]
      setcatcher scan <folder> [appID]
      setcatcher watch <folder> [appID]
      setcatcher diagnostics [output.json|-]
      setcatcher virtualdj-network [endpointURL]
      setcatcher app-audio-probe [seconds] [softwareID]
    """)
}

private func runProbe() {
    let probe = SoftwareProbe()
    let results = probe.probeAll()

    for result in results {
        print("\(result.software.displayName): \(result.status)")

        if result.installations.isEmpty {
            for bundleIdentifier in result.runningApplicationBundleIdentifiers {
                print("  running: \(bundleIdentifier)")
            }

            for url in result.installedApplicationURLs {
                print("  app: \(url.path)")
            }

            for url in result.existingRecordingURLs {
                print("  recordings: \(url.path)")
            }

            for url in result.existingHistoryURLs {
                print("  history: \(url.path)")
            }
            continue
        }

        for installation in result.installations {
            print("  installation: \(installation.variantLabel)")
            if let version = installation.bundleVersion {
                print("    version: \(version)")
            }
            print("    app: \(installation.appURL.path)")
            if installation.isRunning {
                print("    running: \(installation.bundleIdentifier)")
            }

            for path in installation.discoveredPaths {
                print("    \(path.kind.rawValue): \(path.url.path) [\(path.source.rawValue)]")
            }
        }
    }
}

private func runArchive(arguments: [String]) throws {
    guard arguments.count >= 2 else {
        printUsage()
        return
    }

    let sourceURL = URL(fileURLWithPath: (arguments[1] as NSString).expandingTildeInPath)
    let appID = arguments.count >= 3 ? arguments[2] : "manual"
    let service = archiveService()
    let session = try service.archive(sourceURL: sourceURL, sourceAppID: appID)

    printArchived(session)
}

private func runScan(arguments: [String]) throws {
    guard arguments.count >= 2 else {
        printUsage()
        return
    }

    let folderURL = URL(fileURLWithPath: (arguments[1] as NSString).expandingTildeInPath, isDirectory: true)
    let appID = arguments.count >= 3 ? arguments[2] : "manual"
    let scanner = RecordingFolderScanner(archiveService: archiveService())
    let coordinator = ScanCoordinator(scanner: scanner)
    let result = coordinator.scanRecent(
        requests: [FolderScanRequest(appID: appID, folderURL: folderURL)]
    ).first

    guard let result else {
        print("No scan result returned.")
        return
    }

    if let errorDescription = result.errorDescription {
        print("Scan failed: \(errorDescription)")
    } else {
        if !result.archivedSessions.isEmpty {
            result.archivedSessions.forEach(printArchived(_:))
        }

        if !result.pendingRecordingURLs.isEmpty {
            print("Recording detected. Waiting for file to finish:")
            result.pendingRecordingURLs.forEach { print("  \($0.path)") }
        }

        if result.archivedSessions.isEmpty && result.pendingRecordingURLs.isEmpty {
            print("No recent stable audio files found.")
        }
    }
}

private func runWatch(arguments: [String]) throws {
    guard arguments.count >= 2 else {
        printUsage()
        return
    }

    let folderURL = URL(fileURLWithPath: (arguments[1] as NSString).expandingTildeInPath, isDirectory: true)
    let appID = arguments.count >= 3 ? arguments[2] : "manual"
    let service = archiveService()
    let scanner = RecordingFolderScanner(archiveService: service)
    let coordinator = ScanCoordinator(scanner: scanner)

    print("Watching \(folderURL.path)")
    print("Archiving stable audio files to \(service.archiveRoot.path)")

    while true {
        let result = coordinator.scanRecent(
            requests: [FolderScanRequest(appID: appID, folderURL: folderURL)]
        ).first

        if let result {
            if let errorDescription = result.errorDescription {
                print("Scan failed: \(errorDescription)")
            } else {
                if !result.archivedSessions.isEmpty {
                    result.archivedSessions.forEach(printArchived(_:))
                }

                if !result.pendingRecordingURLs.isEmpty {
                    print("Recording detected. Waiting for file to finish:")
                    result.pendingRecordingURLs.forEach { print("  \($0.path)") }
                }
            }
        }

        Thread.sleep(forTimeInterval: 30)
    }
}

private func printArchived(_ session: RecordingSession) {
    print("Archived: \(session.sourceURL.lastPathComponent)")

    if let archiveURL = session.archiveURL {
        print("  to: \(archiveURL.path)")
        print("  metadata: \(archiveURL.deletingPathExtension().appendingPathExtension("json").path)")
    }
}

private func archiveService() -> ArchiveService {
    if let path = ProcessInfo.processInfo.environment["SETCATCHER_ARCHIVE_ROOT"], !path.isEmpty {
        return ArchiveService(archiveRoot: URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true))
    }

    return ArchiveService()
}

private func runDiagnostics(arguments: [String]) throws {
    let outputArgument = arguments.count >= 2 ? arguments[1] : nil
    let outputURL = outputArgument.flatMap { argument -> URL? in
        guard argument != "-" else { return nil }
        return URL(fileURLWithPath: (argument as NSString).expandingTildeInPath)
    } ?? defaultDiagnosticsURL()

    let report = diagnosticsReport()
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(report)

    if outputArgument == "-" {
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
        return
    }

    try FileManager.default.createDirectory(
        at: outputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try data.write(to: outputURL, options: [.atomic])
    print("Diagnostics written: \(outputURL.path)")
}

private func diagnosticsReport() -> DiagnosticsReport {
    let settingsStore = AppSettingsStore()
    let settings = (try? settingsStore.load()) ?? .default
    let folderAccessStore = FolderAccessStore()
    let folderAccesses = (try? folderAccessStore.all()) ?? []
    let importedTracklists = (try? ImportedTracklistStore().all()) ?? []
    let activityEvents = (try? ActivityLogStore().all()) ?? []
    let archiveRootResolution = ArchiveRootResolver.resolve(settings: settings)
    let archiveRoot = archiveRootResolution.url
    let archives = (try? SessionLibrary(
        archiveRoot: archiveRoot,
        archiveRootBookmarkData: archiveRootResolution.bookmarkData
    ).archivedMetadata()) ?? []
    let probeResults = SoftwareProbe().probeAll()

    return DiagnosticsReportBuilder().build(
        archiveRoot: archiveRoot,
        probeResults: probeResults,
        recordingFolders: { appID in
            configuredFolders(
                appID: appID,
                kind: .recordings,
                folderAccessStore: folderAccessStore,
                folderAccesses: folderAccesses
            ) + discoveredRecordingFolders(appID: appID, probeResults: probeResults)
        },
        historyFolders: { appID in
            configuredFolders(
                appID: appID,
                kind: .history,
                folderAccessStore: folderAccessStore,
                folderAccesses: folderAccesses
            ) + discoveredHistoryFolders(appID: appID, probeResults: probeResults)
        },
        folderAccesses: folderAccesses,
        archives: archives,
        importedTracklists: importedTracklists,
        activityEvents: activityEvents
    )
}

private func configuredFolders(
    appID: String,
    kind: FolderKind,
    folderAccessStore: FolderAccessStore,
    folderAccesses: [FolderAccess]
) -> [URL] {
    folderAccesses
        .filter { $0.appID == appID && $0.kind == kind }
        .map { folderAccessStore.resolve($0) }
}

private func discoveredRecordingFolders(appID: String, probeResults: [SoftwareProbeResult]) -> [URL] {
    probeResults.first { $0.software.id == appID }?.existingRecordingURLs ?? []
}

private func discoveredHistoryFolders(appID: String, probeResults: [SoftwareProbeResult]) -> [URL] {
    probeResults.first { $0.software.id == appID }?.existingHistoryURLs ?? []
}

private func defaultDiagnosticsURL() -> URL {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd-HHmmss"
    let filename = "SetCatcher-Diagnostics-\(formatter.string(from: Date())).json"
    return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent(filename)
}

private func runVirtualDJNetworkProbe(arguments: [String]) {
    let endpoint = arguments.count >= 2
        ? URL(string: arguments[1]) ?? VirtualDJNetworkProbe.defaultEndpoint
        : VirtualDJNetworkProbe.defaultEndpoint
    let semaphore = DispatchSemaphore(value: 0)

    Task {
        let result = await VirtualDJNetworkProbe().probe(endpoint: endpoint)
        print("VirtualDJ Network Control: \(result.reachable ? "reachable" : "not reachable")")
        print("  endpoint: \(result.endpoint.absoluteString)")

        if let statusCode = result.statusCode {
            print("  status: \(statusCode)")
        }

        if let errorDescription = result.errorDescription {
            print("  error: \(errorDescription)")
        }

        semaphore.signal()
    }

    semaphore.wait()
}

#if os(macOS)
private func runAppAudioProbeSync(arguments: [String]) {
    let parsed = AppAudioProbeRunner.parseArgs(Array(arguments.dropFirst()))
    AppAudioProbeRunner.run(softwareID: parsed.softwareID, seconds: parsed.seconds)
}
#else
private func runAppAudioProbeSync(arguments: [String]) {
    print("app-audio-probe is only available on macOS.")
}
#endif


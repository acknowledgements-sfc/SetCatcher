import Foundation

#if os(macOS)
/// Metadata-only probe result for invisible-capture bench scripts.
public struct InvisibleCaptureProbeResult: Encodable, Sendable {
    public let timestamp: String
    public let softwareID: String
    public let bundleIdentifier: String
    public let backend: String
    public let sourceDeviceUID: String?
    public let peakLevel: Float
    public let outcome: String
    public let stagingBytes: Int?
    public let archivePath: String?
    public let libraryReconciled: Bool
    public let applePathExhausted: Bool
    public let forcedScreenCaptureKit: Bool
}

/// Headless App audio Capture probe (shared by `djmemory` CLI and `DJMemoryApp --app-audio-probe`).
public enum AppAudioProbeRunner {
    public static let defaultJSONLPath = "/tmp/djmemory-invisible-capture-results.jsonl"

    public static func appendJSONL(_ result: InvisibleCaptureProbeResult, to path: String = defaultJSONLPath) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(result),
              let line = String(data: data, encoding: .utf8)
        else { return }
        let url = URL(fileURLWithPath: path)
        if FileManager.default.fileExists(atPath: path),
           let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            try? handle.seekToEnd()
            if let payload = (line + "\n").data(using: .utf8) {
                try? handle.write(contentsOf: payload)
            }
        } else {
            try? (line + "\n").write(to: url, atomically: true, encoding: .utf8)
        }
    }

    public static func run(softwareID: String?, seconds: Int) {
        let seconds = max(1, seconds)
        let jsonlPath = ProcessInfo.processInfo.environment["DJMEMORY_INVISIBLE_CAPTURE_JSONL"]
            ?? defaultJSONLPath
        let forceSCK = ProcessInfo.processInfo.environment["DJMEMORY_FORCE_SCK_APP_AUDIO"] == "1"
        let semaphore = DispatchSemaphore(value: 0)
        let isoFormatter = ISO8601DateFormatter()

        Task {
            defer { semaphore.signal() }
            print("preflight: \(AppAudioCaptureService.screenCapturePermissionGranted())")
            if !AppAudioCaptureService.screenCapturePermissionGranted() {
                print("requesting Screen & System Audio Recording…")
                _ = AppAudioCaptureService.requestScreenCapturePermission()
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                print("preflight after request: \(AppAudioCaptureService.screenCapturePermissionGranted())")
            }

            let service = AppAudioCaptureService()
            do {
                let apps = try await service.listShareableDJApps()
                if apps.isEmpty {
                    print("targets: (none) — open a DJ app, or grant Screen & System Audio Recording.")
                    if let softwareID {
                        appendJSONL(
                            InvisibleCaptureProbeResult(
                                timestamp: isoFormatter.string(from: Date()),
                                softwareID: softwareID,
                                bundleIdentifier: "",
                                backend: "none",
                                sourceDeviceUID: nil,
                                peakLevel: 0,
                                outcome: "no_target",
                                stagingBytes: nil,
                                archivePath: nil,
                                libraryReconciled: false,
                                applePathExhausted: false,
                                forcedScreenCaptureKit: forceSCK
                            ),
                            to: jsonlPath
                        )
                    }
                    return
                }
                for app in apps {
                    print("target: \(app.software.displayName) (\(app.matchedBundleIdentifier)) id=\(app.software.id)")
                }

                let chosen: MatchedDJApp
                if let softwareID, let match = apps.first(where: { $0.software.id == softwareID }) {
                    chosen = match
                } else if let softwareID {
                    print("ERROR: requested app '\(softwareID)' is not among shareable targets.")
                    return
                } else {
                    chosen = apps.first(where: { $0.software.id == "serato" }) ?? apps[0]
                }

                print("monitoring: \(chosen.software.displayName) id=\(chosen.software.id)")
                let devices = AudioInputDeviceCatalog.listInputs()
                let runningIDs = Set(apps.map(\.software.id))
                try await service.startMonitoring(
                    bundleIdentifier: chosen.matchedBundleIdentifier,
                    displayName: chosen.software.displayName,
                    softwareID: chosen.software.id,
                    inputDevices: devices,
                    runningSoftwareIDs: runningIDs
                )
                print("backend: \(service.activeBackendKind.displayName)")
                if let device = service.activeVirtualDevice {
                    print(
                        "device: \(device.name) uid=\(device.id) transport=\(device.transportType.archiveLabel)"
                    )
                }
                if let sourceUID = service.activeSourceDeviceUID {
                    print("sourceDeviceUID: \(sourceUID)")
                }
                var peak: Float = 0
                let ticks = max(1, seconds * 5)
                for i in 0..<ticks {
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    let level = service.currentInputLevel()
                    peak = max(peak, level)
                    if i % 5 == 0 {
                        print(String(format: "t=%.1fs level=%.4f", Double(i) * 0.2, level))
                    }
                }
                print(String(format: "peak: %.4f", peak))
                var outcome = "silent_meter"
                var stagingBytes: Int?
                var archivePath: String?
                var libraryReconciled = false
                if peak > 0.01 {
                    let recordingStartedAt = Date()
                    try service.beginRecordingFile()
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    if let result = try service.endRecordingFile(discard: false) {
                        stagingBytes = (try? FileManager.default.attributesOfItem(atPath: result.stagingURL.path)[.size] as? NSNumber)?.intValue
                        print("staging: \(result.stagingURL.path) bytes=\(stagingBytes ?? 0)")
                        let session = try ArchiveService().ingestCapture(
                            stagingURL: result.stagingURL,
                            deviceID: result.deviceID,
                            deviceName: result.deviceName,
                            startedAt: recordingStartedAt,
                            sourceAppID: chosen.software.id,
                            captureRoute: result.captureRoute ?? .appAudio,
                            captureBackend: result.captureBackend ?? service.activeBackendKind.archiveBackend,
                            captureDeviceTransport: result.deviceTransport?.archiveLabel
                        )
                        if let archiveURL = session.archiveURL {
                            archivePath = archiveURL.path
                            print("archive: \(archiveURL.path)")
                            print("metadata: \(ArchiveService().metadataURL(for: archiveURL).path)")
                            let archivedIDs = try SessionLibrary().archivedMetadata().map(\.id)
                            libraryReconciled = archivedIDs.contains(session.id)
                            if libraryReconciled {
                                print("library: found \(session.id.uuidString)")
                            } else {
                                print("library: missing \(session.id.uuidString)")
                            }
                            print("PASS meter+archive \(chosen.software.id)")
                            outcome = "pass_meter_archive"
                        } else {
                            print("ERROR: archive session missing archive URL \(session.id.uuidString)")
                            outcome = "archive_missing_url"
                        }
                    }
                } else {
                    print("SILENT_METER — play audio through system output, or use Input device Capture if the mix is hardware-only.")
                    print("ARMED_OK \(chosen.software.id) — shareable + monitoring started; meter not verified.")
                    outcome = "armed_ok_silent"
                }
                appendJSONL(
                    InvisibleCaptureProbeResult(
                        timestamp: isoFormatter.string(from: Date()),
                        softwareID: chosen.software.id,
                        bundleIdentifier: chosen.matchedBundleIdentifier,
                        backend: service.activeBackendKind.rawValue,
                        sourceDeviceUID: service.activeSourceDeviceUID,
                        peakLevel: peak,
                        outcome: outcome,
                        stagingBytes: stagingBytes,
                        archivePath: archivePath,
                        libraryReconciled: libraryReconciled,
                        applePathExhausted: service.appleAppAudioPathExhausted,
                        forcedScreenCaptureKit: forceSCK
                    ),
                    to: jsonlPath
                )
                await service.stopMonitoring()
                print("DONE jsonl=\(jsonlPath)")
            } catch {
                print("ERROR: \(error)")
                if let softwareID {
                    appendJSONL(
                        InvisibleCaptureProbeResult(
                            timestamp: isoFormatter.string(from: Date()),
                            softwareID: softwareID,
                            bundleIdentifier: "",
                            backend: "error",
                            sourceDeviceUID: nil,
                            peakLevel: 0,
                            outcome: "error:\(error)",
                            stagingBytes: nil,
                            archivePath: nil,
                            libraryReconciled: false,
                            applePathExhausted: service.appleAppAudioPathExhausted,
                            forcedScreenCaptureKit: forceSCK
                        ),
                        to: jsonlPath
                    )
                }
            }
        }

        semaphore.wait()
    }

    /// Parses `app-audio-probe` / `--app-audio-probe` trailing args: optional seconds and/or software id.
    public static func parseArgs(_ args: [String]) -> (softwareID: String?, seconds: Int) {
        var softwareID: String?
        var seconds = 8
        for arg in args {
            if let value = Int(arg), value > 0 {
                seconds = value
            } else if !arg.hasPrefix("-") {
                softwareID = arg
            }
        }
        return (softwareID, seconds)
    }
}
#endif

import Foundation

#if os(macOS)
import AppKit
import CoreAudio

/// Metadata-only probe result for invisible-capture bench scripts.
public struct InvisibleCaptureProbeResult: Encodable, Sendable {
    public let timestamp: String
    public let softwareID: String
    public let bundleIdentifier: String
    public let backend: String
    public let outputModeLabel: String
    public let sourceDeviceUID: String?
    public let outputDeviceUID: String?
    public let peakLevel: Float
    public let rmsLevel: Float
    public let framesWritten: Int64
    public let sampleRate: Double?
    public let channels: Int?
    public let bitDepth: Int?
    public let outcome: String
    public let pass: Bool
    public let stagingBytes: Int?
    public let archivePath: String?
    public let libraryReconciled: Bool
    public let applePathExhausted: Bool
    public let forcedScreenCaptureKit: Bool
    public let probeSeconds: Int
    public let macOSVersion: String
    public let djAppVersion: String?
    public let pioneerInputCount: Int
    public let pioneerInputUIDs: [String]
}

/// Headless App audio Capture probe (shared by `djmemory` CLI and `DJMemoryApp --app-audio-probe`).
public enum AppAudioProbeRunner {
    public static let defaultJSONLPath = "/tmp/djmemory-invisible-capture-results.jsonl"
    public static let defaultProbeSeconds = 30

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
            _ = try? handle.seekToEnd()
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
        let outputModeLabel = ProcessInfo.processInfo.environment["DJMEMORY_OUTPUT_MODE_LABEL"] ?? "UNKNOWN"
        let semaphore = DispatchSemaphore(value: 0)
        let isoFormatter = ISO8601DateFormatter()

        Task {
            defer { semaphore.signal() }
            let permissionGranted = AppAudioCaptureService.screenCapturePermissionGranted()
            print("preflight: \(permissionGranted)")
            if !permissionGranted {
                print("ERROR: Screen & System Audio Recording permission is required. Grant it in System Settings, then rerun.")
                if let softwareID {
                    appendJSONL(
                        failedResult(
                            softwareID: softwareID,
                            seconds: seconds,
                            forceSCK: forceSCK,
                            outputModeLabel: outputModeLabel,
                            isoFormatter: isoFormatter,
                            outcome: "permission_denied"
                        ),
                        to: jsonlPath
                    )
                }
                return
            }

            let service = AppAudioCaptureService()
            do {
                let apps = try await service.listShareableDJApps()
                if apps.isEmpty {
                    print("targets: (none) — open a DJ app, or grant Screen & System Audio Recording.")
                    if let softwareID {
                        appendJSONL(
                            failedResult(
                                softwareID: softwareID,
                                seconds: seconds,
                                forceSCK: forceSCK,
                                outputModeLabel: outputModeLabel,
                                isoFormatter: isoFormatter,
                                outcome: "no_target"
                            ),
                            to: jsonlPath
                        )
                    }
                    return
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

                print("scenario: software=\(chosen.software.id) backend=\(forceSCK ? "screenCaptureKit" : "processAudioTap") outputMode=\(outputModeLabel)")
                if !InvisibleCaptureProbeEvaluator.isExplicitOutputModeLabel(outputModeLabel) {
                    print("ERROR: set DJMEMORY_OUTPUT_MODE_LABEL to an explicit bench scenario (for example system-default or controller-usb). UNKNOWN cannot PASS.")
                    appendJSONL(
                        failedResult(
                            softwareID: chosen.software.id,
                            seconds: seconds,
                            forceSCK: forceSCK,
                            outputModeLabel: outputModeLabel,
                            isoFormatter: isoFormatter,
                            outcome: "unknown_scenario"
                        ),
                        to: jsonlPath
                    )
                    return
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
                    print("device: \(device.name) uid=\(device.id) transport=\(device.transportType.archiveLabel)")
                }
                if let sourceUID = service.activeSourceDeviceUID {
                    print("sourceDeviceUID: \(sourceUID)")
                }
                let pioneerInputs = devices.filter(\.isLikelyPioneerDJHardware)
                let outputDeviceUID = defaultOutputDeviceUID()
                let djAppVersion = appVersion(bundleIdentifier: chosen.matchedBundleIdentifier)
                print("outputMode: \(outputModeLabel)")

                var peak: Float = 0
                var sumSquares: Float = 0
                var sampleCount = 0
                try service.beginRecordingFile()
                let recordingStartedAt = Date()
                let ticks = max(1, seconds * 5)
                for i in 0..<ticks {
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    let level = service.currentInputLevel()
                    peak = max(peak, level)
                    sumSquares += level * level
                    sampleCount += 1
                    if i % 5 == 0 {
                        print(String(format: "t=%.1fs level=%.4f", Double(i) * 0.2, level))
                    }
                }
                let rms = sampleCount > 0 ? sqrt(sumSquares / Float(sampleCount)) : 0
                print(String(format: "peak: %.4f rms: %.4f", peak, rms))

                var framesWritten: Int64 = 0
                var stagingBytes: Int?
                var archivePath: String?
                var libraryReconciled = false
                var wavValid = false
                var sampleRate: Double?
                var channels: Int?
                var bitDepth: Int?
                var archivedPeak: Float = 0
                var signalMeasuredFromArchive = false
                let livePeak = peak

                if let result = try service.endRecordingFile(discard: false) {
                    stagingBytes = (try? FileManager.default.attributesOfItem(atPath: result.stagingURL.path)[.size] as? NSNumber)?.intValue
                    let validation = CaptureAudioFormat.validateReadableWAV(at: result.stagingURL)
                    wavValid = validation.valid
                    framesWritten = validation.frames
                    sampleRate = validation.sampleRate
                    channels = validation.channels
                    bitDepth = validation.bitDepth
                    print("staging: \(result.stagingURL.path) bytes=\(stagingBytes ?? 0) frames=\(framesWritten)")
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
                        archivedPeak = CaptureAudioFormat.peakLevel(at: archiveURL)
                        signalMeasuredFromArchive = true
                        print(String(format: "archivedPeak: %.4f (livePeak=%.4f)", archivedPeak, livePeak))
                        let archivedIDs = try SessionLibrary().archivedMetadata().map(\.id)
                        libraryReconciled = archivedIDs.contains(session.id)
                        print(libraryReconciled ? "library: found \(session.id.uuidString)" : "library: missing \(session.id.uuidString)")
                    }
                }

                let passInput = InvisibleCaptureProbePassInput(
                    peakLevel: archivedPeak,
                    rmsLevel: rms,
                    framesWritten: framesWritten,
                    stagingBytes: stagingBytes,
                    wavValid: wavValid,
                    archivePath: archivePath,
                    libraryReconciled: libraryReconciled,
                    signalMeasuredDuringRecording: signalMeasuredFromArchive,
                    outputModeLabel: outputModeLabel
                )
                let pass = InvisibleCaptureProbeEvaluator.passes(passInput)
                let outcome = InvisibleCaptureProbeEvaluator.outcomeLabel(for: passInput)
                if pass {
                    print("PASS meter+archive \(chosen.software.id)")
                } else {
                    print("FAIL gate \(chosen.software.id) — verify archived WAV signal, scenario label, archive, and library reconciliation.")
                }

                appendJSONL(
                    InvisibleCaptureProbeResult(
                        timestamp: isoFormatter.string(from: Date()),
                        softwareID: chosen.software.id,
                        bundleIdentifier: chosen.matchedBundleIdentifier,
                        backend: service.activeBackendKind.rawValue,
                        outputModeLabel: outputModeLabel,
                        sourceDeviceUID: service.activeSourceDeviceUID,
                        outputDeviceUID: outputDeviceUID ?? "UNKNOWN",
                        peakLevel: archivedPeak,
                        rmsLevel: rms,
                        framesWritten: framesWritten,
                        sampleRate: sampleRate,
                        channels: channels,
                        bitDepth: bitDepth,
                        outcome: outcome,
                        pass: pass,
                        stagingBytes: stagingBytes,
                        archivePath: archivePath,
                        libraryReconciled: libraryReconciled,
                        applePathExhausted: service.appleAppAudioPathExhausted,
                        forcedScreenCaptureKit: forceSCK,
                        probeSeconds: seconds,
                        macOSVersion: ProcessInfo.processInfo.operatingSystemVersionString,
                        djAppVersion: djAppVersion ?? "UNKNOWN",
                        pioneerInputCount: pioneerInputs.count,
                        pioneerInputUIDs: pioneerInputs.map(\.id)
                    ),
                    to: jsonlPath
                )
                await service.stopMonitoring()
                print("DONE jsonl=\(jsonlPath)")
            } catch {
                print("ERROR: \(error)")
                if let softwareID {
                    appendJSONL(
                        failedResult(
                            softwareID: softwareID,
                            seconds: seconds,
                            forceSCK: forceSCK,
                            outputModeLabel: outputModeLabel,
                            isoFormatter: isoFormatter,
                            outcome: "error:\(error)",
                            applePathExhausted: service.appleAppAudioPathExhausted
                        ),
                        to: jsonlPath
                    )
                }
            }
        }

        semaphore.wait()
    }

    private static func failedResult(
        softwareID: String,
        seconds: Int,
        forceSCK: Bool,
        outputModeLabel: String,
        isoFormatter: ISO8601DateFormatter,
        outcome: String,
        applePathExhausted: Bool = false
    ) -> InvisibleCaptureProbeResult {
        InvisibleCaptureProbeResult(
            timestamp: isoFormatter.string(from: Date()),
            softwareID: softwareID,
            bundleIdentifier: "",
            backend: "none",
            outputModeLabel: outputModeLabel,
            sourceDeviceUID: nil,
            outputDeviceUID: defaultOutputDeviceUID() ?? "UNKNOWN",
            peakLevel: 0,
            rmsLevel: 0,
            framesWritten: 0,
            sampleRate: nil,
            channels: nil,
            bitDepth: nil,
            outcome: outcome,
            pass: false,
            stagingBytes: nil,
            archivePath: nil,
            libraryReconciled: false,
            applePathExhausted: applePathExhausted,
            forcedScreenCaptureKit: forceSCK,
            probeSeconds: seconds,
            macOSVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            djAppVersion: appVersion(softwareID: softwareID) ?? "UNKNOWN",
            pioneerInputCount: 0,
            pioneerInputUIDs: []
        )
    }

    /// Parses `app-audio-probe` / `--app-audio-probe` trailing args: optional seconds and/or software id.
    public static func parseArgs(_ args: [String]) -> (softwareID: String?, seconds: Int) {
        var softwareID: String?
        var seconds = defaultProbeSeconds
        for arg in args {
            if let value = Int(arg), value > 0 {
                seconds = value
            } else if !arg.hasPrefix("-") {
                softwareID = arg
            }
        }
        return (softwareID, seconds)
    }

    private static func defaultOutputDeviceUID() -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )
        guard status == noErr, deviceID != kAudioObjectUnknown else { return nil }
        address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var uid: CFString = "" as CFString
        size = UInt32(MemoryLayout<CFString>.size)
        let uidStatus = withUnsafeMutablePointer(to: &uid) { pointer in
            AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, pointer)
        }
        guard uidStatus == noErr else { return nil }
        let value = uid as String
        return value.isEmpty ? nil : value
    }

    private static func appVersion(softwareID: String) -> String? {
        guard let software = SupportedDJSoftware.all.first(where: { $0.id == softwareID }) else { return nil }
        for bundleIdentifier in software.bundleIdentifiers {
            if let version = appVersion(bundleIdentifier: bundleIdentifier) {
                return version
            }
        }
        return nil
    }

    private static func appVersion(bundleIdentifier: String) -> String? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier),
              let bundle = Bundle(url: url)
        else { return nil }
        let shortVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        switch (shortVersion, build) {
        case let (short?, build?) where !short.isEmpty && !build.isEmpty:
            return "\(short) (\(build))"
        case let (short?, _) where !short.isEmpty:
            return short
        case let (_, build?) where !build.isEmpty:
            return build
        default:
            return nil
        }
    }
}
#endif

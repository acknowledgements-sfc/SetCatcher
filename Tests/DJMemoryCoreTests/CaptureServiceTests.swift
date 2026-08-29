import Foundation
import XCTest
@testable import DJMemoryCore

final class CaptureServiceTests: XCTestCase {
    func testStartMonitoringUnknownDeviceThrowsDeviceMissing() throws {
        guard CaptureService.microphonePermissionGranted() else {
            throw XCTSkip("Microphone permission is required to reach device binding.")
        }
        let staging = FileManager.default.temporaryDirectory
            .appendingPathComponent("djmemory-capture-missing-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: staging) }
        let service = CaptureService(stagingDirectory: staging)
        let ghost = AudioInputDevice(
            id: "djmemory-missing-uid-\(UUID().uuidString)",
            name: "Ghost Input",
            manufacturer: "None"
        )
        XCTAssertThrowsError(try service.startMonitoring(device: ghost)) { error in
            XCTAssertEqual(error as? CaptureServiceError, .deviceMissing)
        }
    }

    func testLivePioneerInputRecords16Bit48kCapture() async throws {
        guard ProcessInfo.processInfo.environment["DJMEMORY_LIVE_XZ"] == "1" else {
            throw XCTSkip("Set DJMEMORY_LIVE_XZ=1 for the hardware bench.")
        }
        guard CaptureService.microphonePermissionGranted() else {
            throw XCTSkip("Microphone permission is required for live Input Capture.")
        }
        let device = try XCTUnwrap(
            AudioInputDeviceCatalog.listInputs().first(where: \.isLikelyPioneerDJHardware),
            "No Pioneer-like Core Audio input is present."
        )
        print("LIVE_DEVICE name=\(device.name) manufacturer=\(device.manufacturer) uid=\(device.id)")

        let staging = FileManager.default.temporaryDirectory
            .appendingPathComponent("djmemory-live-xz-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: staging) }

        let service = CaptureService(stagingDirectory: staging)
        try service.startMonitoring(device: device)
        var peak: Float = 0
        for _ in 0..<20 {
            try await Task.sleep(nanoseconds: 100_000_000)
            peak = max(peak, service.currentInputLevel())
        }
        print("LIVE_METER_PEAK \(peak)")
        try service.beginRecordingFile()
        try await Task.sleep(nanoseconds: 6_000_000_000)
        let result = try service.stop()
        XCTAssertEqual(result.deviceName, device.name)
        XCTAssertEqual(result.deviceID, device.id)

        let settings = try AppSettingsStore().load()
        let archiveRootResolution = ArchiveRootResolver.resolve(settings: settings)
        let archive = ArchiveService(
            archiveRoot: archiveRootResolution.url,
            archiveRootBookmarkData: archiveRootResolution.bookmarkData,
            verifyCopies: true
        )
        let session = try archive.ingestCapture(
            stagingURL: result.stagingURL,
            deviceID: result.deviceID,
            deviceName: result.deviceName,
            startedAt: result.startedAt,
            endedAt: result.endedAt
        )
        let archiveURL = try XCTUnwrap(session.archiveURL)
        let validation = CaptureAudioFormat.validateReadableWAV(at: archiveURL)
        let archivedPeak = CaptureAudioFormat.peakLevel(at: archiveURL)
        let signalThreshold = LiveCaptureDetectionConfig.default.signalThreshold
        let libraryIDs = try SessionLibrary(
            archiveRoot: archiveRootResolution.url,
            archiveRootBookmarkData: archiveRootResolution.bookmarkData
        ).archivedMetadata().map(\.id)
        let libraryReconciled = libraryIDs.contains(session.id)
        print(
            "LIVE_AUDIO_VALIDATION valid=\(validation.valid) frames=\(validation.frames) "
                + "sampleRate=\(validation.sampleRate) channels=\(validation.channels) "
                + "bitDepth=\(validation.bitDepth) archivedPeak=\(archivedPeak) "
                + "threshold=\(signalThreshold) libraryReconciled=\(libraryReconciled)"
        )
        let resultPath = ProcessInfo.processInfo.environment["DJMEMORY_LIVE_HARDWARE_RESULT_PATH"]
            ?? "/tmp/djmemory-live-xz-result.txt"
        FileManager.default.createFile(
            atPath: resultPath,
            contents: Data("""
            name=\(device.name)
            manufacturer=\(device.manufacturer)
            uid=\(device.id)
            livePeak=\(peak)
            archivedPeak=\(archivedPeak)
            signalThreshold=\(signalThreshold)
            archive=\(archiveURL.path)
            frames=\(validation.frames)
            sampleRate=\(validation.sampleRate)
            channels=\(validation.channels)
            bitDepth=\(validation.bitDepth)
            wavValid=\(validation.valid)
            libraryReconciled=\(libraryReconciled)
            """.utf8)
        )
        XCTAssertTrue(validation.valid, "Archived capture must be a readable canonical WAV.")
        XCTAssertGreaterThan(validation.frames, 0, "Archived capture must contain audio frames.")
        XCTAssertEqual(validation.sampleRate, CaptureAudioFormat.sampleRate)
        XCTAssertEqual(validation.channels, Int(CaptureAudioFormat.channelCount))
        XCTAssertEqual(validation.bitDepth, CaptureAudioFormat.bitDepth)
        XCTAssertTrue(libraryReconciled, "Archived capture must appear in SessionLibrary.")
        XCTAssertGreaterThanOrEqual(
            peak,
            signalThreshold,
            "Live XDJ input did not reach the required signal threshold."
        )
        XCTAssertGreaterThanOrEqual(
            archivedPeak,
            signalThreshold,
            "Archived XDJ capture is silent or below the required signal threshold."
        )
    }

    func testLiveUserArchiveLinkerGroupsCaptureWithFolder() throws {
        guard ProcessInfo.processInfo.environment["DJMEMORY_LIVE_XZ"] == "1" else {
            throw XCTSkip("Set DJMEMORY_LIVE_XZ=1 for the hardware bench.")
        }
        let settings = try AppSettingsStore().load()
        let archiveRootResolution = ArchiveRootResolver.resolve(settings: settings)
        let metadata = try SessionLibrary(
            archiveRoot: archiveRootResolution.url,
            archiveRootBookmarkData: archiveRootResolution.bookmarkData
        ).archivedMetadata()
        let groups = PerformanceSessionLinker.groups(from: metadata)
        let group = try XCTUnwrap(
            groups.first { group in
                group.primary.originalFilename.contains("DJMemory-xz-bench")
                    && group.hardwareBackup?.originalFilename == "XDJ-XZ.wav"
            },
            "Expected one grouped row with Serato primary and XDJ-XZ hardware backup."
        )
        print("LIVE_GROUP id=\(group.id) primary=\(group.primary.sourceAppID) backup=\(group.hardwareBackup?.sourceAppID ?? "nil")")
        XCTAssertEqual(group.primary.sourceAppID, "serato")
        XCTAssertEqual(group.hardwareBackup?.sourceAppID, SupportedDJSoftware.captureAppID)
        XCTAssertEqual(group.id, group.hardwareBackup?.sessionID) // earliest member is capture
        XCTAssertFalse(groups.contains { $0.primary.originalFilename == "XDJ-XZ.wav" && $0.hardwareBackup == nil })
    }

    func testLiveDiskFullOnTinyVolumeThrowsDiskFull() throws {
        guard ProcessInfo.processInfo.environment["DJMEMORY_LIVE_XZ"] == "1" else {
            throw XCTSkip("Set DJMEMORY_LIVE_XZ=1 for the hardware bench.")
        }
        guard CaptureService.microphonePermissionGranted() else {
            throw XCTSkip("Microphone permission is required to open the capture engine.")
        }
        let device = try XCTUnwrap(
            AudioInputDeviceCatalog.listInputs().first(where: \.isLikelyPioneerDJHardware)
                ?? AudioInputDeviceCatalog.listInputs().first,
            "No audio input is present."
        )
        let volume = URL(fileURLWithPath: "/Volumes/DJMEMFULL", isDirectory: true)
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: volume.path, isDirectory: &isDir), isDir.boolValue else {
            throw XCTSkip("Attach /tmp/djmemory-diskfull.dmg first.")
        }
        let fillURL = volume.appendingPathComponent("fill.bin")
        if !FileManager.default.fileExists(atPath: fillURL.path) {
            let handle = FileHandle(forWritingAtPath: fillURL.path)
                ?? { FileManager.default.createFile(atPath: fillURL.path, contents: nil); return FileHandle(forWritingAtPath: fillURL.path)! }()
            defer { try? handle.close() }
            let chunk = Data(repeating: 0, count: 64 * 1024)
            while true {
                do {
                    try handle.write(contentsOf: chunk)
                } catch {
                    break
                }
            }
        }
        let staging = volume.appendingPathComponent("staging", isDirectory: true)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        let service = CaptureService(stagingDirectory: staging)
        try service.startMonitoring(device: device)
        defer { service.stopMonitoring() }
        XCTAssertThrowsError(try service.beginRecordingFile()) { error in
            XCTAssertEqual(error as? CaptureServiceError, .diskFull)
        }
    }
}

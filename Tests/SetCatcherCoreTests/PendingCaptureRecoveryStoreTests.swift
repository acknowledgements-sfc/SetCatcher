import XCTest
@testable import SetCatcherCore

final class PendingCaptureRecoveryStoreTests: XCTestCase {
    func testRecordRoundTripsWhileStagingFileExists() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let stagingURL = root.appendingPathComponent("capture.wav")
        try Data("wav".utf8).write(to: stagingURL)
        let store = PendingCaptureRecoveryStore(storageURL: root.appendingPathComponent("recovery.json"))
        let record = makeRecord(stagingURL: stagingURL)

        try store.save(record)

        XCTAssertEqual(try store.load(), record)
    }

    func testMissingStagingFileClearsStaleManifest() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let manifestURL = root.appendingPathComponent("recovery.json")
        let store = PendingCaptureRecoveryStore(storageURL: manifestURL)
        try store.save(makeRecord(stagingURL: root.appendingPathComponent("missing.wav")))

        XCTAssertNil(try store.load())
        XCTAssertFalse(FileManager.default.fileExists(atPath: manifestURL.path))
    }

    func testRemoveIsIdempotent() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = PendingCaptureRecoveryStore(storageURL: root.appendingPathComponent("recovery.json"))

        XCTAssertNoThrow(try store.remove())
    }

    private func makeRecord(stagingURL: URL) -> PendingCaptureRecoveryRecord {
        PendingCaptureRecoveryRecord(
            stagingURL: stagingURL,
            deviceID: "device-1",
            deviceName: "DJ Mixer",
            startedAt: Date(timeIntervalSince1970: 100),
            endedAt: Date(timeIntervalSince1970: 160),
            sourceAppID: "serato",
            captureRoute: .appAudio,
            captureBackend: .processAudioTap,
            captureDeviceTransport: "virtual",
            captureInterrupted: true,
            captureInterruptionReason: "App quit"
        )
    }
}

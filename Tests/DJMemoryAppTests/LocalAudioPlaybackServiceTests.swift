import AVFoundation
import XCTest
@testable import DJMemoryApp

@MainActor
final class LocalAudioPlaybackServiceTests: XCTestCase {
    private var tempRoot: URL!

    override func setUp() {
        super.setUp()
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("djmemory-playback-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempRoot)
        tempRoot = nil
        super.tearDown()
    }

    func testLoadsLocalWAVAndClampsSeeking() throws {
        let url = tempRoot.appendingPathComponent("test.wav")
        try writeWAV(to: url)
        let service = LocalAudioPlaybackService()

        try service.load(url: url)
        XCTAssertGreaterThan(service.duration, 0)

        service.seek(to: service.duration + 10)
        XCTAssertEqual(service.currentTime, service.duration - 0.001, accuracy: 0.01)

        service.seek(to: -10)
        XCTAssertEqual(service.currentTime, 0, accuracy: 0.01)
    }

    func testLoadExposesInitialPlaybackState() throws {
        let url = tempRoot.appendingPathComponent("state.wav")
        try writeWAV(to: url)
        let service = LocalAudioPlaybackService()

        try service.load(url: url)

        XCTAssertEqual(service.loadedURL, url)
        XCTAssertFalse(service.isPlaying)
        XCTAssertEqual(service.currentTime, 0, accuracy: 0.01)
        XCTAssertGreaterThan(service.duration, 0)
    }

    func testPlayAndPauseUpdatePlaybackState() throws {
        let url = tempRoot.appendingPathComponent("playback.wav")
        try writeWAV(to: url, frameCount: 48_000)
        let service = LocalAudioPlaybackService()
        try service.load(url: url)

        service.play()
        XCTAssertTrue(service.isPlaying)

        service.pause()
        XCTAssertFalse(service.isPlaying)
    }

    func testStopClearsLoadedPlaybackState() throws {
        let url = tempRoot.appendingPathComponent("stop.wav")
        try writeWAV(to: url)
        let service = LocalAudioPlaybackService()
        try service.load(url: url)
        service.seek(to: 0.05)

        service.stop()

        XCTAssertNil(service.loadedURL)
        XCTAssertFalse(service.isPlaying)
        XCTAssertEqual(service.currentTime, 0)
        XCTAssertEqual(service.duration, 0)
    }

    func testReloadReplacesURLAndResetsPosition() throws {
        let firstURL = tempRoot.appendingPathComponent("first.wav")
        let secondURL = tempRoot.appendingPathComponent("second.wav")
        try writeWAV(to: firstURL, frameCount: 48_000)
        try writeWAV(to: secondURL, frameCount: 24_000)
        let service = LocalAudioPlaybackService()
        try service.load(url: firstURL)
        service.seek(to: 0.5)

        try service.load(url: secondURL)

        XCTAssertEqual(service.loadedURL, secondURL)
        XCTAssertFalse(service.isPlaying)
        XCTAssertEqual(service.currentTime, 0, accuracy: 0.01)
        XCTAssertEqual(service.duration, 0.5, accuracy: 0.01)
    }

    func testMissingFileReturnsCalmError() {
        let service = LocalAudioPlaybackService()
        XCTAssertThrowsError(try service.load(url: tempRoot.appendingPathComponent("missing.wav"))) { error in
            XCTAssertEqual(error as? LocalAudioPlaybackError, .fileMissing)
            XCTAssertEqual(
                error.localizedDescription,
                "This recording is no longer available at its archive location."
            )
        }
    }

    func testCorruptFileReturnsUnreadableError() throws {
        let url = tempRoot.appendingPathComponent("corrupt.wav")
        try Data("not audio".utf8).write(to: url)
        let service = LocalAudioPlaybackService()
        XCTAssertThrowsError(try service.load(url: url)) { error in
            XCTAssertEqual(error as? LocalAudioPlaybackError, .unreadableFile)
            XCTAssertEqual(
                error.localizedDescription,
                "This recording could not be opened for playback. The archived file was not changed."
            )
        }
    }

    private func writeWAV(to url: URL, frameCount: AVAudioFrameCount = 4_800) throws {
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 48_000,
            AVNumberOfChannelsKey: 2,
            AVLinearPCMBitDepthKey: 24,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]
        let file = try AVAudioFile(forWriting: url, settings: settings)
        let format = file.processingFormat
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount))
        buffer.frameLength = frameCount
        try file.write(from: buffer)
    }
}

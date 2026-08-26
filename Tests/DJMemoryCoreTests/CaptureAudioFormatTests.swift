import AVFoundation
import XCTest
@testable import DJMemoryCore

final class CaptureAudioFormatTests: XCTestCase {
    func testWriteSettingsAre16Bit48kStereo() {
        let settings = CaptureAudioFormat.writeSettings
        XCTAssertEqual(settings[AVSampleRateKey] as? Double, 48_000)
        XCTAssertEqual(settings[AVNumberOfChannelsKey] as? Int, 2)
        XCTAssertEqual(settings[AVLinearPCMBitDepthKey] as? Int, 16)
        XCTAssertEqual(settings[AVLinearPCMIsFloatKey] as? Bool, false)
        XCTAssertEqual(settings[AVFormatIDKey] as? AudioFormatID, kAudioFormatLinearPCM)
    }

    func testWriteFormatAndConverterCanBeCreated() throws {
        let write = try XCTUnwrap(CaptureAudioFormat.writeFormat())
        let processing = try XCTUnwrap(CaptureAudioFormat.processingFormat())
        XCTAssertEqual(write.sampleRate, 48_000, accuracy: 0.1)
        XCTAssertEqual(Int(write.streamDescription.pointee.mBitsPerChannel), 16)
        XCTAssertNotNil(CaptureAudioFormat.makeConverter(from: processing, to: write))
    }

    func testCapturePCMWriterConvertsSilenceBuffer() throws {
        let processing = try XCTUnwrap(CaptureAudioFormat.processingFormat())
        let frameLength: AVAudioFrameCount = 480
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: processing, frameCapacity: frameLength))
        buffer.frameLength = frameLength
        if let channels = buffer.floatChannelData {
            for channel in 0..<Int(processing.channelCount) {
                memset(channels[channel], 0, Int(frameLength) * MemoryLayout<Float>.size)
            }
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("djmemory-pcm-writer-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        // AVAudioFile.processingFormat is typically Float32; convert into that for a round-trip write.
        let audioFile = try AVAudioFile(
            forWriting: tempURL,
            settings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: CaptureAudioFormat.sampleRate,
                AVNumberOfChannelsKey: Int(CaptureAudioFormat.channelCount),
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: true
            ]
        )
        let writeFormat = audioFile.processingFormat
        let converter = try XCTUnwrap(CaptureAudioFormat.makeConverter(from: processing, to: writeFormat))
        let errorDetail = CapturePCMWriter.convertAndWrite(
            buffer: buffer,
            converter: converter,
            writeFormat: writeFormat,
            audioFile: audioFile
        )
        XCTAssertNil(errorDetail)
        XCTAssertGreaterThan(audioFile.length, 0)
    }

    /// Pre-roll flush path: buffers are converted while watching, retained, then written later when
    /// the file opens. Converting up front and writing afterwards must round-trip the same frames.
    func testConvertThenDeferredWriteRoundTripsFrames() throws {
        let processing = try XCTUnwrap(CaptureAudioFormat.processingFormat())
        let frameLength: AVAudioFrameCount = 512

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("djmemory-preroll-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let audioFile = try AVAudioFile(forWriting: tempURL, settings: CaptureAudioFormat.writeSettings)
        let writeFormat = audioFile.processingFormat
        let converter = try XCTUnwrap(CaptureAudioFormat.makeConverter(from: processing, to: writeFormat))

        // Convert three "pre-roll" buffers before any write happens (as the ring does while watching).
        var converted: [AVAudioPCMBuffer] = []
        for _ in 0..<3 {
            let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: processing, frameCapacity: frameLength))
            buffer.frameLength = frameLength
            if let channels = buffer.floatChannelData {
                for channel in 0..<Int(processing.channelCount) {
                    for frame in 0..<Int(frameLength) { channels[channel][frame] = 0.1 }
                }
            }
            let result = CapturePCMWriter.convert(buffer: buffer, converter: converter, writeFormat: writeFormat)
            XCTAssertNil(result.error)
            converted.append(try XCTUnwrap(result.buffer))
        }

        // Then flush them into the file (as beginRecordingFile does), verifying the format matches.
        XCTAssertTrue(writeFormat.isEqual(CaptureAudioFormat.processingFormat()!))
        var totalFrames: AVAudioFramePosition = 0
        for buffer in converted {
            XCTAssertNil(CapturePCMWriter.write(buffer: buffer, to: audioFile))
            totalFrames += AVAudioFramePosition(buffer.frameLength)
        }
        XCTAssertEqual(audioFile.length, totalFrames)
    }
}

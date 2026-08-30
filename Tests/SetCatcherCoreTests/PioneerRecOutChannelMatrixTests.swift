import AVFoundation
import XCTest
@testable import SetCatcherCore

final class PioneerRecOutChannelMatrixTests: XCTestCase {
    func testHypothesizedPairsMatchRoutingDoc() {
        XCTAssertEqual(
            PioneerRecOutChannelMatrix.hypothesizedPair(forDeviceName: "XDJ-XZ"),
            HardwareStereoChannelPair(leftIndex: 4, rightIndex: 5)
        )
        XCTAssertEqual(
            PioneerRecOutChannelMatrix.hypothesizedPair(forDeviceName: "Pioneer DJ XDJ-RX2"),
            HardwareStereoChannelPair(leftIndex: 2, rightIndex: 3)
        )
        XCTAssertEqual(
            PioneerRecOutChannelMatrix.hypothesizedPair(forDeviceName: "XDJ-RX3"),
            HardwareStereoChannelPair(leftIndex: 4, rightIndex: 5)
        )
        XCTAssertEqual(
            PioneerRecOutChannelMatrix.hypothesizedPair(forDeviceName: "DJM-V10"),
            HardwareStereoChannelPair(leftIndex: 10, rightIndex: 11)
        )
        XCTAssertEqual(
            PioneerRecOutChannelMatrix.hypothesizedPair(forDeviceName: "DJM-A9"),
            HardwareStereoChannelPair(leftIndex: 8, rightIndex: 9)
        )
        XCTAssertEqual(
            PioneerRecOutChannelMatrix.hypothesizedPair(forDeviceName: "DJM-900NXS2"),
            HardwareStereoChannelPair(leftIndex: 8, rightIndex: 9)
        )
        XCTAssertNil(PioneerRecOutChannelMatrix.hypothesizedPair(forDeviceName: "MacBook Pro Microphone"))
    }

    func testValidateFailsWhenChannelCountTooSmall() {
        let pair = HardwareStereoChannelPair(leftIndex: 8, rightIndex: 9)
        switch PioneerRecOutChannelMatrix.validate(pair, channelCount: 8) {
        case .success:
            XCTFail("Expected out-of-range failure for 8-channel stream needing 9/10")
        case .failure(let error):
            XCTAssertEqual(
                error,
                .channelCountTooSmall(pairLabel: "9/10", required: 10, actual: 8)
            )
            XCTAssertTrue(error.message.contains("9/10"), error.message)
            XCTAssertTrue(error.message.contains("10 input channels"), error.message)
            XCTAssertTrue(error.message.contains("exposes 8"), error.message)
        }
    }

    func testXDJXZMeasuredPairFitsEightChannelStream() throws {
        let result = try PioneerRecOutChannelMatrix.resolvedPair(
            forDeviceName: "XDJ-XZ",
            channelCount: 8
        ).get()
        XCTAssertEqual(result, HardwareStereoChannelPair(leftIndex: 4, rightIndex: 5))
    }

    func testResolvedPairNilForUnknownDevice() throws {
        let result = try PioneerRecOutChannelMatrix.resolvedPair(
            forDeviceName: "USB Audio Interface",
            channelCount: 2
        ).get()
        XCTAssertNil(result)
    }

    func testResolvedPairSucceedsWhenInRange() throws {
        let result = try PioneerRecOutChannelMatrix.resolvedPair(
            forDeviceName: "XDJ-RX3",
            channelCount: 6
        ).get()
        XCTAssertEqual(result, HardwareStereoChannelPair(leftIndex: 4, rightIndex: 5))
    }
}

final class CaptureChannelPairExtractorTests: XCTestCase {
    private func multiChannelFloatFormat(channels: AVAudioChannelCount, sampleRate: Double) throws -> AVAudioFormat {
        let tag = AudioChannelLayoutTag(kAudioChannelLayoutTag_DiscreteInOrder | UInt32(channels))
        let layout = try XCTUnwrap(AVAudioChannelLayout(layoutTag: tag))
        return try XCTUnwrap(
            AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: sampleRate,
                interleaved: false,
                channelLayout: layout
            )
        )
    }

    func testExtractStereoFromEightChannelBufferPansChosenPair() throws {
        let channelCount = 8
        let frames = 32
        let format = try multiChannelFloatFormat(channels: AVAudioChannelCount(channelCount), sampleRate: 44_100)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)))
        buffer.frameLength = AVAudioFrameCount(frames)
        let channels = try XCTUnwrap(buffer.floatChannelData)
        for channel in 0..<channelCount {
            for frame in 0..<frames {
                channels[channel][frame] = Float(channel + 1) * 0.1
            }
        }

        // Simulate an 8ch device where “REC OUT” is mistakenly hypothesized as 9/10 —
        // use an in-range pair 3/4 (indexes 2/3) for the extract unit test.
        let pair = HardwareStereoChannelPair(leftIndex: 2, rightIndex: 3)
        let stereo = try XCTUnwrap(CaptureChannelPairExtractor.extractStereo(from: buffer, pair: pair))
        XCTAssertEqual(stereo.format.channelCount, 2)
        XCTAssertEqual(Int(stereo.frameLength), frames)
        let out = try XCTUnwrap(stereo.floatChannelData)
        for frame in 0..<frames {
            XCTAssertEqual(out[0][frame], 0.3, accuracy: 0.0001)
            XCTAssertEqual(out[1][frame], 0.4, accuracy: 0.0001)
        }
        XCTAssertEqual(CaptureChannelPairExtractor.peakLevel(of: stereo), 0.4, accuracy: 0.0001)
    }

    func testExtractReturnsNilWhenPairOutOfRange() throws {
        let format = try multiChannelFloatFormat(channels: 8, sampleRate: 44_100)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 16))
        buffer.frameLength = 16
        let pair = HardwareStereoChannelPair(leftIndex: 8, rightIndex: 9)
        XCTAssertNil(CaptureChannelPairExtractor.extractStereo(from: buffer, pair: pair))
    }

    func testExtractFromTenChannelBufferUsesIndexesEightAndNine() throws {
        let channelCount = 10
        let frames = 8
        let format = try multiChannelFloatFormat(channels: AVAudioChannelCount(channelCount), sampleRate: 48_000)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)))
        buffer.frameLength = AVAudioFrameCount(frames)
        let channels = try XCTUnwrap(buffer.floatChannelData)
        for channel in 0..<channelCount {
            for frame in 0..<frames {
                channels[channel][frame] = Float(channel)
            }
        }
        let pair = HardwareStereoChannelPair(leftIndex: 8, rightIndex: 9)
        let stereo = try XCTUnwrap(CaptureChannelPairExtractor.extractStereo(from: buffer, pair: pair))
        let out = try XCTUnwrap(stereo.floatChannelData)
        for frame in 0..<frames {
            XCTAssertEqual(out[0][frame], 8, accuracy: 0.0001)
            XCTAssertEqual(out[1][frame], 9, accuracy: 0.0001)
        }
    }
}

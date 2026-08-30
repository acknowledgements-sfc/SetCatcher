import XCTest
@testable import SetCatcherCore

final class CaptureDSPTests: XCTestCase {
    func testInterleavedDeinterleaveAndRMSMatchesScalarImplementation() {
        let frameCount = 257
        let sourceChannelCount = 3
        let destinationChannelCount = 4
        let interleaved = seededSamples(count: frameCount * sourceChannelCount, seed: 0xD5A0_2026)

        let expected = scalarInterleaved(
            interleaved,
            frameCount: frameCount,
            sourceChannelCount: sourceChannelCount,
            destinationChannelCount: destinationChannelCount
        )
        let actual = acceleratedInterleaved(
            interleaved,
            frameCount: frameCount,
            sourceChannelCount: sourceChannelCount,
            destinationChannelCount: destinationChannelCount
        )

        assertSamplesEqual(actual.planar, expected.planar)
        XCTAssertEqual(actual.rms, expected.rms, accuracy: 1e-6)
        XCTAssertEqual(CaptureDSP.inputLevel(rms: actual.rms), CaptureDSP.inputLevel(rms: expected.rms), accuracy: 1e-6)
    }

    func testPlanarCopyAndRMSMatchesScalarImplementation() {
        let frameCount = 193
        let sourceChannelCount = 2
        let destinationChannelCount = 3
        let planar = seededSamples(count: frameCount * sourceChannelCount, seed: 0xC0FF_EE)

        let expected = scalarPlanar(
            planar,
            frameCount: frameCount,
            sourceChannelCount: sourceChannelCount,
            destinationChannelCount: destinationChannelCount
        )
        let actual = acceleratedPlanar(
            planar,
            frameCount: frameCount,
            sourceChannelCount: sourceChannelCount,
            destinationChannelCount: destinationChannelCount
        )

        assertSamplesEqual(actual.planar, expected.planar)
        XCTAssertEqual(actual.rms, expected.rms, accuracy: 1e-6)
    }

    func testSingleChannelInputLevelMatchesScalarImplementation() throws {
        let samples = seededSamples(count: 513, seed: 0x1234_ABCD)
        let expectedRMS = scalarRMS(samples)
        let actualLevel = samples.withUnsafeBufferPointer { buffer in
            CaptureDSP.inputLevel(samples: buffer.baseAddress!, count: samples.count)
        }

        XCTAssertEqual(try XCTUnwrap(actualLevel), CaptureDSP.inputLevel(rms: expectedRMS), accuracy: 1e-6)
    }

    private func acceleratedInterleaved(
        _ interleaved: [Float],
        frameCount: Int,
        sourceChannelCount: Int,
        destinationChannelCount: Int
    ) -> (planar: [Float], rms: Float) {
        var planar = [Float](repeating: 0, count: frameCount * destinationChannelCount)
        var meter = CaptureDSP.MeanSquareAccumulator()
        interleaved.withUnsafeBufferPointer { source in
            planar.withUnsafeMutableBufferPointer { destination in
                for channel in 0..<destinationChannelCount {
                    let sourceChannel = min(channel, sourceChannelCount - 1)
                    meter.add(
                        meanSquare: CaptureDSP.copyInterleavedChannelAndMeasure(
                            from: source.baseAddress!,
                            sourceChannel: sourceChannel,
                            sourceChannelCount: sourceChannelCount,
                            frameCount: frameCount,
                            to: destination.baseAddress!.advanced(by: channel * frameCount)
                        ),
                        count: frameCount
                    )
                }
            }
        }
        return (planar, meter.rms!)
    }

    private func scalarInterleaved(
        _ interleaved: [Float],
        frameCount: Int,
        sourceChannelCount: Int,
        destinationChannelCount: Int
    ) -> (planar: [Float], rms: Float) {
        var planar = [Float](repeating: 0, count: frameCount * destinationChannelCount)
        var sumSquares: Float = 0
        var sampleCount = 0
        for frame in 0..<frameCount {
            for channel in 0..<destinationChannelCount {
                let sourceChannel = min(channel, sourceChannelCount - 1)
                let sample = interleaved[frame * sourceChannelCount + sourceChannel]
                planar[channel * frameCount + frame] = sample
                sumSquares += sample * sample
                sampleCount += 1
            }
        }
        return (planar, sqrt(sumSquares / Float(sampleCount)))
    }

    private func acceleratedPlanar(
        _ sourcePlanar: [Float],
        frameCount: Int,
        sourceChannelCount: Int,
        destinationChannelCount: Int
    ) -> (planar: [Float], rms: Float) {
        var planar = [Float](repeating: 0, count: frameCount * destinationChannelCount)
        var meter = CaptureDSP.MeanSquareAccumulator()
        sourcePlanar.withUnsafeBufferPointer { source in
            planar.withUnsafeMutableBufferPointer { destination in
                for channel in 0..<destinationChannelCount {
                    let sourceChannel = min(channel, sourceChannelCount - 1)
                    let count = frameCount
                    meter.add(
                        meanSquare: CaptureDSP.copyPlanarChannelAndMeasure(
                            from: source.baseAddress!.advanced(by: sourceChannel * frameCount),
                            count: count,
                            to: destination.baseAddress!.advanced(by: channel * frameCount)
                        ),
                        count: count
                    )
                }
            }
        }
        return (planar, meter.rms!)
    }

    private func scalarPlanar(
        _ sourcePlanar: [Float],
        frameCount: Int,
        sourceChannelCount: Int,
        destinationChannelCount: Int
    ) -> (planar: [Float], rms: Float) {
        var planar = [Float](repeating: 0, count: frameCount * destinationChannelCount)
        var sumSquares: Float = 0
        var sampleCount = 0
        for channel in 0..<destinationChannelCount {
            let sourceChannel = min(channel, sourceChannelCount - 1)
            for frame in 0..<frameCount {
                let sample = sourcePlanar[sourceChannel * frameCount + frame]
                planar[channel * frameCount + frame] = sample
                sumSquares += sample * sample
                sampleCount += 1
            }
        }
        return (planar, sqrt(sumSquares / Float(sampleCount)))
    }

    private func scalarRMS(_ samples: [Float]) -> Float {
        var sumSquares: Float = 0
        for sample in samples {
            sumSquares += sample * sample
        }
        return sqrt(sumSquares / Float(samples.count))
    }

    private func seededSamples(count: Int, seed: UInt64) -> [Float] {
        var state = seed
        return (0..<count).map { _ in
            state ^= state << 13
            state ^= state >> 7
            state ^= state << 17
            let bucket = Int(state % 20_001) - 10_000
            return Float(bucket) / 10_000
        }
    }

    private func assertSamplesEqual(_ actual: [Float], _ expected: [Float], file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(actual.count, expected.count, file: file, line: line)
        for index in actual.indices {
            XCTAssertEqual(actual[index], expected[index], accuracy: 1e-6, "sample[\(index)]", file: file, line: line)
        }
    }
}

import Accelerate
import Foundation

/// Small, testable DSP primitives shared by live capture paths.
///
/// These helpers deliberately operate on raw `Float` buffers so the hot CoreAudio /
/// ScreenCaptureKit callbacks can use Accelerate without pulling live hardware into tests.
enum CaptureDSP {
    private static let inputLevelScale: Float = 4

    static func inputLevel(rms: Float) -> Float {
        guard rms.isFinite else { return 0 }
        return min(1, max(0, rms * inputLevelScale))
    }

    static func inputLevel(samples: UnsafePointer<Float>, count: Int, stride: Int = 1) -> Float? {
        guard let rms = rms(samples: samples, count: count, stride: stride) else { return nil }
        return inputLevel(rms: rms)
    }

    static func rms(samples: UnsafePointer<Float>, count: Int, stride: Int = 1) -> Float? {
        guard let meanSquare = meanSquare(samples: samples, count: count, stride: stride) else { return nil }
        return sqrt(meanSquare)
    }

    static func meanSquare(samples: UnsafePointer<Float>, count: Int, stride: Int = 1) -> Float? {
        guard count > 0, stride > 0 else { return nil }
        var meanSquare: Float = 0
        vDSP_measqv(samples, vDSP_Stride(stride), &meanSquare, vDSP_Length(count))
        return meanSquare
    }

    /// Absolute peak magnitude over a strided float buffer.
    static func peakAbsolute(samples: UnsafePointer<Float>, count: Int, stride: Int = 1) -> Float? {
        guard count > 0, stride > 0 else { return nil }
        var peak: Float = 0
        vDSP_maxmgv(samples, vDSP_Stride(stride), &peak, vDSP_Length(count))
        return peak
    }

    static func copyInterleavedChannel(
        from source: UnsafePointer<Float>,
        sourceChannel: Int,
        sourceChannelCount: Int,
        frameCount: Int,
        to destination: UnsafeMutablePointer<Float>
    ) {
        guard frameCount > 0, sourceChannelCount > 0 else { return }
        let boundedSourceChannel = min(max(0, sourceChannel), sourceChannelCount - 1)
        let channelSource = source.advanced(by: boundedSourceChannel)
        vDSP_mmov(
            channelSource,
            destination,
            1,
            vDSP_Length(frameCount),
            vDSP_Length(sourceChannelCount),
            1
        )
    }

    /// Copies one strided channel from an interleaved source into one planar destination channel.
    ///
    /// Returns the copied channel's mean square so callers can build an RMS meter without a
    /// second scalar pass over the samples.
    @discardableResult
    static func copyInterleavedChannelAndMeasure(
        from source: UnsafePointer<Float>,
        sourceChannel: Int,
        sourceChannelCount: Int,
        frameCount: Int,
        to destination: UnsafeMutablePointer<Float>
    ) -> Float? {
        guard frameCount > 0, sourceChannelCount > 0 else { return nil }
        let boundedSourceChannel = min(max(0, sourceChannel), sourceChannelCount - 1)
        copyInterleavedChannel(
            from: source,
            sourceChannel: boundedSourceChannel,
            sourceChannelCount: sourceChannelCount,
            frameCount: frameCount,
            to: destination
        )
        return meanSquare(samples: source.advanced(by: boundedSourceChannel), count: frameCount, stride: sourceChannelCount)
    }

    static func copyPlanarChannel(
        from source: UnsafePointer<Float>,
        count: Int,
        to destination: UnsafeMutablePointer<Float>
    ) {
        guard count > 0 else { return }
        destination.update(from: source, count: count)
    }

    /// Copies one non-interleaved source channel into one planar destination channel.
    ///
    /// Returns the copied channel's mean square so callers can build an RMS meter without a
    /// second scalar pass over the samples.
    @discardableResult
    static func copyPlanarChannelAndMeasure(
        from source: UnsafePointer<Float>,
        count: Int,
        to destination: UnsafeMutablePointer<Float>
    ) -> Float? {
        guard count > 0 else { return nil }
        copyPlanarChannel(from: source, count: count, to: destination)
        return meanSquare(samples: source, count: count)
    }

    struct MeanSquareAccumulator {
        private var weightedMeanSquares: Float = 0
        private var sampleCount = 0

        mutating func add(meanSquare: Float?, count: Int) {
            guard let meanSquare, meanSquare.isFinite, count > 0 else { return }
            weightedMeanSquares += meanSquare * Float(count)
            sampleCount += count
        }

        mutating func add(samples: UnsafePointer<Float>, count: Int, stride: Int = 1) {
            add(meanSquare: CaptureDSP.meanSquare(samples: samples, count: count, stride: stride), count: count)
        }

        var rms: Float? {
            guard sampleCount > 0 else { return nil }
            return sqrt(weightedMeanSquares / Float(sampleCount))
        }

        var inputLevel: Float? {
            guard let rms else { return nil }
            return CaptureDSP.inputLevel(rms: rms)
        }
    }
}

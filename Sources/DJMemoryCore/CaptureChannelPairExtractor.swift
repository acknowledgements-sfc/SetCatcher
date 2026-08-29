import AVFoundation
import Foundation

/// Copies two channels from a multi-channel float PCM buffer into a stereo float32 buffer.
///
/// This is explicit REC OUT selection — not an `AVAudioMixerNode` downmix of every bus.
public enum CaptureChannelPairExtractor {
    /// Extracts `leftIndex` / `rightIndex` (0-based) into a non-interleaved stereo float32 buffer
    /// at the source sample rate. Returns `nil` when indexes are out of range or allocation fails.
    public static func extractStereo(
        from buffer: AVAudioPCMBuffer,
        pair: HardwareStereoChannelPair
    ) -> AVAudioPCMBuffer? {
        let channelCount = Int(buffer.format.channelCount)
        guard pair.leftIndex >= 0,
              pair.rightIndex >= 0,
              pair.leftIndex < channelCount,
              pair.rightIndex < channelCount
        else { return nil }

        let frameLength = buffer.frameLength
        guard frameLength > 0 else { return nil }

        guard let stereoFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: buffer.format.sampleRate,
            channels: 2,
            interleaved: false
        ),
            let output = AVAudioPCMBuffer(pcmFormat: stereoFormat, frameCapacity: frameLength)
        else { return nil }

        output.frameLength = frameLength
        guard let destination = output.floatChannelData else { return nil }

        let frames = Int(frameLength)
        if buffer.format.isInterleaved {
            guard let interleaved = buffer.floatChannelData?[0] else { return nil }
            for frame in 0..<frames {
                let base = frame * channelCount
                destination[0][frame] = interleaved[base + pair.leftIndex]
                destination[1][frame] = interleaved[base + pair.rightIndex]
            }
        } else {
            guard let sources = buffer.floatChannelData else { return nil }
            destination[0].update(from: sources[pair.leftIndex], count: frames)
            destination[1].update(from: sources[pair.rightIndex], count: frames)
        }
        return output
    }

    /// Peak absolute level across the extracted stereo pair (for live metering).
    public static func peakLevel(of buffer: AVAudioPCMBuffer) -> Float {
        guard let channels = buffer.floatChannelData else { return 0 }
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return 0 }
        var peak: Float = 0
        let channelCount = Int(buffer.format.channelCount)
        for channel in 0..<channelCount {
            if let channelPeak = CaptureDSP.peakAbsolute(samples: channels[channel], count: frames) {
                peak = max(peak, channelPeak)
            }
        }
        return peak
    }
}

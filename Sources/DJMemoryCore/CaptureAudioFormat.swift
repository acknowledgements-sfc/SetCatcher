import AVFoundation
import Foundation

/// Canonical capture write format: 16-bit linear PCM stereo at 48 kHz.
///
/// Was 24-bit. `AVAudioFile` writing packed 24-bit integer PCM (`AVLinearPCMBitDepthKey: 24`)
/// produced consistently corrupted audio across the whole recording, on both the app-audio and
/// input-device capture paths and independent of the DSP vectorization work — 24-bit doesn't
/// align to a byte/word boundary the way 16-bit does, and Float32→Int24 packing has known,
/// longstanding bugs in AVFoundation. 16-bit is the standard, extensively-exercised path.
public enum CaptureAudioFormat {
    public static let sampleRate: Double = 48_000
    public static let channelCount: AVAudioChannelCount = 2
    public static let bitDepth: Int = 16

    public static var writeSettings: [String: Any] {
        [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: Int(channelCount),
            AVLinearPCMBitDepthKey: bitDepth,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]
    }

    public static func writeFormat() -> AVAudioFormat? {
        AVAudioFormat(settings: writeSettings)
    }

    /// Float32 non-interleaved processing format at the capture sample rate (metering / silence).
    public static func processingFormat(channels: AVAudioChannelCount = channelCount) -> AVAudioFormat? {
        AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: channels,
            interleaved: false
        )
    }

    public static func makeConverter(from source: AVAudioFormat, to destination: AVAudioFormat) -> AVAudioConverter? {
        AVAudioConverter(from: source, to: destination)
    }

    /// Validates a readable, non-empty WAV at the canonical capture format.
    public static func validateReadableWAV(at url: URL) -> (valid: Bool, frames: Int64, sampleRate: Double, channels: Int, bitDepth: Int) {
        guard let file = try? AVAudioFile(forReading: url),
              file.length > 0,
              let format = writeFormat()
        else { return (false, 0, 0, 0, 0) }
        let matches = file.processingFormat.sampleRate == format.sampleRate
            && file.processingFormat.channelCount == format.channelCount
        return (
            valid: matches,
            frames: file.length,
            sampleRate: file.processingFormat.sampleRate,
            channels: Int(file.processingFormat.channelCount),
            bitDepth: bitDepth
        )
    }

    /// Frames per chunk when scanning archived WAV samples for peak level.
    public static let peakScanFrameCapacity: AVAudioFrameCount = 4_096

    /// Absolute peak sample level from an archived WAV using bounded chunked reads.
    /// Returns `0` when the file cannot be read or contains no frames.
    public static func peakLevel(
        at url: URL,
        frameCapacity: AVAudioFrameCount = peakScanFrameCapacity
    ) -> Float {
        guard let file = try? AVAudioFile(forReading: url), file.length > 0 else { return 0 }
        let format = file.processingFormat
        let capacity = max(1, frameCapacity)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return 0 }

        var peak: Float = 0
        while file.framePosition < file.length {
            let remaining = AVAudioFrameCount(file.length - file.framePosition)
            let framesToRead = min(capacity, remaining)
            do {
                try file.read(into: buffer, frameCount: framesToRead)
            } catch {
                break
            }
            guard buffer.frameLength > 0 else { break }
            let frameCount = Int(buffer.frameLength)
            let channelCount = Int(format.channelCount)
            guard let channels = buffer.floatChannelData else { break }
            for channel in 0..<channelCount {
                if let channelPeak = CaptureDSP.peakAbsolute(
                    samples: channels[channel],
                    count: frameCount
                ) {
                    peak = max(peak, channelPeak)
                }
            }
        }
        return peak
    }
}

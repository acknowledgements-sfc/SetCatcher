import AVFoundation
import Foundation

/// Shared convert-and-write path for Capture PCM buffers (input device + app audio).
public enum CapturePCMWriter {
    /// Converts `buffer` through `converter` into `writeFormat` and writes to `audioFile`.
    /// - Returns: Error detail (without a "Capture" / "App audio Capture" prefix), or `nil` on success.
    public static func convertAndWrite(
        buffer: AVAudioPCMBuffer,
        converter: AVAudioConverter,
        writeFormat: AVAudioFormat,
        audioFile: AVAudioFile
    ) -> String? {
        let result = convert(buffer: buffer, converter: converter, writeFormat: writeFormat)
        if let detail = result.error { return detail }
        guard let converted = result.buffer else { return "could not convert to 16-bit / 48 kHz." }
        return write(buffer: converted, to: audioFile)
    }

    /// Converts `buffer` through `converter` into a freshly-allocated `writeFormat` buffer.
    /// - Returns: The converted buffer on success, or an error detail (without a "Capture" prefix).
    public static func convert(
        buffer: AVAudioPCMBuffer,
        converter: AVAudioConverter,
        writeFormat: AVAudioFormat
    ) -> (buffer: AVAudioPCMBuffer?, error: String?) {
        let ratio = writeFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 32
        guard let converted = AVAudioPCMBuffer(pcmFormat: writeFormat, frameCapacity: max(capacity, 1)) else {
            return (nil, "could not allocate a 16-bit / 48 kHz buffer.")
        }

        var error: NSError?
        var provided = false
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            if provided {
                outStatus.pointee = .noDataNow
                return nil
            }
            provided = true
            outStatus.pointee = .haveData
            return buffer
        }
        let status = converter.convert(to: converted, error: &error, withInputFrom: inputBlock)
        if status == .error || converted.frameLength == 0 {
            return (nil, "could not convert to 16-bit / 48 kHz: \(error?.localizedDescription ?? "unknown error").")
        }
        return (converted, nil)
    }

    /// Writes an already-converted `writeFormat` buffer to `audioFile`.
    /// - Returns: An error detail (without a "Capture" prefix), or `nil` on success.
    public static func write(buffer: AVAudioPCMBuffer, to audioFile: AVAudioFile) -> String? {
        do {
            try audioFile.write(from: buffer)
            return nil
        } catch {
            let nsError = error as NSError
            return "could not write audio: \(error.localizedDescription) [\(nsError.domain)#\(nsError.code)]"
        }
    }

    /// Buffer/file format diagnostics. Built only for the first write failure of a take.
    public static func formatContext(buffer: AVAudioPCMBuffer, file: AVAudioFile) -> String {
        " buffer=\(buffer.format) file=\(file.processingFormat)"
    }
}

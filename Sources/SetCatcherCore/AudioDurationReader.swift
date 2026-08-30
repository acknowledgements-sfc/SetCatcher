import AVFoundation
import Foundation

public protocol AudioDurationReading {
    func durationSeconds(for url: URL) -> Double?
}

public struct AudioDurationReader: AudioDurationReading {
    public init() {}

    public func durationSeconds(for url: URL) -> Double? {
        guard
            let audioFile = try? AVAudioFile(forReading: url),
            audioFile.fileFormat.sampleRate > 0
        else {
            return nil
        }

        return Double(audioFile.length) / audioFile.fileFormat.sampleRate
    }
}

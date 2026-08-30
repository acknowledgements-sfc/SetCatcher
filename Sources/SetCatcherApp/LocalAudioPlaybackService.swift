import AVFoundation
import Foundation

enum LocalAudioPlaybackError: LocalizedError, Equatable {
    case fileMissing
    case unreadableFile

    var errorDescription: String? {
        switch self {
        case .fileMissing:
            return "This recording is no longer available at its archive location."
        case .unreadableFile:
            return "This recording could not be opened for playback. The archived file was not changed."
        }
    }
}

struct PlaybackViewState: Equatable {
    var sessionID: UUID?
    var isPlaying = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var errorMessage: String?

    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(1, max(0, currentTime / duration))
    }
}

@MainActor
final class LocalAudioPlaybackService {
    private var player: AVAudioPlayer?
    private(set) var loadedURL: URL?

    var isPlaying: Bool { player?.isPlaying == true }
    var currentTime: TimeInterval { player?.currentTime ?? 0 }
    var duration: TimeInterval { player?.duration ?? 0 }

    func load(url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw LocalAudioPlaybackError.fileMissing
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            guard player.duration.isFinite, player.duration > 0, player.prepareToPlay() else {
                throw LocalAudioPlaybackError.unreadableFile
            }
            self.player?.stop()
            self.player = player
            loadedURL = url
        } catch let error as LocalAudioPlaybackError {
            throw error
        } catch {
            throw LocalAudioPlaybackError.unreadableFile
        }
    }

    func play() {
        player?.play()
    }

    func pause() {
        player?.pause()
    }

    func seek(to time: TimeInterval) {
        guard let player else { return }
        let upperBound = max(0, player.duration - 0.001)
        player.currentTime = min(upperBound, max(0, time))
    }

    func stop() {
        player?.stop()
        player = nil
        loadedURL = nil
    }
}

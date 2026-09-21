import AVFAudio
import Foundation

/// Plays back a locally recorded file via `AVAudioPlayer`.
@MainActor
protocol AudioPlayback: AnyObject {
    var isPlaying: Bool { get }
    func play(url: URL) async throws(PlaybackError)
    func stop()
}

@MainActor
final class AVAudioPlaybackService: NSObject, AudioPlayback {
    private var player: AVAudioPlayer?
    private var pendingContinuation: CheckedContinuation<Void, any Error>?

    var isPlaying: Bool { player?.isPlaying ?? false }

    func play(url: URL) async throws(PlaybackError) {
        stop()
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw PlaybackError.fileNotFound
        }

        do {
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.delegate = self
            player = newPlayer

            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                self.pendingContinuation = continuation
                guard newPlayer.play() else {
                    self.pendingContinuation = nil
                    continuation.resume(throwing: PlaybackError.decodeFailed("play() returned false"))
                    return
                }
            }
        } catch let error as PlaybackError {
            throw error
        } catch {
            throw PlaybackError.decodeFailed("\(error)")
        }
    }

    func stop() {
        guard let player, player.isPlaying else { return }
        player.stop()
        finishPending(cancelled: true)
    }

    private func finishPending(cancelled: Bool) {
        guard let pendingContinuation else { return }
        self.pendingContinuation = nil
        if cancelled {
            pendingContinuation.resume(throwing: PlaybackError.cancelled)
        } else {
            pendingContinuation.resume()
        }
    }
}

extension AVAudioPlaybackService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in self?.finishPending(cancelled: false) }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: (any Error)?) {
        Task { @MainActor [weak self] in self?.finishPending(cancelled: true) }
    }
}

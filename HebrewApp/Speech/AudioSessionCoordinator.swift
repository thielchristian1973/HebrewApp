import AVFAudio
import Foundation

/// Configures the shared `AVAudioSession` for simultaneous playback and recording, and turns
/// interruption/route-change notifications into a callback so the recording/playback UI can
/// pause and offer resumption (Documentation/SPEECH_SPEC.md: "Session-Unterbrechung,
/// Bluetooth/Headset-Wechsel, Hintergrund und Navigation testen").
@MainActor
final class AudioSessionCoordinator {
    enum InterruptionEvent: Sendable {
        case began
        case ended(shouldResume: Bool)
        case routeChanged(reason: AVAudioSession.RouteChangeReason)
    }

    var onInterruption: (@MainActor (InterruptionEvent) -> Void)?

    /// `NSObjectProtocol` observer tokens are opaque and only ever written once (in `init`) and
    /// read once (in `deinit`), so `nonisolated(unsafe)` is safe here — it exists solely to let
    /// a nonisolated `deinit` remove them; `Notification` itself is never stored.
    private nonisolated(unsafe) var interruptionObserver: NSObjectProtocol?
    private nonisolated(unsafe) var routeChangeObserver: NSObjectProtocol?

    init() {
        let center = NotificationCenter.default
        interruptionObserver = center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            // `Notification` is not `Sendable`, so only Sendable primitives extracted here are
            // handed across into the main-actor-isolated handler below.
            guard
                let info = note.userInfo,
                let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt
            else { return }
            let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt
            MainActor.assumeIsolated {
                self?.handleInterruption(typeValue: typeValue, optionsValue: optionsValue)
            }
        }
        routeChangeObserver = center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let reasonValue = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt else { return }
            MainActor.assumeIsolated {
                self?.handleRouteChange(reasonValue: reasonValue)
            }
        }
    }

    deinit {
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
        if let routeChangeObserver {
            NotificationCenter.default.removeObserver(routeChangeObserver)
        }
    }

    func activateRecordAndPlaybackSession() throws(RecordingError) {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try session.setActive(true)
        } catch {
            throw RecordingError.deviceUnavailable
        }
    }

    func deactivateSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func handleInterruption(typeValue: UInt, optionsValue: UInt?) {
        guard let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            onInterruption?(.began)
        case .ended:
            var shouldResume = false
            if let optionsValue {
                shouldResume = AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume)
            }
            onInterruption?(.ended(shouldResume: shouldResume))
        @unknown default:
            break
        }
    }

    private func handleRouteChange(reasonValue: UInt) {
        guard let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }
        onInterruption?(.routeChanged(reason: reason))
    }
}

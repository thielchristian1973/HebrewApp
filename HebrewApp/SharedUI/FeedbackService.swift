import AudioToolbox
import UIKit

/// Turns a `FeedbackCue` into an actual haptic + very short tone. Deliberately a thin,
/// branch-free wrapper over `UINotificationFeedbackGenerator`/`AudioServicesPlaySystemSound` —
/// the decision logic that produces a `FeedbackCue` lives in `FeedbackCueMapper` and is
/// unit-tested there; this type has nothing left to unit test (same reasoning as the other
/// system-framework wrappers in Speech/*, which are also untested at the unit level).
///
/// `AudioServicesPlaySystemSound` automatically respects the silent switch and Do Not Disturb,
/// so this never overrides a user's own silence preference. The two bundled tones are
/// synthesized locally (short sine sweeps), not licensed/purchased audio
/// (CLAUDE.md: "keine entgeltliche Audio-Produktion").
@MainActor
final class FeedbackService {
    private let confirmSoundID: SystemSoundID?
    private let retrySoundID: SystemSoundID?

    init() {
        confirmSoundID = Self.loadSystemSound(named: "confirm")
        retrySoundID = Self.loadSystemSound(named: "retry")
    }

    deinit {
        if let confirmSoundID { AudioServicesDisposeSystemSoundID(confirmSoundID) }
        if let retrySoundID { AudioServicesDisposeSystemSoundID(retrySoundID) }
    }

    func play(_ cue: FeedbackCue) {
        switch cue {
        case .confirmSuccess:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            if let confirmSoundID { AudioServicesPlaySystemSound(confirmSoundID) }
        case .acknowledgeRetry:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            if let retrySoundID { AudioServicesPlaySystemSound(retrySoundID) }
        case .none:
            break
        }
    }

    /// A light tap with no tone — used for plain "weiter" advancement that isn't an assessment
    /// (e.g. the sentence step), so it still feels responsive without implying right/wrong.
    func lightTap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private static func loadSystemSound(named name: String) -> SystemSoundID? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else { return nil }
        var soundID: SystemSoundID = 0
        let status = AudioServicesCreateSystemSoundID(url as CFURL, &soundID)
        return status == kAudioServicesNoError ? soundID : nil
    }
}

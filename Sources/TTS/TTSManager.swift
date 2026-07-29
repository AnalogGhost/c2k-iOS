import AVFoundation
import Foundation

final class TTSManager: NSObject {
    private let synthesizer = AVSpeechSynthesizer()
    // AVSpeechUtteranceDefaultSpeechRate = 0.5; multiply by Android-scale rate (0.7–1.3)
    private var speechRate: Float = AVSpeechUtteranceDefaultSpeechRate
    private var volume: Float = 1.0

    // Tracks the utterances in the current announcement group (a flush plus any queued
    // follow-ups). Audio ducking is held for the whole group and released once it drains —
    // mirrors Android's per-utterance-group AudioFocusRequest handling.
    private var pending: Set<ObjectIdentifier> = []
    private var holdsDuck = false

    private static let encouragementPhraseKeys = [
        "tts_encouragement_1", "tts_encouragement_2", "tts_encouragement_3",
        "tts_encouragement_4", "tts_encouragement_5",
    ]

    enum Announcement {
        case intervalStart(Interval)
        case workoutComplete
        case countdownWarning(Int)
        case nextInterval(Interval)
        case lastRunInterval
        case halfway
        case intervalMidpoint(phraseIndex: Int)
    }

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    var isSpeaking: Bool { synthesizer.isSpeaking }

    func setRate(_ androidRate: Float) {
        speechRate = androidRate * AVSpeechUtteranceDefaultSpeechRate
    }

    func setVolume(_ v: Float) {
        volume = v
    }

    func announce(_ announcement: Announcement, queueAdd: Bool = false) {
        let utterance = AVSpeechUtterance(string: text(for: announcement))
        utterance.rate = speechRate
        utterance.volume = volume
        if !queueAdd {
            synthesizer.stopSpeaking(at: .word)
            pending.removeAll()
        }
        pending.insert(ObjectIdentifier(utterance))
        activateDuckingIfNeeded()
        synthesizer.speak(utterance)
    }

    func shutdown() {
        synthesizer.stopSpeaking(at: .immediate)
        pending.removeAll()
        releaseDuckingIfIdle()
    }

    private func activateDuckingIfNeeded() {
        guard !holdsDuck else { return }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .voicePrompt, options: [.duckOthers])
            try session.setActive(true)
            holdsDuck = true
        } catch {
            // Speak without ducking rather than failing the announcement.
        }
    }

    private func releaseDuckingIfIdle() {
        guard holdsDuck, pending.isEmpty else { return }
        holdsDuck = false
        // Hand the session back to the background keep-alive loop's category; don't deactivate
        // it here — BackgroundAudioManager owns the session lifecycle for the whole workout.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
    }

    private func text(for announcement: Announcement) -> String {
        switch announcement {
        case .intervalStart(let interval):   return interval.announcement
        case .workoutComplete:               return NSLocalizedString("tts_workout_complete", comment: "")
        case .countdownWarning(let seconds):
            return String.localizedStringWithFormat(
                NSLocalizedString("tts_seconds_remaining", comment: ""), seconds)
        case .nextInterval(let interval):    return nextIntervalText(interval.type)
        case .lastRunInterval:               return NSLocalizedString("tts_last_run", comment: "")
        case .halfway:                       return NSLocalizedString("tts_halfway", comment: "")
        case .intervalMidpoint(let phraseIndex):
            let key = Self.encouragementPhraseKeys[phraseIndex % Self.encouragementPhraseKeys.count]
            return NSLocalizedString(key, comment: "")
        }
    }

    private func nextIntervalText(_ type: IntervalType) -> String {
        let key: String
        switch type {
        case .run:      key = "tts_next_run"
        case .walk:     key = "tts_next_walk"
        case .warmup:   key = "tts_next_warmup"
        case .cooldown: key = "tts_next_cooldown"
        }
        return NSLocalizedString(key, comment: "")
    }
}

extension TTSManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        finish(utterance)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        finish(utterance)
    }

    private func finish(_ utterance: AVSpeechUtterance) {
        pending.remove(ObjectIdentifier(utterance))
        releaseDuckingIfIdle()
    }
}

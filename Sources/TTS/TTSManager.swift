import AVFoundation
import Foundation

// Narrow seam so WorkoutEngine can be unit-tested with a spy instead of a real
// AVSpeechSynthesizer — mirrors Android's TtsInterface/TtsManager split.
protocol TTSAnnouncing: AnyObject {
    func announce(_ announcement: TTSManager.Announcement, queueAdd: Bool)
}

extension TTSAnnouncing {
    func announce(_ announcement: TTSManager.Announcement) {
        announce(announcement, queueAdd: false)
    }
}

/// What a workout plays cues through: the voice, or the chimes of Tones mode. Mirrors Android's
/// CuePlayer.
protocol CuePlayer: TTSAnnouncing {
    // True while a cue is queued or sounding, so a final cue can finish before shutdown.
    var isSpeaking: Bool { get }
    func shutdown()
}

final class TTSManager: NSObject {
    private let synthesizer = AVSpeechSynthesizer()
    // AVSpeechUtteranceDefaultSpeechRate = 0.5; multiply by Android-scale rate (0.7–1.3)
    private var speechRate: Float = AVSpeechUtteranceDefaultSpeechRate
    private var volume: Float = 1.0
    // BCP-47 code from the in-app language picker; nil follows the system voice.
    private var languageOverride: String?

    // Tracks the utterances in the current announcement group (a flush plus any queued
    // follow-ups). Audio ducking is held for the whole group and released once it drains —
    // mirrors Android's per-utterance-group AudioFocusRequest handling.
    private var pending: Set<ObjectIdentifier> = []
    private var holdsDuck = false
    // During a workout this is the BackgroundAudioManager, which owns the session.
    var ducking: AudioDucking = StandaloneDucking.shared

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
        case periodicTimeRemaining(Int)
        /// `meters` covered so far, with the average pace over the last split when it's usable.
        case distanceSplit(meters: Int, paceSecondsPerKm: Int?)
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

    func setLanguage(_ bcp47: String?) {
        languageOverride = bcp47
    }

    /// The language code announcements will actually use — override, else the system voice.
    func resolvedLanguageCode() -> String {
        languageOverride ?? AVSpeechSynthesisVoice.currentLanguageCode()
    }

    private static func voice(for code: String) -> AVSpeechSynthesisVoice? {
        AVSpeechSynthesisVoice(language: code) ?? AVSpeechSynthesisVoice(language: String(code.prefix(2)))
    }

    // Silence before a cue that has to take the duck, while the output switches over.
    static let leadIn: TimeInterval = 0.4

    static let englishBundle =
        Bundle.main.path(forResource: "en", ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main

    /// The language cues are actually spoken in: the resolved language when the device has a voice
    /// for it, else English. With no voice for the app's language (Galician on most iPhones), iOS
    /// would read the translated text with another language's voice and pronunciation.
    static func cueLanguage(for code: String, hasVoice: (String) -> Bool = { voice(for: $0) != nil }) -> String {
        hasVoice(code) ? code : "en"
    }

    func announce(_ announcement: Announcement, queueAdd: Bool = false) {
        let code = resolvedLanguageCode()
        let fellBack = Self.cueLanguage(for: code) != code
        let utterance = AVSpeechUtterance(
            string: text(for: announcement, bundle: fellBack ? Self.englishBundle : .main))
        utterance.rate = speechRate
        utterance.volume = volume
        // nil is valid — AVSpeech falls back to the default
        utterance.voice = Self.voice(for: fellBack ? "en" : code)
        if !queueAdd {
            synthesizer.stopSpeaking(at: .word)
            pending.removeAll()
        }
        if !holdsDuck {
            // Lowering other audio and switching the output to this app can swallow the first few
            // hundred milliseconds, often the number in "2 minutes remaining" (Android issue #50).
            utterance.preUtteranceDelay = Self.leadIn
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
        holdsDuck = true
        ducking.beginDucking(mode: .voicePrompt)
    }

    private func releaseDuckingIfIdle() {
        guard holdsDuck, pending.isEmpty else { return }
        holdsDuck = false
        ducking.endDucking()
    }

    func text(for announcement: Announcement, bundle: Bundle = .main) -> String {
        switch announcement {
        case .intervalStart(let interval):   return interval.announcement(bundle: bundle)
        case .workoutComplete:               return NSLocalizedString("tts_workout_complete", bundle: bundle, comment: "")
        case .countdownWarning(let seconds):
            return String.localizedStringWithFormat(
                NSLocalizedString("tts_seconds_remaining", bundle: bundle, comment: ""), seconds)
        case .nextInterval(let interval):    return nextIntervalText(interval.type, bundle: bundle)
        case .lastRunInterval:               return NSLocalizedString("tts_last_run", bundle: bundle, comment: "")
        case .halfway:                       return NSLocalizedString("tts_halfway", bundle: bundle, comment: "")
        case .intervalMidpoint(let phraseIndex):
            let key = Self.encouragementPhraseKeys[phraseIndex % Self.encouragementPhraseKeys.count]
            return NSLocalizedString(key, bundle: bundle, comment: "")
        case .periodicTimeRemaining(let seconds):
            return String(format: NSLocalizedString("tts_time_remaining", bundle: bundle, comment: ""),
                          Interval.spokenDuration(seconds: seconds, bundle: bundle))
        case .distanceSplit(let meters, let pace):
            let distance = Self.spokenDistance(meters: meters, bundle: bundle)
            guard let pace else { return distance }
            return String(format: NSLocalizedString("tts_distance_split_pace", bundle: bundle, comment: ""),
                          distance, Interval.spokenDuration(seconds: pace, bundle: bundle))
        }
    }

    // Spoken with whole-number plurals only ("1 kilometre 500 metres", not "1.5 kilometres"):
    // languages disagree on the plural form for a fraction (French says "1,5 kilomètre" but
    // "2,5 kilomètres"), matching Android.
    static func spokenDistance(meters: Int, bundle: Bundle = .main) -> String {
        let km = meters / 1000
        let m = meters % 1000
        let kmStr = km > 0 ? String.localizedStringWithFormat(NSLocalizedString("tts_distance_km", bundle: bundle, comment: ""), km) : nil
        let mStr = m > 0 ? String.localizedStringWithFormat(NSLocalizedString("tts_distance_m", bundle: bundle, comment: ""), m) : nil
        switch (kmStr, mStr) {
        case let (k?, m?): return String(format: NSLocalizedString("tts_distance_km_m", bundle: bundle, comment: ""), k, m)
        case let (k?, nil): return k
        default: return mStr ?? ""
        }
    }

    private func nextIntervalText(_ type: IntervalType, bundle: Bundle) -> String {
        let key: String
        switch type {
        case .run:      key = "tts_next_run"
        case .walk:     key = "tts_next_walk"
        case .warmup:   key = "tts_next_warmup"
        case .cooldown: key = "tts_next_cooldown"
        }
        return NSLocalizedString(key, bundle: bundle, comment: "")
    }
}

extension TTSManager: CuePlayer {}

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

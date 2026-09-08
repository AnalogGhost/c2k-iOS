import AVFoundation
import Observation

// Standalone "Test voice" flow for Settings. Owns its own AVSpeechSynthesizer and its own
// audio-session teardown — it must NOT reuse the workout TTSManager, whose ducking release
// deliberately never deactivates the session (BackgroundAudioManager owns that lifecycle).
@Observable
@MainActor
final class VoiceTester: NSObject, AVSpeechSynthesizerDelegate {
    private(set) var status: VoiceTestStatus = .idle

    private let synth = AVSpeechSynthesizer()
    private var watchdog: Task<Void, Never>?
    private let watchdogSeconds: Double

    init(watchdogSeconds: Double = 3) {
        self.watchdogSeconds = watchdogSeconds
        super.init()
        synth.delegate = self
    }

    func speakTest(rate androidRate: Float, volume: Float, language: String?) {
        guard !WorkoutManager.shared.isRunning else { return }
        guard status != .initializing && status != .playing else { return }

        status = .initializing

        let voice: AVSpeechSynthesisVoice?
        if let language {
            guard let v = AVSpeechSynthesisVoice(language: language)
                ?? AVSpeechSynthesisVoice(language: String(language.prefix(2))) else {
                status = .voiceUnavailable
                return
            }
            voice = v
        } else {
            voice = nil
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .voicePrompt, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            status = .audioOutputFailure
            return
        }

        let utterance = AVSpeechUtterance(string: String(localized: "settings_tts_test_phrase"))
        utterance.rate = androidRate * AVSpeechUtteranceDefaultSpeechRate
        utterance.volume = volume
        utterance.voice = voice
        synth.speak(utterance)

        watchdog = Task { [weak self] in
            try? await Task.sleep(for: .seconds(self?.watchdogSeconds ?? 3))
            guard let self, self.status == .initializing else { return }
            self.status = .synthesisFailure
            self.stopAndDeactivate()
        }
    }

    private func stopAndDeactivate() {
        watchdog?.cancel()
        watchdog = nil
        synth.stopSpeaking(at: .immediate)
        // Safe here: no workout owns the session while Settings is open.
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in
            watchdog?.cancel()
            watchdog = nil
            if status == .initializing { status = .playing }
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            status = .finished
            stopAndDeactivate()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            if status != .finished { status = .synthesisFailure }
            stopAndDeactivate()
        }
    }
}

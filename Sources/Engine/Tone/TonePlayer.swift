import AVFoundation
import Foundation

/// Plays chimes in place of spoken announcements (Tones mode). It ducks other audio the same way
/// the voice does, so music behaves the same as under a spoken cue.
final class TonePlayer: NSObject {
    private let volume: Float
    private let countdownThresholds: [Int]
    private var rendered: [Chime: Data] = [:]
    private var player: AVAudioPlayer?
    private var holdsDuck = false
    private let ducking: AudioDucking

    init(volume: Float = 1.0, countdownThresholds: [Int] = [], ducking: AudioDucking = StandaloneDucking.shared) {
        self.volume = volume
        self.countdownThresholds = countdownThresholds
        self.ducking = ducking
    }

    // Every announcement that maps to a chime arrives as a flush, never queued, so a new chime
    // simply replaces whatever is still ringing.
    func announce(_ announcement: TTSManager.Announcement, queueAdd: Bool) {
        guard let chime = ToneCues.chime(for: announcement, countdownThresholds: countdownThresholds) else { return }
        play(chime)
    }

    func play(_ chime: Chime) {
        player?.stop()
        let wav = rendered[chime] ?? ChimeSynth.wav(ChimeSynth.render(chime))
        rendered[chime] = wav
        guard let next = try? AVAudioPlayer(data: wav) else {
            player = nil
            releaseDucking()
            return
        }
        next.volume = volume
        next.delegate = self
        activateDucking()
        next.play()
        player = next
    }

    func shutdown() {
        player?.stop()
        player = nil
        releaseDucking()
    }

    private func activateDucking() {
        guard !holdsDuck else { return }
        holdsDuck = true
        ducking.beginDucking(mode: .default)
    }

    private func releaseDucking() {
        guard holdsDuck else { return }
        holdsDuck = false
        ducking.endDucking()
    }
}

extension TonePlayer: CuePlayer {
    // True while a chime is playing, so the workout can let the completion chime finish.
    var isSpeaking: Bool { player?.isPlaying ?? false }
}

extension TonePlayer: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ finished: AVAudioPlayer, successfully flag: Bool) {
        guard finished === player else { return }
        player = nil
        releaseDucking()
    }
}

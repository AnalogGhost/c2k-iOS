import AVFoundation

final class TTSManager {
    private let synthesizer = AVSpeechSynthesizer()
    // AVSpeechUtteranceDefaultSpeechRate = 0.5; multiply by Android-scale rate (0.7–1.3)
    private var speechRate: Float = AVSpeechUtteranceDefaultSpeechRate

    enum Announcement {
        case intervalStart(Interval)
        case workoutComplete
        case countdownWarning(Int)
        case nextInterval(Interval)
        case lastRunInterval
        case halfway
    }

    func setRate(_ androidRate: Float) {
        speechRate = androidRate * AVSpeechUtteranceDefaultSpeechRate
    }

    func announce(_ announcement: Announcement, queueAdd: Bool = false) {
        let utterance = AVSpeechUtterance(string: text(for: announcement))
        utterance.rate = speechRate
        if !queueAdd { synthesizer.stopSpeaking(at: .word) }
        synthesizer.speak(utterance)
    }

    func shutdown() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    private func text(for announcement: Announcement) -> String {
        switch announcement {
        case .intervalStart(let interval):   return interval.announcement
        case .workoutComplete:               return "Workout complete. Well done!"
        case .countdownWarning(let seconds): return "\(seconds) seconds remaining"
        case .nextInterval(let interval):    return "Next: \(interval.announcement)"
        case .lastRunInterval:               return "This is your last run interval"
        case .halfway:                       return "Halfway there"
        }
    }
}

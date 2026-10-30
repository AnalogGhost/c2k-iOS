import Foundation

/// Which chime, if any, stands in for each spoken announcement in Tones mode. Cues that only make
/// sense as words (look-ahead, halfway, last run, encouragement, periodic time remaining) have no
/// chime and are dropped: a tone for each would be one more sound to learn for little gain.
enum ToneCues {

    /// `countdownThresholds` are the active countdown warnings, as the engine fires them (see
    /// `countdownWarningThresholds`). With two of them, the later one gets the double tick.
    static func chime(for announcement: TTSManager.Announcement, countdownThresholds: [Int]) -> Chime? {
        switch announcement {
        case .intervalStart(let interval):
            switch interval.type {
            case .warmup:   return .warmup
            case .run:      return .run
            case .walk:     return .walk
            case .cooldown: return .cooldown
            }
        case .countdownWarning(let seconds):
            return countdownThresholds.count > 1 && seconds == countdownThresholds.last
                ? .countdownSecond : .countdownFirst
        case .workoutComplete:
            return .complete
        case .nextInterval, .intervalMidpoint, .periodicTimeRemaining, .halfway, .lastRunInterval:
            return nil
        }
    }
}

import Foundation

struct Interval {
    let type: IntervalType
    let durationSeconds: Int

    /// Spoken form of a duration, e.g. "1 minute and 30 seconds".
    static func spokenDuration(seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        if mins > 0 && secs > 0 {
            let minStr = String.localizedStringWithFormat(NSLocalizedString("tts_duration_minutes", comment: ""), mins)
            let secStr = String.localizedStringWithFormat(NSLocalizedString("tts_duration_seconds", comment: ""), secs)
            return String(format: NSLocalizedString("tts_duration_min_sec", comment: ""), minStr, secStr)
        } else if mins > 0 {
            return String.localizedStringWithFormat(NSLocalizedString("tts_duration_minutes", comment: ""), mins)
        } else {
            return String.localizedStringWithFormat(NSLocalizedString("tts_duration_seconds", comment: ""), secs)
        }
    }

    var announcement: String {
        let duration = Self.spokenDuration(seconds: durationSeconds)
        switch type {
        case .warmup:   return NSLocalizedString("tts_interval_warmup", comment: "")
        case .run:      return String(format: NSLocalizedString("tts_interval_run", comment: ""), duration)
        case .walk:     return String(format: NSLocalizedString("tts_interval_walk", comment: ""), duration)
        case .cooldown: return NSLocalizedString("tts_interval_cooldown", comment: "")
        }
    }
}

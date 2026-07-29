import Foundation

struct Interval {
    let type: IntervalType
    let durationSeconds: Int

    var announcement: String {
        let mins = durationSeconds / 60
        let secs = durationSeconds % 60
        let duration: String
        if mins > 0 && secs > 0 {
            let minStr = String.localizedStringWithFormat(NSLocalizedString("tts_duration_minutes", comment: ""), mins)
            let secStr = String.localizedStringWithFormat(NSLocalizedString("tts_duration_seconds", comment: ""), secs)
            duration = String(format: NSLocalizedString("tts_duration_min_sec", comment: ""), minStr, secStr)
        } else if mins > 0 {
            duration = String.localizedStringWithFormat(NSLocalizedString("tts_duration_minutes", comment: ""), mins)
        } else {
            duration = String.localizedStringWithFormat(NSLocalizedString("tts_duration_seconds", comment: ""), secs)
        }
        switch type {
        case .warmup:   return NSLocalizedString("tts_interval_warmup", comment: "")
        case .run:      return String(format: NSLocalizedString("tts_interval_run", comment: ""), duration)
        case .walk:     return String(format: NSLocalizedString("tts_interval_walk", comment: ""), duration)
        case .cooldown: return NSLocalizedString("tts_interval_cooldown", comment: "")
        }
    }
}

import Foundation

struct Interval {
    let type: IntervalType
    let durationSeconds: Int

    /// Spoken form of a duration, e.g. "1 minute and 30 seconds".
    static func spokenDuration(seconds: Int, bundle: Bundle = .main) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        if mins > 0 && secs > 0 {
            let minStr = String.localizedStringWithFormat(NSLocalizedString("tts_duration_minutes", bundle: bundle, comment: ""), mins)
            let secStr = String.localizedStringWithFormat(NSLocalizedString("tts_duration_seconds", bundle: bundle, comment: ""), secs)
            return String(format: NSLocalizedString("tts_duration_min_sec", bundle: bundle, comment: ""), minStr, secStr)
        } else if mins > 0 {
            return String.localizedStringWithFormat(NSLocalizedString("tts_duration_minutes", bundle: bundle, comment: ""), mins)
        } else {
            return String.localizedStringWithFormat(NSLocalizedString("tts_duration_seconds", bundle: bundle, comment: ""), secs)
        }
    }

    var announcement: String { announcement(bundle: .main) }

    func announcement(bundle: Bundle) -> String {
        let duration = Self.spokenDuration(seconds: durationSeconds, bundle: bundle)
        switch type {
        case .warmup:   return NSLocalizedString("tts_interval_warmup", bundle: bundle, comment: "")
        case .run:      return String(format: NSLocalizedString("tts_interval_run", bundle: bundle, comment: ""), duration)
        case .walk:     return String(format: NSLocalizedString("tts_interval_walk", bundle: bundle, comment: ""), duration)
        case .cooldown: return NSLocalizedString("tts_interval_cooldown", bundle: bundle, comment: "")
        }
    }
}

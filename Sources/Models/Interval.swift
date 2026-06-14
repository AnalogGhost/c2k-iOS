struct Interval {
    let type: IntervalType
    let durationSeconds: Int

    var announcement: String {
        let mins = durationSeconds / 60
        let secs = durationSeconds % 60
        let duration: String
        if mins > 0 && secs > 0 {
            duration = "\(mins) minute\(mins > 1 ? "s" : "") and \(secs) seconds"
        } else if mins > 0 {
            duration = "\(mins) minute\(mins > 1 ? "s" : "")"
        } else {
            duration = "\(secs) seconds"
        }
        switch type {
        case .warmup:   return "Begin warm-up walk"
        case .run:      return "Start running for \(duration)"
        case .walk:     return "Walk for \(duration)"
        case .cooldown: return "Begin cool-down walk"
        }
    }
}

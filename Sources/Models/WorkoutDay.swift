struct WorkoutDay {
    let week: Int
    let day: Int
    let intervals: [Interval]

    var totalDurationSeconds: Int {
        intervals.reduce(0) { $0 + $1.durationSeconds }
    }
}

struct WorkoutPlan {
    let programId: String
    let displayName: String
    let description: String
    let weeks: [[WorkoutDay]]
    let prerequisite: String?

    var totalWeeks: Int { weeks.count }
}

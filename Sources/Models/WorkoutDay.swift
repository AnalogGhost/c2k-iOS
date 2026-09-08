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

    /// The (week, day) to suggest next: the first uncompleted day *after* the latest completed
    /// one, in plan order. Scanning for the earliest gap instead would point users who
    /// deliberately skip ahead (e.g. start at week 3 because weeks 1-2 are too easy) back at
    /// week 1 day 1 forever. Nil when nothing remains after the latest completed day.
    func nextWorkout(completedDays: Set<WeekDay>) -> WeekDay? {
        let ordered = weeks.flatMap { $0.map { WeekDay(week: $0.week, day: $0.day) } }
        let lastCompletedIdx = ordered.lastIndex(where: completedDays.contains) ?? -1
        return ordered.dropFirst(lastCompletedIdx + 1).first { !completedDays.contains($0) }
    }
}

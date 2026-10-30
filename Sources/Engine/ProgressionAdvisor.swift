import Foundation

/// What the Home screen offers a runner who keeps stopping the same workout early.
enum ProgressionSuggestion: Equatable {
    /// Go back and run `week` again, the usual C25K advice for a week that feels too hard.
    case repeatWeek(week: Int, earlyStops: Int)

    /// C25K week 1 has no earlier week to repeat, so offer the gentler starter plan instead.
    case tryPreC25K(earlyStops: Int)

    var earlyStops: Int {
        switch self {
        case .repeatWeek(_, let stops), .tryPreC25K(let stops): return stops
        }
    }
}

/// A week the runner chose to repeat, and when, so only workouts run since then count toward it.
struct RepeatedWeek: Equatable {
    let programId: String
    let week: Int
    let since: Date
}

// Only suggests; nothing changes until the runner accepts. Stopping early is the one signal the
// app has: it can't tell whether someone walked during a run interval and finished anyway.
// Port of the Android app's ProgressionAdvisor.
enum ProgressionAdvisor {

    static let earlyStopsToSuggest = 2

    // Shorter attempts are usually an accidental start or a quick restart, not a struggle.
    static let minAttemptSeconds = 120

    /// Suggests stepping back when the runner has stopped their next workout (`week`, `day`) early
    /// at least `earlyStopsToSuggest` times. Only stops since the last workout they finished in
    /// this program count, so early stops from before a repeated week don't trigger it again once
    /// they're back. After "Not now" (`dismissedAt`) it takes that many new stops to suggest
    /// again, but the count shown is every stop since the last finished workout, so the card
    /// doesn't understate how often the runner has hit this wall.
    static func suggest(plan: WorkoutPlan, week: Int, day: Int,
                        sessions: [WorkoutSession], dismissedAt: Date?) -> ProgressionSuggestion? {
        let inPlan = sessions.filter { $0.programId == plan.programId }
        let lastFinished = inPlan.filter(\.completed).map(\.startedAt).max() ?? .distantPast
        let stops = inPlan.filter {
            !$0.completed && $0.week == week && $0.day == day &&
                $0.durationSeconds >= minAttemptSeconds && $0.startedAt > lastFinished
        }
        let sinceDismissed = stops.filter { $0.startedAt > (dismissedAt ?? .distantPast) }.count
        guard sinceDismissed >= earlyStopsToSuggest else { return nil }
        if week > 1 { return .repeatWeek(week: week - 1, earlyStops: stops.count) }
        if plan.programId == Programs.idC25K { return .tryPreC25K(earlyStops: stops.count) }
        // Week 1 of any other program: the runner is already kept on this day, so there is
        // nothing gentler within the plan to offer.
        return nil
    }

    /// The next day of `repeated` the runner hasn't finished since choosing to repeat it, or nil
    /// once they've finished the whole week again (or it belongs to another program). Then the
    /// plan's usual next workout takes over, which is the day they were stuck on.
    static func nextInRepeatedWeek(plan: WorkoutPlan, repeated: RepeatedWeek?,
                                   sessions: [WorkoutSession]) -> WeekDay? {
        guard let repeated, repeated.programId == plan.programId,
              plan.weeks.indices.contains(repeated.week - 1) else { return nil }
        let redone = Set(sessions.filter {
            $0.programId == plan.programId && $0.completed &&
                $0.week == repeated.week && $0.startedAt >= repeated.since
        }.map(\.day))
        return plan.weeks[repeated.week - 1]
            .first { !redone.contains($0.day) }
            .map { WeekDay(week: $0.week, day: $0.day) }
    }
}

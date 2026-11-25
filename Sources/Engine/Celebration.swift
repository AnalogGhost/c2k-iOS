import Foundation

/// What the completed-workout screen celebrates, if anything.
enum Celebration: Equatable {
    /// The program's last workout, finished with every run done.
    case programFinished
    /// The last workout of week 3, the first time any program gets there.
    case weekThree
}

enum CelebrationTrigger {
    /// Set once week 3 has been celebrated, so it never comes round again.
    static let weekThreeKey = "week3_celebrated"

    /// The celebration for a workout that has just ended, or nil. Only a finished workout with no
    /// skipped run counts, so nothing fires mid-workout or for a session that won't advance the
    /// program. Pre-C25K's week 3 is also its last, so finishing it is a program celebration.
    static func celebration(after state: WorkoutState, plan: WorkoutPlan, week: Int, day: Int,
                            weekThreeCelebrated: Bool) -> Celebration? {
        guard case .completed(_, _, let skippedRun) = state, !skippedRun else { return nil }
        if isLastDay(of: plan, week: week, day: day) { return .programFinished }
        if !weekThreeCelebrated, plan.weeks.count >= 3, week == 3, day == plan.weeks[2].last?.day {
            return .weekThree
        }
        return nil
    }

    /// `celebration(after:…)` with the week-3 flag read from and recorded in `defaults`. Reaching
    /// week 3 by finishing a program records it too, so the smaller week-3 moment doesn't follow.
    static func evaluate(after state: WorkoutState, plan: WorkoutPlan, week: Int, day: Int,
                         defaults: UserDefaults = .standard) -> Celebration? {
        let result = celebration(after: state, plan: plan, week: week, day: day,
                                 weekThreeCelebrated: defaults.bool(forKey: weekThreeKey))
        if result != nil, week >= 3 { defaults.set(true, forKey: weekThreeKey) }
        return result
    }

    private static func isLastDay(of plan: WorkoutPlan, week: Int, day: Int) -> Bool {
        week == plan.totalWeeks && day == plan.weeks.last?.last?.day
    }
}

enum ShareLinks {
    static let website = URL(string: "https://hackerapps.com/apps/c2k/")!
    static let writeReview = URL(string: "https://apps.apple.com/app/id6796435384?action=write-review")!
}

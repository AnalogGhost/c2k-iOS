import Foundation

struct PeriodTotals: Equatable {
    let completedSessions: Int
    let totalKm: Double
    let totalTimeSeconds: Int
    let totalCalories: Int?

    var hasActivity: Bool { completedSessions > 0 || totalTimeSeconds > 0 }
}

struct WeeklySummary: Equatable {
    let thisWeek: PeriodTotals
    let lastWeek: PeriodTotals
}

struct MonthlySummary: Equatable {
    let thisMonth: PeriodTotals
    let lastMonth: PeriodTotals
}

// Aggregates sessions into the current calendar week/month and the one before it, so the
// History screen can show "this week" / "this month" summaries with a previous-period
// comparison — mirrors Android's WeeklySummaryCalculator / MonthlySummaryCalculator.
extension WorkoutStats {

    // The week starts on the calendar's `firstWeekday` (the user's region setting), unlike
    // `streak`, which is deliberately ISO Monday-start.
    static func weeklySummary(
        sessions: [WorkoutSession], now: Date = .now, weightKg: Double? = nil, calendar: Calendar = .current
    ) -> WeeklySummary {
        let (this, last) = periodPair(.weekOfYear, sessions: sessions, now: now, weightKg: weightKg, calendar: calendar)
        return WeeklySummary(thisWeek: this, lastWeek: last)
    }

    static func monthlySummary(
        sessions: [WorkoutSession], now: Date = .now, weightKg: Double? = nil, calendar: Calendar = .current
    ) -> MonthlySummary {
        let (this, last) = periodPair(.month, sessions: sessions, now: now, weightKg: weightKg, calendar: calendar)
        return MonthlySummary(thisMonth: this, lastMonth: last)
    }

    // Boundaries are the calendar's local period starts, not fixed day counts, so a DST
    // change inside the period or a short/long month can't misplace a session.
    private static func periodPair(
        _ component: Calendar.Component, sessions: [WorkoutSession], now: Date, weightKg: Double?, calendar: Calendar
    ) -> (this: PeriodTotals, last: PeriodTotals) {
        guard let current = calendar.dateInterval(of: component, for: now),
              let lastStart = calendar.date(byAdding: component, value: -1, to: current.start)
        else {
            let empty = periodTotals([], weightKg: weightKg)
            return (empty, empty)
        }
        return (
            periodTotals(sessions.filter { $0.startedAt >= current.start && $0.startedAt < current.end }, weightKg: weightKg),
            periodTotals(sessions.filter { $0.startedAt >= lastStart && $0.startedAt < current.start }, weightKg: weightKg)
        )
    }

    // Follows the History "Totals" card: distance and time include every recorded session
    // (an abandoned run still covered ground) while the workout count only includes completed
    // ones. Calories are nil when no body weight is set, rather than guessed.
    private static func periodTotals(_ sessions: [WorkoutSession], weightKg: Double?) -> PeriodTotals {
        PeriodTotals(
            completedSessions: sessions.filter(\.completed).count,
            totalKm: sessions.reduce(0) { $0 + $1.distanceMeters } / 1000,
            totalTimeSeconds: sessions.reduce(0) { $0 + $1.durationSeconds },
            totalCalories: totalCalories(sessions: sessions, weightKg: weightKg)
        )
    }
}

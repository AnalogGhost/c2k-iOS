import Foundation

// Pure calculation functions extracted from HomeView/HistoryView so they're unit-testable
// without a SwiftData ModelContext or SwiftUI hosting, and so streak logic has one place
// that's exercised by tests.
enum WorkoutStats {

    // Weekly, not daily (matches Android issue #29): every program schedules ~3 runs a week
    // with rest days between them, so a day-based streak was guaranteed to reset on every
    // rest day. A week counts toward the streak if it has at least one completed session,
    // and the streak is alive as long as the latest such week is the current or the previous
    // one (the current week gets a grace period — its workout may simply not have happened
    // yet). Weeks are bucketed by *local* calendar day, ISO (Monday-start): bucketing by UTC
    // instead would disagree with what the user sees on their device clock near midnight or a
    // week boundary in non-UTC timezones, silently breaking or inflating the streak — matches
    // Android's `ZoneId.systemDefault()` local-date bucketing.
    static func streak(sessions: [WorkoutSession], now: Date = .now, calendar: Calendar = .current) -> Int {
        let completed = sessions.filter(\.completed)
        let completedWeeks = Set(completed.map { localWeekNumber(for: $0.startedAt, calendar: calendar) })
        guard let latestCompleted = completedWeeks.max() else { return 0 }

        let thisWeek = localWeekNumber(for: now, calendar: calendar)
        guard latestCompleted >= thisWeek - 1 else { return 0 }

        let sorted = completedWeeks.sorted(by: >)
        var count = 1
        var expected = sorted[0] - 1
        for w in sorted.dropFirst() {
            if w == expected { count += 1; expected -= 1 }
            else if w < expected { break }
        }
        return count
    }

    static func totalCalories(sessions: [WorkoutSession], weightKg: Double?) -> Int? {
        guard let weightKg else { return nil }
        return sessions.reduce(0) { total, s in
            total + (CalorieCalculator.estimateCalories(
                distanceMeters: s.distanceMeters, durationSeconds: s.durationSeconds, weightKg: weightKg
            ) ?? 0)
        }
    }

    static func fastestPaceSecPerKm(sessions: [WorkoutSession]) -> Double? {
        eligible(sessions).map { Double($0.durationSeconds) / ($0.distanceMeters / 1000) }.min()
    }

    static func longestRunMeters(sessions: [WorkoutSession]) -> Double? {
        eligible(sessions).map(\.distanceMeters).max()
    }

    private static func eligible(_ sessions: [WorkoutSession]) -> [WorkoutSession] {
        sessions.filter { $0.completed && $0.distanceMeters > 0 }
    }

    private static func localDayNumber(for date: Date, calendar: Calendar) -> Int {
        let startOfDay = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: .init(timeIntervalSince1970: 0), to: startOfDay).day ?? 0
    }

    // ISO week number as a simple, monotonically increasing integer (not the 1-52/53 calendar
    // week-of-year, which wraps every January and would break streaks spanning a year
    // boundary). Epoch day -3 was a Monday (1969-12-29), so shifting by 3 before floor-dividing
    // by 7 aligns the division to Monday boundaries — matches Android's
    // `Math.floorDiv(epochDay + 3, 7)`.
    private static func localWeekNumber(for date: Date, calendar: Calendar) -> Int {
        let day = localDayNumber(for: date, calendar: calendar) + 3
        return day >= 0 ? day / 7 : (day - 6) / 7
    }
}

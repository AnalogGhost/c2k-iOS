import Foundation

// Pure calculation functions extracted from HomeView/HistoryView so they're unit-testable
// without a SwiftData ModelContext or SwiftUI hosting, and so streak logic has one place
// that's exercised by tests.
enum WorkoutStats {

    // Consecutive-day streak ending today or yesterday, bucketed by *local* calendar day.
    // Bucketing by UTC day instead would disagree with what the user sees on their device
    // clock near midnight in non-UTC timezones, silently breaking or inflating the streak —
    // matches Android's `ZoneId.systemDefault()` local-date bucketing.
    static func streak(sessions: [WorkoutSession], now: Date = .now, calendar: Calendar = .current) -> Int {
        let completed = sessions.filter(\.completed)
        let dayNumbers = Set(completed.map { localDayNumber(for: $0.startedAt, calendar: calendar) })
        guard !dayNumbers.isEmpty else { return 0 }

        let today = localDayNumber(for: now, calendar: calendar)
        guard dayNumbers.contains(today) || dayNumbers.contains(today - 1) else { return 0 }

        let sorted = dayNumbers.sorted(by: >)
        var count = 1
        var expected = sorted[0] - 1
        for d in sorted.dropFirst() {
            if d == expected { count += 1; expected -= 1 }
            else if d < expected { break }
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
}

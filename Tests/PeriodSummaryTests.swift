import XCTest
@testable import CtoK

final class PeriodSummaryTests: XCTestCase {

    private static let utc = TimeZone(identifier: "UTC")!

    // firstWeekday: 1 = Sunday, 2 = Monday.
    private func calendar(zone: TimeZone = utc, firstWeekday: Int = 2) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = zone
        cal.firstWeekday = firstWeekday
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12, minute: Int = 0,
                      zone: TimeZone = utc) -> Date {
        calendar(zone: zone).date(from: DateComponents(
            year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    // 2026-09-16 is a Wednesday. Its Monday-start week runs 2026-09-14..2026-09-20; its
    // Sunday-start week runs 2026-09-13..2026-09-19.
    private var wednesday: Date { date(2026, 9, 16) }

    private func session(_ startedAt: Date, durationSeconds: Int = 600, distanceMeters: Double = 1000,
                         completed: Bool = true) -> WorkoutSession {
        let s = WorkoutSession(programId: "C25K", week: 1, day: 1)
        s.startedAt = startedAt
        s.durationSeconds = durationSeconds
        s.distanceMeters = distanceMeters
        s.completed = completed
        return s
    }

    private func weekly(_ sessions: [WorkoutSession], now: Date? = nil, weightKg: Double? = nil,
                        calendar: Calendar? = nil) -> WeeklySummary {
        WorkoutStats.weeklySummary(sessions: sessions, now: now ?? wednesday, weightKg: weightKg,
                                   calendar: calendar ?? self.calendar())
    }

    private func monthly(_ sessions: [WorkoutSession], now: Date? = nil, weightKg: Double? = nil,
                         calendar: Calendar? = nil) -> MonthlySummary {
        WorkoutStats.monthlySummary(sessions: sessions, now: now ?? wednesday, weightKg: weightKg,
                                    calendar: calendar ?? self.calendar())
    }

    // MARK: - Weekly

    func testWeeklyEmptyHistoryGivesZeroTotalsAndNoActivity() {
        let summary = weekly([])
        XCTAssertEqual(summary.thisWeek.completedSessions, 0)
        XCTAssertEqual(summary.thisWeek.totalKm, 0)
        XCTAssertEqual(summary.thisWeek.totalTimeSeconds, 0)
        XCTAssertFalse(summary.thisWeek.hasActivity)
        XCTAssertFalse(summary.lastWeek.hasActivity)
    }

    func testWeeklySessionsThisWeekAreSummed() {
        let summary = weekly([
            session(date(2026, 9, 14), durationSeconds: 600, distanceMeters: 1000),
            session(date(2026, 9, 16), durationSeconds: 300, distanceMeters: 500),
        ])
        XCTAssertEqual(summary.thisWeek.completedSessions, 2)
        XCTAssertEqual(summary.thisWeek.totalKm, 1.5, accuracy: 0.0001)
        XCTAssertEqual(summary.thisWeek.totalTimeSeconds, 900)
        XCTAssertTrue(summary.thisWeek.hasActivity)
        XCTAssertFalse(summary.lastWeek.hasActivity)
    }

    func testWeeklyLastWeekIsTotalledSeparatelyAndOlderWeeksAreIgnored() {
        let summary = weekly([
            session(date(2026, 9, 16), durationSeconds: 600, distanceMeters: 1000),
            session(date(2026, 9, 10), durationSeconds: 1200, distanceMeters: 2000),
            session(date(2026, 9, 2), durationSeconds: 9999, distanceMeters: 9000),
        ])
        XCTAssertEqual(summary.thisWeek.completedSessions, 1)
        XCTAssertEqual(summary.thisWeek.totalKm, 1.0, accuracy: 0.0001)
        XCTAssertEqual(summary.lastWeek.completedSessions, 1)
        XCTAssertEqual(summary.lastWeek.totalKm, 2.0, accuracy: 0.0001)
        XCTAssertEqual(summary.lastWeek.totalTimeSeconds, 1200)
    }

    func testWeeklySessionsAfterTheCurrentWeekAreNotCounted() {
        let summary = weekly([session(date(2026, 9, 21))])
        XCTAssertFalse(summary.thisWeek.hasActivity)
        XCTAssertFalse(summary.lastWeek.hasActivity)
    }

    func testWeekBoundaryFallsOnLocalMidnightOfTheFirstDay() {
        let summary = weekly([
            session(date(2026, 9, 14, hour: 0, minute: 0)),   // Monday 00:00 -> this week
            session(date(2026, 9, 13, hour: 23, minute: 59)), // Sunday 23:59 -> last week
        ])
        XCTAssertEqual(summary.thisWeek.completedSessions, 1)
        XCTAssertEqual(summary.lastWeek.completedSessions, 1)
    }

    func testFirstDayOfWeekDecidesWhichWeekASundaySessionBelongsTo() {
        let sunday = session(date(2026, 9, 13))

        let mondayStart = weekly([sunday], calendar: calendar(firstWeekday: 2))
        XCTAssertFalse(mondayStart.thisWeek.hasActivity)
        XCTAssertTrue(mondayStart.lastWeek.hasActivity)

        let sundayStart = weekly([sunday], calendar: calendar(firstWeekday: 1))
        XCTAssertTrue(sundayStart.thisWeek.hasActivity)
        XCTAssertFalse(sundayStart.lastWeek.hasActivity)
    }

    func testNowOnTheFirstDayOfTheWeekStartsAFreshWeek() {
        let summary = weekly([session(date(2026, 9, 11))], now: date(2026, 9, 14, hour: 8))
        XCTAssertFalse(summary.thisWeek.hasActivity)
        XCTAssertEqual(summary.lastWeek.completedSessions, 1)
    }

    func testWeeksAreBucketedInTheCalendarTimeZoneNotUTC() {
        let auckland = TimeZone(identifier: "Pacific/Auckland")!
        // Monday 00:30 in Auckland is still Sunday 12:30 UTC — a UTC-based split would put
        // this run in last week.
        let run = session(date(2026, 9, 14, hour: 0, minute: 30, zone: auckland))
        let summary = weekly([run], now: date(2026, 9, 16, zone: auckland), calendar: calendar(zone: auckland))
        XCTAssertEqual(summary.thisWeek.completedSessions, 1)
        XCTAssertFalse(summary.lastWeek.hasActivity)
    }

    func testADSTChangeInsideTheWeekDoesNotShiftTheBoundary() {
        let newYork = TimeZone(identifier: "America/New_York")!
        // DST ends Sunday 2026-11-01, so this Monday-start week is 25 hours long. Adding a
        // fixed 7*24h to Monday 00:00 would end the week at 23:00 on Sunday and drop this run.
        let lateSunday = session(date(2026, 11, 1, hour: 23, minute: 30, zone: newYork))
        let summary = weekly([lateSunday], now: date(2026, 10, 28, zone: newYork), calendar: calendar(zone: newYork))
        XCTAssertEqual(summary.thisWeek.completedSessions, 1)
    }

    func testWeeklyDistanceAndTimeIncludeIncompleteSessionsButTheCountDoesNot() {
        let summary = weekly([
            session(date(2026, 9, 14), durationSeconds: 600, distanceMeters: 1000, completed: true),
            session(date(2026, 9, 15), durationSeconds: 200, distanceMeters: 400, completed: false),
        ])
        XCTAssertEqual(summary.thisWeek.completedSessions, 1)
        XCTAssertEqual(summary.thisWeek.totalKm, 1.4, accuracy: 0.0001)
        XCTAssertEqual(summary.thisWeek.totalTimeSeconds, 800)
    }

    func testWeeklyCaloriesAreNilWithoutAWeight() {
        let summary = weekly([session(date(2026, 9, 14))])
        XCTAssertNil(summary.thisWeek.totalCalories)
        XCTAssertNil(summary.lastWeek.totalCalories)
    }

    func testWeeklyCaloriesSumPerSessionEstimatesForEachWeek() {
        let thisWeek = session(date(2026, 9, 14), durationSeconds: 600, distanceMeters: 1000)
        let lastWeek = session(date(2026, 9, 8), durationSeconds: 900, distanceMeters: 1500)

        let summary = weekly([thisWeek, lastWeek], weightKg: 70)
        XCTAssertEqual(summary.thisWeek.totalCalories,
                       CalorieCalculator.estimateCalories(distanceMeters: 1000, durationSeconds: 600, weightKg: 70))
        XCTAssertEqual(summary.lastWeek.totalCalories,
                       CalorieCalculator.estimateCalories(distanceMeters: 1500, durationSeconds: 900, weightKg: 70))
    }

    func testWeeklyTreadmillSessionWithoutDistanceCountsTimeButNoCalories() {
        let summary = weekly([session(date(2026, 9, 14), durationSeconds: 1800, distanceMeters: 0)], weightKg: 70)
        XCTAssertEqual(summary.thisWeek.totalTimeSeconds, 1800)
        XCTAssertEqual(summary.thisWeek.totalCalories, 0)
        XCTAssertTrue(summary.thisWeek.hasActivity)
    }

    // MARK: - Monthly

    func testMonthlyEmptyHistoryGivesZeroTotalsAndNoActivity() {
        let summary = monthly([])
        XCTAssertEqual(summary.thisMonth.completedSessions, 0)
        XCTAssertEqual(summary.thisMonth.totalKm, 0)
        XCTAssertEqual(summary.thisMonth.totalTimeSeconds, 0)
        XCTAssertFalse(summary.thisMonth.hasActivity)
        XCTAssertFalse(summary.lastMonth.hasActivity)
    }

    func testMonthlySessionsThisMonthAreSummed() {
        let summary = monthly([
            session(date(2026, 9, 1), durationSeconds: 600, distanceMeters: 1000),
            session(date(2026, 9, 30), durationSeconds: 300, distanceMeters: 500),
        ])
        XCTAssertEqual(summary.thisMonth.completedSessions, 2)
        XCTAssertEqual(summary.thisMonth.totalKm, 1.5, accuracy: 0.0001)
        XCTAssertEqual(summary.thisMonth.totalTimeSeconds, 900)
        XCTAssertTrue(summary.thisMonth.hasActivity)
        XCTAssertFalse(summary.lastMonth.hasActivity)
    }

    func testMonthlyLastMonthIsTotalledSeparatelyAndOlderMonthsAreIgnored() {
        let summary = monthly([
            session(date(2026, 9, 16), durationSeconds: 600, distanceMeters: 1000),
            session(date(2026, 8, 15), durationSeconds: 1200, distanceMeters: 2000),
            session(date(2026, 7, 1), durationSeconds: 9999, distanceMeters: 9000),
        ])
        XCTAssertEqual(summary.thisMonth.completedSessions, 1)
        XCTAssertEqual(summary.thisMonth.totalKm, 1.0, accuracy: 0.0001)
        XCTAssertEqual(summary.lastMonth.completedSessions, 1)
        XCTAssertEqual(summary.lastMonth.totalKm, 2.0, accuracy: 0.0001)
        XCTAssertEqual(summary.lastMonth.totalTimeSeconds, 1200)
    }

    func testMonthlySessionsAfterTheCurrentMonthAreNotCounted() {
        let summary = monthly([session(date(2026, 10, 1))])
        XCTAssertFalse(summary.thisMonth.hasActivity)
        XCTAssertFalse(summary.lastMonth.hasActivity)
    }

    func testMonthBoundaryFallsOnLocalMidnightOfTheFirst() {
        let summary = monthly([
            session(date(2026, 9, 1, hour: 0, minute: 0)),    // 1st 00:00 -> this month
            session(date(2026, 8, 31, hour: 23, minute: 59)), // last day 23:59 -> last month
        ])
        XCTAssertEqual(summary.thisMonth.completedSessions, 1)
        XCTAssertEqual(summary.lastMonth.completedSessions, 1)
    }

    func testFebruaryLengthDoesNotShiftTheBoundaryInALeapOrCommonYear() {
        // 2028 is a leap year (Feb has 29 days), 2026 is not (28 days). A fixed day-count
        // boundary would misplace the last day of February in one of these.
        let leapFeb = session(date(2028, 2, 29, hour: 23, minute: 30))
        XCTAssertEqual(monthly([leapFeb], now: date(2028, 3, 5)).lastMonth.completedSessions, 1)

        let commonFeb = session(date(2026, 2, 28, hour: 23, minute: 30))
        XCTAssertEqual(monthly([commonFeb], now: date(2026, 3, 5)).lastMonth.completedSessions, 1)
    }

    func testNowOnTheFirstStartsAFreshMonth() {
        let summary = monthly([session(date(2026, 8, 20))], now: date(2026, 9, 1, hour: 8))
        XCTAssertFalse(summary.thisMonth.hasActivity)
        XCTAssertEqual(summary.lastMonth.completedSessions, 1)
    }

    func testYearRollsOverFromDecemberToJanuary() {
        let summary = monthly([session(date(2025, 12, 20))], now: date(2026, 1, 10))
        XCTAssertFalse(summary.thisMonth.hasActivity)
        XCTAssertEqual(summary.lastMonth.completedSessions, 1)
    }

    func testMonthsAreBucketedInTheCalendarTimeZoneNotUTC() {
        let auckland = TimeZone(identifier: "Pacific/Auckland")!
        // 1st 00:30 in Auckland is still the last day of the previous month at 12:30 UTC — a
        // UTC-based split would put this run in last month.
        let run = session(date(2026, 9, 1, hour: 0, minute: 30, zone: auckland))
        let summary = monthly([run], now: date(2026, 9, 16, zone: auckland), calendar: calendar(zone: auckland))
        XCTAssertEqual(summary.thisMonth.completedSessions, 1)
        XCTAssertFalse(summary.lastMonth.hasActivity)
    }

    func testADSTChangeAtTheMonthBoundaryDoesNotShiftIt() {
        let newYork = TimeZone(identifier: "America/New_York")!
        // The clocks go back on 2026-11-01, the first day of the month being summarised.
        let lateOctober = session(date(2026, 10, 31, hour: 23, minute: 30, zone: newYork))
        let summary = monthly([lateOctober], now: date(2026, 11, 5, zone: newYork), calendar: calendar(zone: newYork))
        XCTAssertEqual(summary.lastMonth.completedSessions, 1)
        XCTAssertFalse(summary.thisMonth.hasActivity)
    }

    func testMonthlyDistanceAndTimeIncludeIncompleteSessionsButTheCountDoesNot() {
        let summary = monthly([
            session(date(2026, 9, 14), durationSeconds: 600, distanceMeters: 1000, completed: true),
            session(date(2026, 9, 15), durationSeconds: 200, distanceMeters: 400, completed: false),
        ])
        XCTAssertEqual(summary.thisMonth.completedSessions, 1)
        XCTAssertEqual(summary.thisMonth.totalKm, 1.4, accuracy: 0.0001)
        XCTAssertEqual(summary.thisMonth.totalTimeSeconds, 800)
    }

    func testMonthlyCaloriesAreNilWithoutAWeight() {
        let summary = monthly([session(date(2026, 9, 14))])
        XCTAssertNil(summary.thisMonth.totalCalories)
        XCTAssertNil(summary.lastMonth.totalCalories)
    }

    func testMonthlyCaloriesSumPerSessionEstimatesForEachMonth() {
        let thisMonth = session(date(2026, 9, 14), durationSeconds: 600, distanceMeters: 1000)
        let lastMonth = session(date(2026, 8, 8), durationSeconds: 900, distanceMeters: 1500)

        let summary = monthly([thisMonth, lastMonth], weightKg: 70)
        XCTAssertEqual(summary.thisMonth.totalCalories,
                       CalorieCalculator.estimateCalories(distanceMeters: 1000, durationSeconds: 600, weightKg: 70))
        XCTAssertEqual(summary.lastMonth.totalCalories,
                       CalorieCalculator.estimateCalories(distanceMeters: 1500, durationSeconds: 900, weightKg: 70))
    }

    func testMonthlyTreadmillSessionWithoutDistanceCountsTimeButNoCalories() {
        let summary = monthly([session(date(2026, 9, 14), durationSeconds: 1800, distanceMeters: 0)], weightKg: 70)
        XCTAssertEqual(summary.thisMonth.totalTimeSeconds, 1800)
        XCTAssertEqual(summary.thisMonth.totalCalories, 0)
        XCTAssertTrue(summary.thisMonth.hasActivity)
    }

    // MARK: - Shared

    func testAPeriodWithOnlyAnAbandonedSessionStillHasActivity() {
        // The comparison line ("Last week: …") keys off hasActivity, and an abandoned run
        // still covered ground, so it must count even though no workout was completed.
        let abandoned = session(date(2026, 9, 9), durationSeconds: 240, distanceMeters: 300, completed: false)
        let summary = weekly([abandoned])
        XCTAssertEqual(summary.lastWeek.completedSessions, 0)
        XCTAssertTrue(summary.lastWeek.hasActivity)
    }

    func testAPeriodWithNothingRecordedHasNoActivity() {
        XCTAssertFalse(PeriodTotals(completedSessions: 0, totalKm: 0, totalTimeSeconds: 0, totalCalories: nil).hasActivity)
        XCTAssertTrue(PeriodTotals(completedSessions: 1, totalKm: 0, totalTimeSeconds: 0, totalCalories: nil).hasActivity)
    }

    func testASessionExactlyAtTheStartOfNextWeekOrMonthIsExcluded() {
        // Upper bounds are exclusive: next Monday 00:00 / the 1st of next month 00:00.
        XCTAssertFalse(weekly([session(date(2026, 9, 21, hour: 0, minute: 0))]).thisWeek.hasActivity)
        XCTAssertFalse(monthly([session(date(2026, 10, 1, hour: 0, minute: 0))]).thisMonth.hasActivity)
    }

    func testWeekSpanningAMonthBoundaryIsSplitByTheMonthlySummaryOnly() {
        // Mon 2026-09-28 .. Sun 2026-10-04 straddles September/October.
        let now = date(2026, 10, 2)
        let sessions = [session(date(2026, 9, 29)), session(date(2026, 10, 1))]
        XCTAssertEqual(weekly(sessions, now: now).thisWeek.completedSessions, 2)
        let month = monthly(sessions, now: now)
        XCTAssertEqual(month.thisMonth.completedSessions, 1)
        XCTAssertEqual(month.lastMonth.completedSessions, 1)
    }

    func testWeekSpanningAYearBoundaryStaysInOneWeek() {
        // Mon 2025-12-29 .. Sun 2026-01-04.
        let summary = weekly([session(date(2025, 12, 30)), session(date(2025, 12, 24))], now: date(2026, 1, 2))
        XCTAssertEqual(summary.thisWeek.completedSessions, 1)
        XCTAssertEqual(summary.lastWeek.completedSessions, 1)
    }

    func testDefaultArgumentsUseTheCurrentCalendarAndTime() {
        let summary = WorkoutStats.weeklySummary(sessions: [session(.now)])
        XCTAssertEqual(summary.thisWeek.completedSessions, 1)
        XCTAssertEqual(WorkoutStats.monthlySummary(sessions: [session(.now)]).thisMonth.completedSessions, 1)
    }
}

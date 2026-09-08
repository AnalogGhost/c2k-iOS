import XCTest
@testable import CtoK

final class WorkoutStatsTests: XCTestCase {

    private let utc = Calendar(identifier: .gregorian).withUTC()

    private func session(programId: String = "C25K", week: Int = 1, day: Int = 1,
                          daysAgo: Int, completed: Bool = true,
                          distanceMeters: Double = 0, durationSeconds: Int = 0,
                          now: Date, calendar: Calendar) -> WorkoutSession {
        let s = WorkoutSession(programId: programId, week: week, day: day)
        s.startedAt = calendar.date(byAdding: .day, value: -daysAgo, to: now)!
        s.completed = completed
        s.distanceMeters = distanceMeters
        s.durationSeconds = durationSeconds
        return s
    }

    // MARK: - Streak
    //
    // Weekly, not daily (matches Android issue #29): a program schedules ~3 runs a week with
    // rest days between, so tests exercise week-granularity — one completed session per week
    // is enough to keep a streak alive, spaced 7+ days apart with rest days in between.

    func testStreakIsZeroWithNoSessions() {
        XCTAssertEqual(WorkoutStats.streak(sessions: []), 0)
    }

    func testStreakIsZeroWhenNoCompletedSessions() {
        let now = Date.now
        let s = session(daysAgo: 0, completed: false, now: now, calendar: utc)
        XCTAssertEqual(WorkoutStats.streak(sessions: [s], now: now, calendar: utc), 0)
    }

    func testStreakOfOneForSingleSessionThisWeek() {
        let now = Date.now
        let s = session(daysAgo: 0, now: now, calendar: utc)
        XCTAssertEqual(WorkoutStats.streak(sessions: [s], now: now, calendar: utc), 1)
    }

    func testStreakSurvivesRestDaysWithinTheSameWeek() {
        // Three sessions within the same calendar week (Mon/Wed/Fri) with rest days between
        // them should still be a streak of 1 week, not broken by the day-level gaps. Pin
        // `now` to a Friday so the 4-day lookback stays inside one ISO week regardless of
        // when the test runs.
        var comps = DateComponents()
        comps.year = 2026; comps.month = 6; comps.day = 12 // Friday
        let now = utc.date(from: comps)!
        let sessions = [0, 2, 4].map { session(daysAgo: $0, now: now, calendar: utc) }
        XCTAssertEqual(WorkoutStats.streak(sessions: sessions, now: now, calendar: utc), 1)
    }

    func testStreakCountsConsecutiveWeeksEndingThisWeek() {
        let now = Date.now
        // One completed session per week for 4 consecutive weeks, most recent this week.
        let sessions = (0..<4).map { session(daysAgo: $0 * 7, now: now, calendar: utc) }
        XCTAssertEqual(WorkoutStats.streak(sessions: sessions, now: now, calendar: utc), 4)
    }

    func testStreakStillCountsIfLastWorkoutWasLastWeek() {
        let now = Date.now
        // Weeks 1-3 ago completed, this week not yet — still alive via the grace period.
        let sessions = (1..<4).map { session(daysAgo: $0 * 7, now: now, calendar: utc) }
        XCTAssertEqual(WorkoutStats.streak(sessions: sessions, now: now, calendar: utc), 3)
    }

    func testStreakBreaksOnAGapOfTwoOrMoreWeeks() {
        let now = Date.now
        // This week, last week, then a gap (2 weeks ago missing), then 3 weeks ago.
        let sessions = [
            session(daysAgo: 0, now: now, calendar: utc),
            session(daysAgo: 7, now: now, calendar: utc),
            session(daysAgo: 21, now: now, calendar: utc),
        ]
        XCTAssertEqual(WorkoutStats.streak(sessions: sessions, now: now, calendar: utc), 2)
    }

    func testStreakIsZeroIfMostRecentWorkoutWasTwoWeeksAgo() {
        let now = Date.now
        let s = session(daysAgo: 14, now: now, calendar: utc)
        XCTAssertEqual(WorkoutStats.streak(sessions: [s], now: now, calendar: utc), 0)
    }

    func testStreakDedupesMultipleSessionsInTheSameWeek() {
        let now = Date.now
        let sessions = [
            session(daysAgo: 0, now: now, calendar: utc),
            session(daysAgo: 1, now: now, calendar: utc),
            session(daysAgo: 7, now: now, calendar: utc),
        ]
        XCTAssertEqual(WorkoutStats.streak(sessions: sessions, now: now, calendar: utc), 2)
    }

    func testStreakUsesLocalCalendarWeekNotUTC() {
        // Two workouts that land in different LOCAL calendar weeks (Sunday 11:30pm and the
        // following Monday 12:30am Pacific) but the same UTC calendar day/week, since Pacific
        // is UTC-7 in June. A streak bucketed by UTC — the original iOS port's bug, which used
        // timeIntervalSince1970/86400 instead of Android's ZoneId.systemDefault() local-date
        // bucketing — could misplace a session near a week boundary into the wrong week.
        var pacific = Calendar(identifier: .gregorian)
        pacific.timeZone = TimeZone(identifier: "America/Los_Angeles")!

        // 2026-06-14 is a Sunday, so this session falls in the ISO week ending that Sunday.
        var comps = DateComponents()
        comps.year = 2026; comps.month = 6; comps.day = 14; comps.hour = 23; comps.minute = 30
        let sessionA = pacific.date(from: comps)! // Sunday, 11:30pm local — last day of its week

        // 2026-06-15 is the following Monday — the first day of the *next* ISO week.
        comps.day = 15; comps.hour = 0; comps.minute = 30
        let sessionB = pacific.date(from: comps)! // Monday, 12:30am local — next local week

        let sessions = [makeSession(startedAt: sessionA), makeSession(startedAt: sessionB)]
        XCTAssertEqual(WorkoutStats.streak(sessions: sessions, now: sessionB, calendar: pacific), 2)
    }

    private func makeSession(startedAt: Date) -> WorkoutSession {
        let s = WorkoutSession(programId: "C25K", week: 1, day: 1)
        s.startedAt = startedAt
        s.completed = true
        return s
    }

    // MARK: - Aggregation

    func testTotalCaloriesIsNilWithoutWeight() {
        let s = makeSession(startedAt: .now)
        s.distanceMeters = 5000
        s.durationSeconds = 1800
        XCTAssertNil(WorkoutStats.totalCalories(sessions: [s], weightKg: nil))
    }

    func testTotalCaloriesSumsAcrossSessions() {
        let a = makeSession(startedAt: .now); a.distanceMeters = 5000; a.durationSeconds = 1800
        let b = makeSession(startedAt: .now); b.distanceMeters = 5000; b.durationSeconds = 1800
        let total = WorkoutStats.totalCalories(sessions: [a, b], weightKg: 70)
        let single = CalorieCalculator.estimateCalories(distanceMeters: 5000, durationSeconds: 1800, weightKg: 70)!
        XCTAssertEqual(total, single * 2)
    }

    func testFastestPaceIgnoresSessionsWithNoDistance() {
        let noDistance = makeSession(startedAt: .now)
        noDistance.durationSeconds = 600
        let withDistance = makeSession(startedAt: .now)
        withDistance.distanceMeters = 1000
        withDistance.durationSeconds = 300
        let pace = WorkoutStats.fastestPaceSecPerKm(sessions: [noDistance, withDistance])
        XCTAssertEqual(pace, 300)
    }

    func testFastestPaceIgnoresIncompleteSessions() {
        let incomplete = makeSession(startedAt: .now)
        incomplete.completed = false
        incomplete.distanceMeters = 1000
        incomplete.durationSeconds = 100 // would be the fastest pace if it counted
        let completed = makeSession(startedAt: .now)
        completed.distanceMeters = 1000
        completed.durationSeconds = 300
        let pace = WorkoutStats.fastestPaceSecPerKm(sessions: [incomplete, completed])
        XCTAssertEqual(pace, 300)
    }

    func testLongestRunPicksMaxDistance() {
        let short = makeSession(startedAt: .now); short.distanceMeters = 3000
        let long = makeSession(startedAt: .now); long.distanceMeters = 8000
        XCTAssertEqual(WorkoutStats.longestRunMeters(sessions: [short, long]), 8000)
    }

    func testLongestRunIsNilWithNoEligibleSessions() {
        let noDistance = makeSession(startedAt: .now)
        XCTAssertNil(WorkoutStats.longestRunMeters(sessions: [noDistance]))
    }
}

private extension Calendar {
    func withUTC() -> Calendar {
        var cal = self
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }
}

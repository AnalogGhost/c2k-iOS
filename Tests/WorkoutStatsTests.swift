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

    func testStreakIsZeroWithNoSessions() {
        XCTAssertEqual(WorkoutStats.streak(sessions: []), 0)
    }

    func testStreakIsZeroWhenNoCompletedSessions() {
        let now = Date.now
        let s = session(daysAgo: 0, completed: false, now: now, calendar: utc)
        XCTAssertEqual(WorkoutStats.streak(sessions: [s], now: now, calendar: utc), 0)
    }

    func testStreakOfOneForSingleSessionToday() {
        let now = Date.now
        let s = session(daysAgo: 0, now: now, calendar: utc)
        XCTAssertEqual(WorkoutStats.streak(sessions: [s], now: now, calendar: utc), 1)
    }

    func testStreakCountsConsecutiveDaysEndingToday() {
        let now = Date.now
        let sessions = (0..<4).map { session(daysAgo: $0, now: now, calendar: utc) }
        XCTAssertEqual(WorkoutStats.streak(sessions: sessions, now: now, calendar: utc), 4)
    }

    func testStreakStillCountsIfLastWorkoutWasYesterday() {
        let now = Date.now
        let sessions = (1..<4).map { session(daysAgo: $0, now: now, calendar: utc) }
        XCTAssertEqual(WorkoutStats.streak(sessions: sessions, now: now, calendar: utc), 3)
    }

    func testStreakBreaksOnAGapOfTwoOrMoreDays() {
        let now = Date.now
        // Today, yesterday, then a gap (2 days ago missing), then 3 days ago.
        let sessions = [
            session(daysAgo: 0, now: now, calendar: utc),
            session(daysAgo: 1, now: now, calendar: utc),
            session(daysAgo: 3, now: now, calendar: utc),
        ]
        XCTAssertEqual(WorkoutStats.streak(sessions: sessions, now: now, calendar: utc), 2)
    }

    func testStreakIsZeroIfMostRecentWorkoutWasTwoDaysAgo() {
        let now = Date.now
        let s = session(daysAgo: 2, now: now, calendar: utc)
        XCTAssertEqual(WorkoutStats.streak(sessions: [s], now: now, calendar: utc), 0)
    }

    func testStreakDedupesMultipleSessionsOnTheSameDay() {
        let now = Date.now
        let sessions = [
            session(daysAgo: 0, now: now, calendar: utc),
            session(daysAgo: 0, now: now, calendar: utc),
            session(daysAgo: 1, now: now, calendar: utc),
        ]
        XCTAssertEqual(WorkoutStats.streak(sessions: sessions, now: now, calendar: utc), 2)
    }

    func testStreakUsesLocalCalendarDayNotUTC() {
        // Two workouts on two different LOCAL calendar days (11:30pm and the following
        // 12:30am Pacific) that land on the *same* UTC calendar day, since Pacific is
        // UTC-7 in June (both convert to ~06:30/07:30 UTC on the same UTC date). A streak
        // bucketed by UTC epoch day — the original iOS port's bug, which used
        // timeIntervalSince1970/86400 instead of Android's ZoneId.systemDefault()
        // local-date bucketing — would collapse these into one day and report a streak
        // of 1 instead of 2.
        var pacific = Calendar(identifier: .gregorian)
        pacific.timeZone = TimeZone(identifier: "America/Los_Angeles")!

        var comps = DateComponents()
        comps.year = 2026; comps.month = 6; comps.day = 15; comps.hour = 23; comps.minute = 30
        let sessionA = pacific.date(from: comps)! // June 15, 11:30pm local

        comps.day = 16; comps.hour = 0; comps.minute = 30
        let sessionB = pacific.date(from: comps)! // June 16, 12:30am local — next local day

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

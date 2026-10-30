import XCTest
@testable import CtoK

// Ported from the Android app's ProgressionAdvisorTest.
final class ProgressionAdvisorTests: XCTestCase {

    private func plan(id: String = "test", weeks: Int = 4) -> WorkoutPlan {
        WorkoutPlan(
            programId: id, displayName: "Test Plan", description: "",
            weeks: (1...weeks).map { w in
                (1...3).map { d in WorkoutDay(week: w, day: d, intervals: [Interval(type: .run, durationSeconds: 600)]) }
            },
            prerequisite: nil
        )
    }

    private func at(_ seconds: Double) -> Date { Date(timeIntervalSince1970: seconds) }

    private func session(_ week: Int, _ day: Int, startedAt: Double, completed: Bool,
                         durationSeconds: Int = 600, programId: String = "test") -> WorkoutSession {
        let s = WorkoutSession(programId: programId, week: week, day: day)
        s.startedAt = at(startedAt)
        s.completed = completed
        s.durationSeconds = durationSeconds
        return s
    }

    private func stoppedEarly(_ week: Int, _ day: Int, startedAt: Double,
                              durationSeconds: Int = 600, programId: String = "test") -> WorkoutSession {
        session(week, day, startedAt: startedAt, completed: false, durationSeconds: durationSeconds, programId: programId)
    }

    // MARK: - suggest

    func testOneEarlyStopIsNotEnough() {
        let sessions = [stoppedEarly(3, 2, startedAt: 10)]
        XCTAssertNil(ProgressionAdvisor.suggest(plan: plan(), week: 3, day: 2, sessions: sessions, dismissedAt: nil))
    }

    func testTwoEarlyStopsSuggestRepeatingThePreviousWeek() {
        let sessions = [stoppedEarly(3, 2, startedAt: 10), stoppedEarly(3, 2, startedAt: 20)]
        XCTAssertEqual(ProgressionAdvisor.suggest(plan: plan(), week: 3, day: 2, sessions: sessions, dismissedAt: nil),
                       .repeatWeek(week: 2, earlyStops: 2))
    }

    func testAttemptsShorterThanTheMinimumDoNotCount() {
        let sessions = [
            stoppedEarly(3, 2, startedAt: 10, durationSeconds: ProgressionAdvisor.minAttemptSeconds - 1),
            stoppedEarly(3, 2, startedAt: 20),
        ]
        XCTAssertNil(ProgressionAdvisor.suggest(plan: plan(), week: 3, day: 2, sessions: sessions, dismissedAt: nil))
    }

    func testEarlyStopsOnOtherDaysOrProgramsDoNotCount() {
        let sessions = [
            stoppedEarly(3, 2, startedAt: 10),
            stoppedEarly(3, 1, startedAt: 20),
            stoppedEarly(3, 2, startedAt: 30, programId: "other"),
        ]
        XCTAssertNil(ProgressionAdvisor.suggest(plan: plan(), week: 3, day: 2, sessions: sessions, dismissedAt: nil))
    }

    func testEarlyStopsBeforeTheLastFinishedWorkoutDoNotCount() {
        // The runner struggled, repeated week 2 (finishing it at 30), and is back on week 3 day 2.
        let sessions = [
            stoppedEarly(3, 2, startedAt: 10),
            stoppedEarly(3, 2, startedAt: 20),
            session(2, 3, startedAt: 30, completed: true),
        ]
        XCTAssertNil(ProgressionAdvisor.suggest(plan: plan(), week: 3, day: 2, sessions: sessions, dismissedAt: nil))
    }

    func testDismissingHoldsUntilTheRunnerStrugglesAgain() {
        let before = [stoppedEarly(3, 2, startedAt: 10), stoppedEarly(3, 2, startedAt: 20)]
        XCTAssertNil(ProgressionAdvisor.suggest(plan: plan(), week: 3, day: 2, sessions: before, dismissedAt: at(25)))

        let oneMore = before + [stoppedEarly(3, 2, startedAt: 30)]
        XCTAssertNil(ProgressionAdvisor.suggest(plan: plan(), week: 3, day: 2, sessions: oneMore, dismissedAt: at(25)))
    }

    func testSuggestionAfterDismissingReportsEveryEarlyStopNotJustTheNewOnes() {
        let sessions = [10.0, 20, 30, 40].map { stoppedEarly(3, 2, startedAt: $0) }
        XCTAssertEqual(ProgressionAdvisor.suggest(plan: plan(), week: 3, day: 2, sessions: sessions, dismissedAt: at(25)),
                       .repeatWeek(week: 2, earlyStops: 4))
    }

    func testC25KWeekOneSuggestsPreC25K() {
        let sessions = [
            stoppedEarly(1, 1, startedAt: 10, programId: Programs.idC25K),
            stoppedEarly(1, 1, startedAt: 20, programId: Programs.idC25K),
        ]
        XCTAssertEqual(ProgressionAdvisor.suggest(plan: Programs.byId(Programs.idC25K), week: 1, day: 1,
                                                  sessions: sessions, dismissedAt: nil),
                       .tryPreC25K(earlyStops: 2))
    }

    func testWeekOneOfAnotherProgramHasNothingToSuggest() {
        let sessions = [stoppedEarly(1, 1, startedAt: 10), stoppedEarly(1, 1, startedAt: 20)]
        XCTAssertNil(ProgressionAdvisor.suggest(plan: plan(), week: 1, day: 1, sessions: sessions, dismissedAt: nil))
    }

    // MARK: - nextInRepeatedWeek

    private var repeatWeek2: RepeatedWeek { RepeatedWeek(programId: "test", week: 2, since: at(100)) }

    func testRepeatedWeekStartsAtItsFirstDayEvenThoughItWasFinishedBefore() {
        let sessions = (1...3).map { session(2, $0, startedAt: Double($0), completed: true) }
        XCTAssertEqual(ProgressionAdvisor.nextInRepeatedWeek(plan: plan(), repeated: repeatWeek2, sessions: sessions),
                       WeekDay(week: 2, day: 1))
    }

    func testRepeatedWeekMovesOnAsDaysAreFinishedAgain() {
        let sessions = [session(2, 1, startedAt: 110, completed: true), session(2, 2, startedAt: 120, completed: false)]
        XCTAssertEqual(ProgressionAdvisor.nextInRepeatedWeek(plan: plan(), repeated: repeatWeek2, sessions: sessions),
                       WeekDay(week: 2, day: 2))
    }

    func testRepeatedWeekEndsOnceEveryDayIsFinishedAgain() {
        let sessions = (1...3).map { session(2, $0, startedAt: 100 + Double($0), completed: true) }
        XCTAssertNil(ProgressionAdvisor.nextInRepeatedWeek(plan: plan(), repeated: repeatWeek2, sessions: sessions))
    }

    func testRepeatedWeekOfAnotherProgramIsIgnored() {
        XCTAssertNil(ProgressionAdvisor.nextInRepeatedWeek(plan: plan(id: "other"), repeated: repeatWeek2, sessions: []))
    }
}

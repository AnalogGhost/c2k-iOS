import XCTest
@testable import CtoK

final class CelebrationTests: XCTestCase {
    private let finished = WorkoutState.completed(sessionId: UUID(), elapsedSessionSeconds: 1800, skippedRun: false)
    private let skipped = WorkoutState.completed(sessionId: UUID(), elapsedSessionSeconds: 1800, skippedRun: true)
    private let c25k = Programs.c25K

    private func celebration(_ state: WorkoutState, _ plan: WorkoutPlan, week: Int, day: Int,
                             weekThreeCelebrated: Bool = false) -> Celebration? {
        CelebrationTrigger.celebration(after: state, plan: plan, week: week, day: day,
                                       weekThreeCelebrated: weekThreeCelebrated)
    }

    // MARK: - Program completion

    func testTheLastWorkoutOfEveryProgramIsCelebrated() {
        for plan in Programs.all() {
            let last = plan.weeks.last!.last!
            XCTAssertEqual(celebration(finished, plan, week: last.week, day: last.day), .programFinished, plan.programId)
        }
    }

    func testOtherWorkoutsAreNotCelebrated() {
        XCTAssertNil(celebration(finished, c25k, week: 1, day: 1))
        XCTAssertNil(celebration(finished, c25k, week: 9, day: 2))
        XCTAssertNil(celebration(finished, c25k, week: 3, day: 2))
    }

    func testASkippedRunOnTheLastDayIsNotCelebrated() {
        XCTAssertNil(celebration(skipped, c25k, week: 9, day: 3))
    }

    func testNothingFiresMidWorkout() {
        let active = WorkoutState.ActiveSnapshot(
            currentInterval: Interval(type: .cooldown, durationSeconds: 300), nextInterval: nil,
            intervalIndex: 2, totalIntervals: 3, remainingRunIntervals: 0,
            secondsRemainingInInterval: 1, elapsedSessionSeconds: 1799, sessionId: UUID())
        XCTAssertNil(celebration(.active(active), c25k, week: 9, day: 3))
        XCTAssertNil(celebration(.paused(snapshot: active), c25k, week: 9, day: 3))
        XCTAssertNil(celebration(.idle, c25k, week: 9, day: 3))
    }

    // MARK: - Week 3

    func testTheLastWorkoutOfWeekThreeIsCelebratedOnce() {
        XCTAssertEqual(celebration(finished, c25k, week: 3, day: 3), .weekThree)
        XCTAssertNil(celebration(finished, c25k, week: 3, day: 3, weekThreeCelebrated: true))
    }

    func testPreC25KWeekThreeIsItsProgramCompletion() {
        XCTAssertEqual(celebration(finished, Programs.preC25K, week: 3, day: 3), .programFinished)
    }

    func testEvaluateRecordsWeekThreeSoItNeverFiresTwice() {
        let defaults = UserDefaults(suiteName: "CelebrationTests-\(UUID())")!
        XCTAssertEqual(CelebrationTrigger.evaluate(after: finished, plan: c25k, week: 3, day: 3, defaults: defaults), .weekThree)
        XCTAssertNil(CelebrationTrigger.evaluate(after: finished, plan: Programs.c210K, week: 3, day: 3, defaults: defaults))
    }

    func testFinishingAProgramAlsoUsesUpWeekThree() {
        let defaults = UserDefaults(suiteName: "CelebrationTests-\(UUID())")!
        XCTAssertEqual(CelebrationTrigger.evaluate(after: finished, plan: Programs.preC25K, week: 3, day: 3, defaults: defaults),
                       .programFinished)
        XCTAssertNil(CelebrationTrigger.evaluate(after: finished, plan: c25k, week: 3, day: 3, defaults: defaults))
    }

    func testASkippedRunDoesNotUseUpWeekThree() {
        let defaults = UserDefaults(suiteName: "CelebrationTests-\(UUID())")!
        XCTAssertNil(CelebrationTrigger.evaluate(after: skipped, plan: c25k, week: 3, day: 3, defaults: defaults))
        XCTAssertEqual(CelebrationTrigger.evaluate(after: finished, plan: c25k, week: 3, day: 3, defaults: defaults), .weekThree)
    }
}

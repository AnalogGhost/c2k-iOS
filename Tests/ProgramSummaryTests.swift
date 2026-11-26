import XCTest
@testable import CtoK

final class ProgramSummaryTests: XCTestCase {

    private func session(_ programId: String = "C25K", seconds: Int, meters: Double,
                         completed: Bool = true) -> WorkoutSession {
        let s = WorkoutSession(programId: programId, week: 1, day: 1)
        s.durationSeconds = seconds
        s.distanceMeters = meters
        s.completed = completed
        return s
    }

    func testAddsTheFinishedWorkoutToTheProgramsEarlierOnes() {
        let earlier = [session(seconds: 1800, meters: 3000), session(seconds: 1500, meters: 2500)]
        let summary = ProgramSummary.of(sessions: earlier, programId: "C25K", currentId: UUID(),
                                        durationSeconds: 2000, distanceMeters: 4000)
        XCTAssertEqual(summary, ProgramSummary(workouts: 3, durationSeconds: 5300, distanceMeters: 9500))
    }

    func testLeavesOutEarlyStopsAndOtherPrograms() {
        let sessions = [session(seconds: 600, meters: 900, completed: false),
                        session("C210K", seconds: 1800, meters: 3000)]
        let summary = ProgramSummary.of(sessions: sessions, programId: "C25K", currentId: UUID(),
                                        durationSeconds: 2000, distanceMeters: 0)
        XCTAssertEqual(summary, ProgramSummary(workouts: 1, durationSeconds: 2000, distanceMeters: 0))
    }

    func testTheFinishedWorkoutIsNotCountedTwiceOnceSaved() {
        let current = session(seconds: 2000, meters: 4000)
        let summary = ProgramSummary.of(sessions: [current, session(seconds: 1800, meters: 3000)],
                                        programId: "C25K", currentId: current.id,
                                        durationSeconds: 2000, distanceMeters: 4000)
        XCTAssertEqual(summary.workouts, 2)
        XCTAssertEqual(summary.durationSeconds, 3800)
    }

    // MARK: - Next programs

    func testEveryProgramButOneHourRunnerSuggestsAnother() {
        for plan in Programs.all() {
            let next = Programs.nextPrograms(after: plan.programId)
            XCTAssertFalse(next.contains(plan.programId), plan.programId)
            XCTAssertEqual(next.isEmpty, plan.programId == Programs.idOHR, plan.programId)
            for id in next { XCTAssertTrue(Programs.all().contains { $0.programId == id }, id) }
        }
    }

    func testPreC25KLeadsToCouchTo5K() {
        XCTAssertEqual(Programs.nextPrograms(after: Programs.idPreC25K), [Programs.idC25K])
    }
}

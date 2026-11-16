import XCTest
import SwiftData
@testable import CtoK

@MainActor
final class SessionRepositoryTests: XCTestCase {

    private var context: ModelContext!
    private var repo: SessionRepository!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: WorkoutSession.self, RoutePoint.self, configurations: config)
        context = ModelContext(container)
        repo = SessionRepository(context: context)
    }

    // MARK: - Persistence round-trips

    func testStartAndFinishSessionPersistsFields() {
        let id = repo.startSession(programId: "C25K", week: 1, day: 1)
        repo.finishSession(id: id, durationSeconds: 1800, distanceMeters: 5000, completed: true)

        let completed = repo.completedDays(programId: "C25K")
        XCTAssertEqual(completed, [WeekDay(week: 1, day: 1)])
    }

    func testDeleteSessionRemovesItAndItsRoutePoints() {
        let id = repo.startSession(programId: "C25K", week: 1, day: 1)
        repo.addRoutePoint(RoutePoint(sessionId: id, update: LocationUpdate(
            latitude: 50, longitude: 0, altitudeMeters: nil, speedMps: nil, timestamp: .now
        )))
        repo.finishSession(id: id, durationSeconds: 100, distanceMeters: 10, completed: true)

        repo.deleteSession(id: id)

        XCTAssertTrue(repo.completedDays(programId: "C25K").isEmpty)
        XCTAssertTrue(repo.routePoints(sessionId: id).isEmpty)
    }

    func testResetProgressClearsOnlyTheGivenProgram() {
        let keptId = repo.startSession(programId: "C210K", week: 1, day: 1)
        repo.finishSession(id: keptId, durationSeconds: 100, distanceMeters: 10, completed: true)

        let clearedId = repo.startSession(programId: "C25K", week: 1, day: 1)
        repo.finishSession(id: clearedId, durationSeconds: 100, distanceMeters: 10, completed: true)

        repo.resetProgress(programId: "C25K")

        XCTAssertTrue(repo.completedDays(programId: "C25K").isEmpty)
        XCTAssertEqual(repo.completedDays(programId: "C210K"), [WeekDay(week: 1, day: 1)])
    }

    // MARK: - recomputeSessionDistances (issue #30)

    private func addRoute(to id: UUID, points: [(lat: Double, atSeconds: Double)]) {
        for p in points {
            repo.addRoutePoint(RoutePoint(sessionId: id, update: LocationUpdate(
                latitude: p.lat, longitude: 0, altitudeMeters: nil, speedMps: nil,
                timestamp: Date(timeIntervalSince1970: p.atSeconds)
            )))
        }
    }

    func testRecomputeRepairsDistanceInflatedByATeleportingFix() {
        let id = repo.startSession(programId: "C25K", week: 1, day: 1)
        // Same pattern as issue #30: a spike point ~111 km away and back, which the
        // pre-fix recorder had already summed into the stored (inflated) distance.
        addRoute(to: id, points: [
            (50.0000, 0), (50.0001, 5), (51.0000, 10), (50.0002, 15), (50.0003, 20),
        ])
        repo.finishSession(id: id, durationSeconds: 20, distanceMeters: 250_000, completed: true)

        repo.recomputeSessionDistances()

        let fixed = try! context.fetch(FetchDescriptor<WorkoutSession>()).first { $0.id == id }
        XCTAssertEqual(fixed?.distanceMeters ?? -1, 22.2, accuracy: 1)
    }

    func testRecomputeLeavesSessionsWithoutARouteUntouched() {
        // Treadmill mode / GPS off: no route points, so the recorded distance (from manual
        // entry or a different source) must be preserved rather than zeroed out.
        let id = repo.startSession(programId: "C25K", week: 1, day: 1)
        repo.finishSession(id: id, durationSeconds: 1800, distanceMeters: 5000, completed: true)

        repo.recomputeSessionDistances()

        let session = try! context.fetch(FetchDescriptor<WorkoutSession>()).first { $0.id == id }
        XCTAssertEqual(session?.distanceMeters, 5000)
    }

    func testRecomputeLeavesACleanSessionsDistanceUnchanged() {
        let id = repo.startSession(programId: "C25K", week: 1, day: 1)
        // ~11.1 m per 0.0001° segment, 4 clean segments.
        addRoute(to: id, points: (0..<5).map { i in (50.0 + Double(i) * 0.0001, Double(i) * 5) })
        let filtered = DistanceCalculator.filteredDistanceMeters(points: repo.routePoints(sessionId: id))
        repo.finishSession(id: id, durationSeconds: 20, distanceMeters: filtered, completed: true)

        repo.recomputeSessionDistances()

        let session = try! context.fetch(FetchDescriptor<WorkoutSession>()).first { $0.id == id }
        XCTAssertEqual(session?.distanceMeters, filtered)
    }

    // MARK: - Interrupted workouts

    private func session(_ id: UUID) throws -> WorkoutSession? {
        try context.fetch(FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.id == id })).first
    }

    func testCheckpointSavesProgressOfARunningWorkoutOnly() throws {
        let running = repo.startSession(programId: "C25K", week: 1, day: 1)
        repo.checkpointSession(id: running, durationSeconds: 600, distanceMeters: 1500)
        XCTAssertEqual(try session(running)?.durationSeconds, 600)
        XCTAssertEqual(try session(running)?.distanceMeters, 1500)

        let ended = repo.startSession(programId: "C25K", week: 1, day: 2)
        repo.finishSession(id: ended, durationSeconds: 1800, distanceMeters: 5000, completed: true)
        repo.checkpointSession(id: ended, durationSeconds: 900, distanceMeters: 2000)
        XCTAssertEqual(try session(ended)?.durationSeconds, 1800)
    }

    func testRecoveryKeepsAnInterruptedRunAndRebuildsItsDistanceFromTheRoute() throws {
        let id = repo.startSession(programId: "C25K", week: 1, day: 1)
        repo.checkpointSession(id: id, durationSeconds: 900, distanceMeters: 100)
        // ~1.1 km north at a jogging pace, recorded after the last checkpoint.
        addRoute(to: id, points: [(0, 0), (0.005, 200), (0.01, 400)])

        XCTAssertEqual(repo.recoverInterruptedSessions(startedBefore: .now.addingTimeInterval(1)), 1)
        let s = try XCTUnwrap(try session(id))
        XCTAssertEqual(s.durationSeconds, 900)
        XCTAssertEqual(s.distanceMeters, 1112, accuracy: 5)
        XCTAssertNil(s.completedAt)
        XCTAssertFalse(s.completed)
    }

    func testRecoveryRemovesARunClosedBeforeAnythingWasSaved() throws {
        let id = repo.startSession(programId: "C25K", week: 1, day: 1)
        XCTAssertEqual(repo.recoverInterruptedSessions(startedBefore: .now.addingTimeInterval(1)), 0)
        XCTAssertNil(try session(id))
    }

    func testRecoveryLeavesEndedAndJustStartedWorkoutsAlone() throws {
        let ended = repo.startSession(programId: "C25K", week: 1, day: 1)
        repo.finishSession(id: ended, durationSeconds: 1800, distanceMeters: 5000, completed: false)
        let cutoff = Date.now
        let fresh = repo.startSession(programId: "C25K", week: 1, day: 2)
        try XCTUnwrap(try session(fresh)).startedAt = cutoff.addingTimeInterval(1)

        XCTAssertEqual(repo.recoverInterruptedSessions(startedBefore: cutoff), 0)
        XCTAssertEqual(try session(ended)?.distanceMeters, 5000)
        XCTAssertNotNil(try session(fresh))
    }
}

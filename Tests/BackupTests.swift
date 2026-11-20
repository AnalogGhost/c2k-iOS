import XCTest
import SwiftData
@testable import CtoK

@MainActor
final class BackupTests: XCTestCase {

    private var containers: [ModelContainer] = []

    private func makeRepository() throws -> (SessionRepository, ModelContext) {
        let container = try ModelContainer(for: WorkoutSession.self, RoutePoint.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        containers.append(container)
        let context = ModelContext(container)
        return (SessionRepository(context: context), context)
    }

    private func sessions(_ context: ModelContext) -> [WorkoutSession] {
        (try? context.fetch(FetchDescriptor<WorkoutSession>(sortBy: [SortDescriptor(\.startedAt)]))) ?? []
    }

    @discardableResult
    private func addSession(_ context: ModelContext, startedAt ms: Int64, completed: Bool = true,
                            ended: Bool = true, programId: String = Programs.idC25K, points: Int = 0) -> UUID {
        let session = WorkoutSession(programId: programId, week: 2, day: 3)
        session.startedAt = Date(millisecondsSince1970: ms)
        session.completedAt = ended ? Date(millisecondsSince1970: ms + 1_800_000) : nil
        session.durationSeconds = 1800
        session.distanceMeters = 3210.5
        session.completed = completed
        context.insert(session)
        for i in 0..<points {
            context.insert(RoutePoint(sessionId: session.id, update: LocationUpdate(
                latitude: 51.5 + Double(i) * 0.0001, longitude: -0.12,
                altitudeMeters: i == 0 ? nil : 20, speedMps: i == 0 ? nil : 2.5,
                timestamp: Date(millisecondsSince1970: ms + Int64(i) * 5_000))))
        }
        try? context.save()
        return session.id
    }

    /// Export from one store, through the file format, into another.
    private func transfer(from source: SessionRepository, to target: SessionRepository) throws -> Int {
        try target.importBackup(Backup.decode(source.exportBackup().encoded()))
    }

    func testAHistorySurvivesExportAndImport() throws {
        let (source, sourceContext) = try makeRepository()
        let (target, targetContext) = try makeRepository()
        addSession(sourceContext, startedAt: 1_000_000, points: 3)
        addSession(sourceContext, startedAt: 2_000_000, completed: false, ended: false)

        XCTAssertEqual(try transfer(from: source, to: target), 2)

        let imported = sessions(targetContext)
        XCTAssertEqual(imported.count, 2)
        let first = imported[0]
        XCTAssertEqual(first.programId, Programs.idC25K)
        XCTAssertEqual(first.week, 2)
        XCTAssertEqual(first.day, 3)
        XCTAssertEqual(first.completedAt?.millisecondsSince1970, 2_800_000)
        XCTAssertEqual(first.durationSeconds, 1800)
        XCTAssertEqual(first.distanceMeters, 3210.5)
        XCTAssertTrue(first.completed)
        // A run the app was closed during keeps its missing end time.
        XCTAssertNil(imported[1].completedAt)

        let route = target.routePoints(sessionId: first.id)
        XCTAssertEqual(route.count, 3)
        XCTAssertNil(route[0].altitudeMeters)
        XCTAssertNil(route[0].speedMps)
        XCTAssertEqual(route[1].altitudeMeters, 20)
        XCTAssertEqual(route[1].speedMps, 2.5)
        XCTAssertEqual(route[1].timestamp.millisecondsSince1970, 1_005_000)
    }

    func testImportingTwiceAddsNothingTheSecondTime() throws {
        let (source, sourceContext) = try makeRepository()
        let (target, targetContext) = try makeRepository()
        addSession(sourceContext, startedAt: 1_000_000, points: 2)

        XCTAssertEqual(try transfer(from: source, to: target), 1)
        XCTAssertEqual(try transfer(from: source, to: target), 0)
        XCTAssertEqual(sessions(targetContext).count, 1)
        XCTAssertEqual(target.routePoints(sessionId: sessions(targetContext)[0].id).count, 2)
    }

    func testImportMergesWithWorkoutsAlreadyHere() throws {
        let (source, sourceContext) = try makeRepository()
        let (target, targetContext) = try makeRepository()
        addSession(sourceContext, startedAt: 1_000_000)
        addSession(sourceContext, startedAt: 2_000_000)
        addSession(targetContext, startedAt: 2_000_000)
        addSession(targetContext, startedAt: 3_000_000)

        XCTAssertEqual(try transfer(from: source, to: target), 1)
        XCTAssertEqual(sessions(targetContext).map(\.startedAt.millisecondsSince1970), [1_000_000, 2_000_000, 3_000_000])
    }

    func testWorkoutsFromAnUnknownProgramAreSkipped() throws {
        let (source, sourceContext) = try makeRepository()
        let (target, _) = try makeRepository()
        addSession(sourceContext, startedAt: 1_000_000, programId: "SOMETHING_NEW")
        addSession(sourceContext, startedAt: 2_000_000)
        XCTAssertEqual(try transfer(from: source, to: target), 1)
    }

    func testAFileThatIsNotABackupIsRejected() {
        for text in ["not json", #"{"sessions": []}"#,
                     #"{"format": "c2k-backup", "version": 1, "sessions": [{"programId": "C25K"}]}"#] {
            XCTAssertThrowsError(try Backup.decode(Data(text.utf8))) {
                XCTAssertEqual($0 as? Backup.ReadError, .notABackup, text)
            }
        }
    }

    func testABackupFromANewerVersionIsRejected() {
        XCTAssertThrowsError(try Backup.decode(Data(#"{"format": "c2k-backup", "version": 2, "sessions": []}"#.utf8))) {
            XCTAssertEqual($0 as? Backup.ReadError, .newerVersion)
        }
    }

    func testABackupWrittenByTheAndroidAppIsRead() throws {
        // The Android app's output for one workout: explicit nulls, route points in order.
        let text = """
        {
          "format": "c2k-backup",
          "version": 1,
          "exportedAt": 1763600000000,
          "sessions": [
            {
              "programId": "C210K", "week": 1, "day": 2, "startedAt": 1763500000000,
              "completedAt": null, "durationSeconds": 1800, "distanceMeters": 4000.25, "completed": false,
              "route": [{"latitude": 51.5, "longitude": -0.12, "altitudeMeters": null, "speedMps": 3.1, "recordedAt": 1763500005000}]
            }
          ]
        }
        """
        let backup = try Backup.decode(Data(text.utf8))
        XCTAssertEqual(backup.sessions.count, 1)
        XCTAssertEqual(backup.sessions[0].programId, "C210K")
        XCTAssertNil(backup.sessions[0].completedAt)
        XCTAssertEqual(backup.sessions[0].route[0].speedMps, 3.1)
    }

    func testTheFileNameCarriesTheDate() {
        var components = DateComponents()
        components.year = 2026; components.month = 11; components.day = 5
        let date = Calendar.current.date(from: components)!
        XCTAssertEqual(Backup.fileName(on: date), "c2k-backup-2026-11-05.json")
    }
}

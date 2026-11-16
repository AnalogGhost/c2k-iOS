import XCTest
import SwiftData
@testable import CtoK

@MainActor
final class GpxExportTests: XCTestCase {

    private var container: ModelContainer!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: WorkoutSession.self, RoutePoint.self, configurations: config)
    }

    private func session(week: Int = 3, day: Int = 2, startedAt: Date) -> WorkoutSession {
        let s = WorkoutSession(programId: "C25K", week: week, day: day)
        s.startedAt = startedAt
        container.mainContext.insert(s)
        return s
    }

    private func point(_ s: WorkoutSession, lat: Double, lon: Double, alt: Double? = nil) -> RoutePoint {
        RoutePoint(sessionId: s.id, update: LocationUpdate(
            latitude: lat, longitude: lon, altitudeMeters: alt, speedMps: nil,
            timestamp: Date(timeIntervalSince1970: 1_794_825_000)
        ))
    }

    func testFileNameHasWeekDayAndLocalStartTime() {
        // 2026-11-16T10:30:00Z
        let s = session(startedAt: Date(timeIntervalSince1970: 1_794_825_000))
        let name = GpxExport.fileName(session: s, timeZone: TimeZone(identifier: "America/Sao_Paulo")!)
        XCTAssertEqual(name, "c2k-route-w3d2-2026-11-16-0730.gpx")
    }

    func testCoordinatesNearZeroAreWrittenWithoutAnExponent() {
        let s = session(startedAt: .now)
        let gpx = GpxExport.gpx(session: s, points: [point(s, lat: 0.00001, lon: -0.00002, alt: 12.34)])
        XCTAssertTrue(gpx.contains("<trkpt lat=\"0.0000100\" lon=\"-0.0000200\">"), gpx)
        XCTAssertTrue(gpx.contains("<ele>12.3</ele>"), gpx)
        XCTAssertFalse(gpx.contains("e-"), gpx)
    }

    func testWriteFileProducesAGpxFileAndReplacesThePreviousExport() throws {
        let first = session(day: 1, startedAt: .now)
        let second = session(day: 2, startedAt: .now)
        let firstURL = try GpxExport.writeFile(session: first, points: [point(first, lat: 37.97, lon: 23.74)])
        let secondURL = try GpxExport.writeFile(session: second, points: [point(second, lat: 37.97, lon: 23.74)])

        XCTAssertEqual(secondURL.pathExtension, "gpx")
        XCTAssertFalse(FileManager.default.fileExists(atPath: firstURL.path))
        let contents = try String(contentsOf: secondURL, encoding: .utf8)
        XCTAssertTrue(contents.hasPrefix("<?xml"))
        XCTAssertTrue(contents.contains("<name>C2K W3D2</name>"))
        XCTAssertTrue(contents.hasSuffix("</gpx>"))
    }
}

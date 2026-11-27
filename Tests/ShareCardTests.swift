import XCTest
import SwiftUI
@testable import CtoK

@MainActor
final class ShareCardTests: XCTestCase {

    private func stats(duration: Int, distance: Double) -> ShareCardStats {
        ShareCardStats(programName: "Couch to 5K", week: 3, day: 2, finishedProgram: false,
                       durationSeconds: duration, distanceMeters: distance, date: .now)
    }

    // MARK: - Pace

    func testPaceIsTheWholeWorkoutAveragePerKilometre() {
        XCTAssertEqual(stats(duration: 30 * 60, distance: 4000).paceSecondsPerKm, 450)   // 7:30 / km
    }

    func testNoPaceWithoutAUsableDistance() {
        XCTAssertNil(stats(duration: 30 * 60, distance: 0).paceSecondsPerKm, "treadmill run")
        XCTAssertNil(stats(duration: 30 * 60, distance: 50).paceSecondsPerKm, "GPS noise, not a run")
        XCTAssertNil(stats(duration: 0, distance: 3000).paceSecondsPerKm)
    }

    // MARK: - From a saved session

    func testASessionOnTheProgramsLastDayIsAFinishedProgram() {
        let session = WorkoutSession(programId: Programs.idC25K, week: 9, day: 3)
        session.completed = true
        session.durationSeconds = 1800
        session.distanceMeters = 4200
        let stats = ShareCardStats.of(session: session)
        XCTAssertTrue(stats.finishedProgram)
        XCTAssertEqual(stats.programName, Programs.byId(Programs.idC25K).localizedName)
        XCTAssertEqual(stats.durationSeconds, 1800)
        XCTAssertEqual(stats.distanceMeters, 4200)
        XCTAssertEqual(stats.date, session.startedAt)
    }

    func testAStoppedLastDayOrAnOrdinaryDayIsNot() {
        let stopped = WorkoutSession(programId: Programs.idC25K, week: 9, day: 3)
        stopped.completed = false
        XCTAssertFalse(ShareCardStats.of(session: stopped).finishedProgram)

        let ordinary = WorkoutSession(programId: Programs.idC25K, week: 4, day: 1)
        ordinary.completed = true
        XCTAssertFalse(ShareCardStats.of(session: ordinary).finishedProgram)
    }

    // MARK: - Route outline

    func testTooFewPointsGiveNoOutline() {
        XCTAssertEqual(RouteOutline.normalized(latitudes: [], longitudes: []), [])
        XCTAssertEqual(RouteOutline.normalized(latitudes: [51.5], longitudes: [-0.1]), [])
    }

    func testStandingStillGivesNoOutline() {
        XCTAssertEqual(RouteOutline.normalized(latitudes: [51.5, 51.5, 51.5], longitudes: [-0.1, -0.1, -0.1]), [])
    }

    func testTheOutlineFillsTheUnitSquareWithNorthUp() {
        // Due north, then due east by the same distance on the ground.
        let lat = 51.5, step = 0.01
        // East-west distance shrinks with latitude; the outline scales by the route's mean latitude.
        let meanLat = (lat + 2 * (lat + step)) / 3
        let east = step / cos(meanLat * .pi / 180)
        let points = RouteOutline.normalized(latitudes: [lat, lat + step, lat + step],
                                             longitudes: [0, 0, east])
        XCTAssertEqual(points.count, 3)
        XCTAssertEqual(points[0].x, 0, accuracy: 1e-6); XCTAssertEqual(points[0].y, 1, accuracy: 1e-6)
        XCTAssertEqual(points[1].x, 0, accuracy: 1e-6); XCTAssertEqual(points[1].y, 0, accuracy: 1e-6)
        XCTAssertEqual(points[2].x, 1, accuracy: 1e-6); XCTAssertEqual(points[2].y, 0, accuracy: 1e-6)
    }

    func testAStraightRunIsCentredNotStretched() {
        // Due north only: the line keeps its shape, down the middle of the square.
        let points = RouteOutline.normalized(latitudes: [50, 50.01], longitudes: [1, 1])
        XCTAssertEqual(points.map(\.x), [0.5, 0.5])
        XCTAssertEqual(points[0].y, 1, accuracy: 1e-6)
        XCTAssertEqual(points[1].y, 0, accuracy: 1e-6)
    }

    func testLongRoutesAreThinnedButKeepTheirEnds() {
        let lats = (0..<5000).map { 50 + Double($0) * 1e-5 }
        let lons = (0..<5000).map { 1 + sin(Double($0) / 300) * 1e-3 }
        let points = RouteOutline.normalized(latitudes: lats, longitudes: lons, maxPoints: 400)
        XCTAssertEqual(points.count, 400)
        let full = RouteOutline.normalized(latitudes: lats, longitudes: lons, maxPoints: 10_000)
        // The thinned route's box can differ in the last decimals; its ends are the same places.
        XCTAssertEqual(points.first!.x, full.first!.x, accuracy: 1e-3)
        XCTAssertEqual(points.first!.y, full.first!.y, accuracy: 1e-3)
        XCTAssertEqual(points.last!.x, full.last!.x, accuracy: 1e-3)
        XCTAssertEqual(points.last!.y, full.last!.y, accuracy: 1e-3)
        XCTAssertTrue(points.allSatisfy { (0...1).contains($0.x) && (0...1).contains($0.y) })
    }

    // MARK: - Backgrounds

    func testEveryBundledPhotoIsInTheApp() {
        for n in 1...ShareBackground.photoCount {
            let name = ShareBackground.photo(n).assetName!
            XCTAssertNotNil(UIImage(named: name, in: Bundle(for: WorkoutManager.self), with: nil), name)
        }
        XCTAssertEqual(ShareBackground.builtIn.count, ShareBackground.photoCount + ShareBackground.gradientCount)
    }

    func testTheCardRendersAtStorySize() {
        let canvas = ShareCardCanvas(stats: stats(duration: 1800, distance: 4000),
                                     route: [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1)],
                                     background: .photo(1), customPhoto: nil)
        let renderer = ImageRenderer(content: canvas)
        renderer.scale = 3
        let image = renderer.uiImage
        XCTAssertEqual(image?.size.width, 360)
        XCTAssertEqual(image.map { $0.size.width * $0.scale }, 1080)
        XCTAssertEqual(image.map { $0.size.height * $0.scale }, 1920)
    }
}

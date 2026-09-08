import XCTest
@testable import CtoK

final class DistanceCalculatorTests: XCTestCase {

    // ~0.0001° latitude ≈ 11.1 m; at 5 s intervals that's ~2.2 m/s, a normal running pace.
    private func point(_ lat: Double, lon: Double = 0.0, atSeconds: Double) -> RoutePoint {
        RoutePoint(sessionId: UUID(), update: LocationUpdate(
            latitude: lat, longitude: lon, altitudeMeters: nil, speedMps: nil,
            timestamp: Date(timeIntervalSince1970: atSeconds)
        ))
    }

    func testEmptyAndSinglePointRoutesHaveZeroDistance() {
        XCTAssertEqual(DistanceCalculator.filteredDistanceMeters(points: []), 0, accuracy: 0.001)
        XCTAssertEqual(
            DistanceCalculator.filteredDistanceMeters(points: [point(50.0, atSeconds: 0)]),
            0, accuracy: 0.001
        )
    }

    func testPlausibleRouteSumsAllSegments() {
        let points = (0..<5).map { i in point(50.0 + Double(i) * 0.0001, atSeconds: Double(i) * 5) }
        let distance = DistanceCalculator.filteredDistanceMeters(points: points)
        // 4 segments of ~11.1 m each
        XCTAssertEqual(distance, 44.5, accuracy: 1)
    }

    func testTeleportingSpikeContributesNothing() {
        // Same route, but one point jumps ~111 km away and back — the pattern from issue
        // #30, where a faulty GPS lock added 584 km. Both segments touching the spike imply
        // impossible speed and must be discarded; the rest of the route still counts.
        let points = [
            point(50.0000, atSeconds: 0),
            point(50.0001, atSeconds: 5),
            point(51.0000, atSeconds: 10), // spike: ~111 km in 5 s
            point(50.0002, atSeconds: 15),
            point(50.0003, atSeconds: 20),
        ]
        let distance = DistanceCalculator.filteredDistanceMeters(points: points)
        // Only the two clean segments (0→1 and 3→4), ~11.1 m each
        XCTAssertEqual(distance, 22.2, accuracy: 1)
    }

    func testSustainedWrongTrackCountsOnlyTheJumpsOutAndBack() {
        // GPS settles somewhere wrong, records a few self-consistent points there, then
        // recovers. The huge jump segments are dropped; the small movements at the wrong
        // location are indistinguishable from real running and legitimately kept.
        let points = [
            point(50.0000, atSeconds: 0),
            point(51.0000, atSeconds: 5),  // jump out: dropped
            point(51.0001, atSeconds: 10), // ~11 m while "wrong": kept
            point(50.0001, atSeconds: 15), // jump back: dropped
        ]
        let distance = DistanceCalculator.filteredDistanceMeters(points: points)
        XCTAssertEqual(distance, 11.1, accuracy: 1)
    }

    func testNonPositiveTimeDeltaSegmentsAreSkipped() {
        let points = [
            point(50.0000, atSeconds: 10),
            point(50.0001, atSeconds: 10), // dt = 0: speed undefined, skip
            point(50.0002, atSeconds: 15),
        ]
        let distance = DistanceCalculator.filteredDistanceMeters(points: points)
        XCTAssertEqual(distance, 11.1, accuracy: 1)
    }

    func testHaversineMatchesKnownDistance() {
        // One degree of latitude along a meridian: Earth's mean circumference / 360 ≈ 111.19 km
        let meters = DistanceCalculator.haversineMeters(lat1: 0, lon1: 0, lat2: 1, lon2: 0)
        XCTAssertEqual(meters, 111_195.0, accuracy: 10.0)
    }
}

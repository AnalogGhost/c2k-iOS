import Foundation

enum DistanceCalculator {

    // Fastest implied speed accepted between two consecutive GPS fixes. A faulty fix can
    // "teleport" hundreds of kilometres in one segment (issue #30: 584 km in 8 minutes),
    // so anything above a pace no human sustains on foot (~45 km/h) is treated as bad data
    // rather than movement. Matches Android's DistanceCalculator.MAX_SPEED_MPS.
    static let maxSpeedMps = 12.5

    private static let earthRadiusMeters = 6_371_000.0

    static func haversineMeters(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) +
            cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) *
            sin(dLon / 2) * sin(dLon / 2)
        return earthRadiusMeters * 2 * atan2(sqrt(a), sqrt(1 - a))
    }

    /// Total distance along a recorded route, skipping segments whose implied speed exceeds
    /// `maxSpeedMps` (as well as segments with a non-positive time delta, which make speed
    /// meaningless). Both segments around an isolated spike point exceed the limit, so the
    /// spike contributes nothing and the total resumes from the next plausible segment.
    static func filteredDistanceMeters(points: [RoutePoint]) -> Double {
        guard points.count >= 2 else { return 0 }
        var total = 0.0
        for i in 1..<points.count {
            let prev = points[i - 1]
            let next = points[i]
            let dtSeconds = next.timestamp.timeIntervalSince(prev.timestamp)
            guard dtSeconds > 0 else { continue }
            let meters = haversineMeters(
                lat1: prev.latitude, lon1: prev.longitude,
                lat2: next.latitude, lon2: next.longitude
            )
            guard meters / dtSeconds <= maxSpeedMps else { continue }
            total += meters
        }
        return total
    }
}

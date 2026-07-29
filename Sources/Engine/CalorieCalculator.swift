import Foundation

// Estimates calories burned from distance, duration, and body weight using a MET
// (Metabolic Equivalent of Task) model. MET values are approximate, taken from the public
// Compendium of Physical Activities, and looked up against the session's average speed —
// this is a reasonable estimate, not a precise measurement.
//
// calories = MET * weightKg * durationHours
enum CalorieCalculator {

    // Upper-bound average speed (km/h) -> MET value for that band. Bands run from a slow
    // walk up through fast running; the last entry is an open-ended upper bound.
    private static let metBands: [(upperKmh: Double, met: Double)] = [
        (3.2, 2.8),             // slow walk, ~2 mph
        (4.8, 3.3),             // walk, ~3 mph
        (5.6, 3.8),             // walk, ~3.5 mph
        (6.4, 5.0),             // very brisk walk, ~4 mph
        (8.0, 7.0),             // jogging, general
        (9.7, 8.3),             // running, ~5 mph
        (11.3, 9.8),            // running, ~6 mph
        (12.9, 11.0),           // running, ~7 mph
        (.greatestFiniteMagnitude, 11.8), // running, ~8 mph+
    ]

    private static func met(forSpeedKmh speedKmh: Double) -> Double {
        metBands.first(where: { speedKmh <= $0.upperKmh })!.met
    }

    // Returns the estimated calories burned, or nil if there's nothing to estimate
    // (no distance/duration recorded, or no weight set) rather than guessing.
    static func estimateCalories(distanceMeters: Double, durationSeconds: Int, weightKg: Double) -> Int? {
        guard distanceMeters > 0, durationSeconds > 0, weightKg > 0 else { return nil }
        let speedKmh = (distanceMeters / 1000) / (Double(durationSeconds) / 3600)
        let hours = Double(durationSeconds) / 3600
        return Int((met(forSpeedKmh: speedKmh) * weightKg * hours).rounded())
    }
}

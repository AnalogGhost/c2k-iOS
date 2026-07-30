import XCTest
@testable import CtoK

final class CalorieCalculatorTests: XCTestCase {

    func testReturnsNilWhenDistanceIsZero() {
        XCTAssertNil(CalorieCalculator.estimateCalories(distanceMeters: 0, durationSeconds: 600, weightKg: 70))
    }

    func testReturnsNilWhenDurationIsZero() {
        XCTAssertNil(CalorieCalculator.estimateCalories(distanceMeters: 1000, durationSeconds: 0, weightKg: 70))
    }

    func testReturnsNilWhenWeightIsZero() {
        // Callers pass weightKg as a non-optional Double, so "no weight set" is represented
        // by the caller not invoking this at all (see WorkoutStats.totalCalories); this test
        // documents the zero-weight guard instead.
        XCTAssertNil(CalorieCalculator.estimateCalories(distanceMeters: 1000, durationSeconds: 600, weightKg: 0))
    }

    func testReturnsNilForNegativeWeight() {
        XCTAssertNil(CalorieCalculator.estimateCalories(distanceMeters: 1000, durationSeconds: 600, weightKg: -5))
    }

    func testSlowWalkUsesLowMetBand() {
        // 2 km in 60 min = 2 km/h, well within the slowest walk band.
        let calories = CalorieCalculator.estimateCalories(distanceMeters: 2000, durationSeconds: 3600, weightKg: 70)
        XCTAssertNotNil(calories)
        // MET 2.8 * 70kg * 1h ≈ 196
        XCTAssertEqual(calories, 196)
    }

    func testFastRunningUsesHighMetBand() {
        // 15 km in 60 min = 15 km/h, in the fastest open-ended band (MET 11.8).
        let calories = CalorieCalculator.estimateCalories(distanceMeters: 15000, durationSeconds: 3600, weightKg: 70)
        XCTAssertNotNil(calories)
        // MET 11.8 * 70kg * 1h = 826
        XCTAssertEqual(calories, 826)
    }

    func testCaloriesScaleWithWeight() {
        let lighter = CalorieCalculator.estimateCalories(distanceMeters: 5000, durationSeconds: 1800, weightKg: 50)!
        let heavier = CalorieCalculator.estimateCalories(distanceMeters: 5000, durationSeconds: 1800, weightKg: 100)!
        XCTAssertEqual(Double(heavier), Double(lighter) * 2, accuracy: 1.0)
    }

    func testBandBoundaryIsInclusiveOfUpperEdge() {
        // Exactly 3.2 km/h is the upper edge of the slowest band per the MET table.
        let atBoundary = CalorieCalculator.estimateCalories(distanceMeters: 3200, durationSeconds: 3600, weightKg: 70)!
        let justAbove = CalorieCalculator.estimateCalories(distanceMeters: 3201, durationSeconds: 3600, weightKg: 70)!
        XCTAssertLessThan(atBoundary, justAbove)
    }
}

import XCTest
@testable import CtoK

final class VibrationStrengthTests: XCTestCase {
    func testRawValueRoundTrip() {
        for strength in VibrationStrength.allCases {
            XCTAssertEqual(VibrationStrength(rawValue: strength.rawValue), strength)
        }
    }

    func testUnknownRawValueFallsBackToMediumViaPreferences() {
        // UserPreferences does the `?? .medium` fallback; the enum itself returns nil.
        XCTAssertNil(VibrationStrength(rawValue: "extreme"))
    }

    func testIntensityStrictlyIncreases() {
        XCTAssertLessThan(VibrationStrength.light.intensity, VibrationStrength.medium.intensity)
        XCTAssertLessThan(VibrationStrength.medium.intensity, VibrationStrength.strong.intensity)
    }

    func testSharpnessStrictlyIncreases() {
        XCTAssertLessThan(VibrationStrength.light.sharpness, VibrationStrength.medium.sharpness)
        XCTAssertLessThan(VibrationStrength.medium.sharpness, VibrationStrength.strong.sharpness)
    }

    func testFallbackStyleMapping() {
        XCTAssertEqual(VibrationStrength.light.fallbackStyle, .light)
        XCTAssertEqual(VibrationStrength.medium.fallbackStyle, .medium)
        XCTAssertEqual(VibrationStrength.strong.fallbackStyle, .heavy)
    }
}

@MainActor
final class HapticsPlayerTests: XCTestCase {
    func testBeatTablesMirrorAndroidWaveforms() {
        XCTAssertEqual(HapticsPlayer.beats(for: .intervalChange), [0])
        XCTAssertEqual(HapticsPlayer.beats(for: .runIntervalChange), [0, 0.16])
        XCTAssertEqual(HapticsPlayer.beats(for: .workoutComplete), [0, 0.18, 0.36])
    }

    func testPlayNeverThrowsWithoutHapticHardware() {
        // On the simulator supportsHaptics == false; play must silently fall back.
        let player = HapticsPlayer()
        player.configure(strength: .strong)
        player.start()
        player.play(.intervalChange)
        player.play(.runIntervalChange)
        player.play(.workoutComplete)
        player.stop()
    }
}

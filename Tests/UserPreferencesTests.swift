import XCTest
@testable import CtoK

// UserPreferences reads and writes UserDefaults.standard directly, so these tests save the
// keys they touch and put them back afterwards.
final class UserPreferencesTests: XCTestCase {
    private let keys = ["periodic_time_cues", "periodic_time_cue_interval", "skip_warmup_cooldown", "skip_warmup", "skip_cooldown", "countdown_warning_2_enabled", "cue_style"]
    private var saved: [String: Any] = [:]

    override func setUp() {
        super.setUp()
        let defaults = UserDefaults.standard
        for key in keys {
            saved[key] = defaults.object(forKey: key)
            defaults.removeObject(forKey: key)
        }
    }

    override func tearDown() {
        let defaults = UserDefaults.standard
        for key in keys {
            if let value = saved[key] { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
        }
        saved.removeAll()
        super.tearDown()
    }

    // Defaults match Android's UserPreferences: both features are opt-in, 30 s cadence.
    func testNewPreferencesDefaultToOffWithAThirtySecondCadence() {
        let prefs = UserPreferences()
        XCTAssertFalse(prefs.periodicTimeCues)
        XCTAssertEqual(prefs.periodicTimeCueInterval, 30)
        XCTAssertFalse(prefs.skipWarmup)
        XCTAssertFalse(prefs.skipCooldown)
    }

    // Defaults to on, so updating doesn't change anyone's warnings.
    func testSecondCountdownWarningDefaultsToOnAndPersistsUnderTheAndroidKey() {
        XCTAssertTrue(UserPreferences().countdownWarning2Enabled)
        UserPreferences().countdownWarning2Enabled = false
        XCTAssertEqual(UserDefaults.standard.object(forKey: "countdown_warning_2_enabled") as? Bool, false)
        XCTAssertFalse(UserPreferences().countdownWarning2Enabled)
    }

    func testCueStyleDefaultsToVoiceAndPersistsTheAndroidValue() {
        XCTAssertEqual(UserPreferences().cueStyle, .voice)
        UserPreferences().cueStyle = .tones
        XCTAssertEqual(UserDefaults.standard.string(forKey: "cue_style"), "TONES")
        XCTAssertEqual(UserPreferences().cueStyle, .tones)
    }

    func testAnUnknownStoredCueStyleFallsBackToVoice() {
        UserDefaults.standard.set("CHIMES", forKey: "cue_style")
        XCTAssertEqual(UserPreferences().cueStyle, .voice)
    }

    func testReadingDefaultsDoesNotWriteThem() {
        _ = UserPreferences()
        for key in keys {
            XCTAssertNil(UserDefaults.standard.object(forKey: key), key)
        }
    }

    func testPeriodicTimeCuesPersistUnderTheAndroidKey() {
        UserPreferences().periodicTimeCues = true
        XCTAssertEqual(UserDefaults.standard.object(forKey: "periodic_time_cues") as? Bool, true)
        XCTAssertTrue(UserPreferences().periodicTimeCues)
    }

    func testPeriodicTimeCueIntervalPersistsUnderTheAndroidKey() {
        UserPreferences().periodicTimeCueInterval = 75
        XCTAssertEqual(UserDefaults.standard.object(forKey: "periodic_time_cue_interval") as? Int, 75)
        XCTAssertEqual(UserPreferences().periodicTimeCueInterval, 75)
    }

    func testSkipWarmupAndCooldownPersistUnderTheAndroidKeys() {
        UserPreferences().skipWarmup = true
        XCTAssertEqual(UserDefaults.standard.object(forKey: "skip_warmup") as? Bool, true)
        XCTAssertTrue(UserPreferences().skipWarmup)
        XCTAssertFalse(UserPreferences().skipCooldown)

        UserPreferences().skipCooldown = true
        XCTAssertEqual(UserDefaults.standard.object(forKey: "skip_cooldown") as? Bool, true)
        XCTAssertTrue(UserPreferences().skipCooldown)
    }

    // 1.2.20 stored a single switch; whoever had it on keeps skipping both after updating.
    func testTheOldCombinedSwitchSeedsBothNewOnes() {
        UserDefaults.standard.set(true, forKey: "skip_warmup_cooldown")
        let prefs = UserPreferences()
        XCTAssertTrue(prefs.skipWarmup)
        XCTAssertTrue(prefs.skipCooldown)
    }

    func testChangingOneNewSwitchOverridesTheOldCombinedOne() {
        UserDefaults.standard.set(true, forKey: "skip_warmup_cooldown")
        UserPreferences().skipCooldown = false
        let prefs = UserPreferences()
        XCTAssertTrue(prefs.skipWarmup)
        XCTAssertFalse(prefs.skipCooldown)
    }

    func testTurningAPreferenceBackOffIsPersisted() {
        let prefs = UserPreferences()
        prefs.skipWarmup = true
        prefs.periodicTimeCues = true
        prefs.skipWarmup = false
        prefs.periodicTimeCues = false
        let reloaded = UserPreferences()
        XCTAssertFalse(reloaded.skipWarmup)
        XCTAssertFalse(reloaded.periodicTimeCues)
    }
}

import XCTest
@testable import CtoK

// UserPreferences reads and writes UserDefaults.standard directly, so these tests save the
// keys they touch and put them back afterwards.
final class UserPreferencesTests: XCTestCase {
    private let keys = ["periodic_time_cues", "periodic_time_cue_interval", "skip_warmup_cooldown"]
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
        XCTAssertFalse(prefs.skipWarmupCooldown)
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

    func testSkipWarmupCooldownPersistsUnderTheAndroidKey() {
        UserPreferences().skipWarmupCooldown = true
        XCTAssertEqual(UserDefaults.standard.object(forKey: "skip_warmup_cooldown") as? Bool, true)
        XCTAssertTrue(UserPreferences().skipWarmupCooldown)
    }

    func testTurningAPreferenceBackOffIsPersisted() {
        let prefs = UserPreferences()
        prefs.skipWarmupCooldown = true
        prefs.periodicTimeCues = true
        prefs.skipWarmupCooldown = false
        prefs.periodicTimeCues = false
        let reloaded = UserPreferences()
        XCTAssertFalse(reloaded.skipWarmupCooldown)
        XCTAssertFalse(reloaded.periodicTimeCues)
    }
}

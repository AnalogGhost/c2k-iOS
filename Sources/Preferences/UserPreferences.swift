import Foundation
import Observation

@Observable
final class UserPreferences {
    private let defaults = UserDefaults.standard

    var ttsEnabled: Bool = (UserDefaults.standard.object(forKey: "tts_enabled") as? Bool) ?? true {
        didSet { defaults.set(ttsEnabled, forKey: "tts_enabled") }
    }

    var gpsEnabled: Bool = (UserDefaults.standard.object(forKey: "gps_enabled") as? Bool) ?? true {
        didSet { defaults.set(gpsEnabled, forKey: "gps_enabled") }
    }

    var countdownWarnings: Bool = (UserDefaults.standard.object(forKey: "countdown_warnings") as? Bool) ?? true {
        didSet { defaults.set(countdownWarnings, forKey: "countdown_warnings") }
    }

    var keepScreenOn: Bool = (UserDefaults.standard.object(forKey: "keep_screen_on") as? Bool) ?? true {
        didSet { defaults.set(keepScreenOn, forKey: "keep_screen_on") }
    }

    var vibrationEnabled: Bool = (UserDefaults.standard.object(forKey: "vibration_enabled") as? Bool) ?? false {
        didSet { defaults.set(vibrationEnabled, forKey: "vibration_enabled") }
    }

    var ttsSpeechRate: Float = {
        let v = UserDefaults.standard.float(forKey: "tts_speech_rate")
        return v == 0 ? 1.0 : v
    }() {
        didSet { defaults.set(ttsSpeechRate, forKey: "tts_speech_rate") }
    }

    var lastProgramId: String? = UserDefaults.standard.string(forKey: "last_program_id") {
        didSet { defaults.set(lastProgramId, forKey: "last_program_id") }
    }

    var ttsVolume: Float = {
        (UserDefaults.standard.object(forKey: "tts_volume") as? Float) ?? 1.0
    }() {
        didSet { defaults.set(ttsVolume, forKey: "tts_volume") }
    }

    var countdownWarning1: Int = {
        let v = UserDefaults.standard.object(forKey: "countdown_warning_1") as? Int
        return v ?? 10
    }() {
        didSet { defaults.set(countdownWarning1, forKey: "countdown_warning_1") }
    }

    var countdownWarning2: Int = {
        let v = UserDefaults.standard.object(forKey: "countdown_warning_2") as? Int
        return v ?? 5
    }() {
        didSet { defaults.set(countdownWarning2, forKey: "countdown_warning_2") }
    }

    var midIntervalCues: Bool = (UserDefaults.standard.object(forKey: "mid_interval_cues") as? Bool) ?? true {
        didSet { defaults.set(midIntervalCues, forKey: "mid_interval_cues") }
    }

    var treadmillMode: Bool = (UserDefaults.standard.object(forKey: "treadmill_mode") as? Bool) ?? false {
        didSet { defaults.set(treadmillMode, forKey: "treadmill_mode") }
    }

    var weightKg: Double? = UserDefaults.standard.object(forKey: "weight_kg") as? Double {
        didSet { defaults.set(weightKg, forKey: "weight_kg") }
    }

    var weightUnit: WeightUnit = {
        let raw = UserDefaults.standard.string(forKey: "weight_unit") ?? WeightUnit.kg.rawValue
        return WeightUnit(rawValue: raw) ?? .kg
    }() {
        didSet { defaults.set(weightUnit.rawValue, forKey: "weight_unit") }
    }
}

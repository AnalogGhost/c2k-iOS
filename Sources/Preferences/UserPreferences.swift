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
}

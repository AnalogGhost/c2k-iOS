import Foundation

// Reads/writes the in-app language override.
//
// The user's *choice* is stored in `choiceKey` so `.system` is distinguishable from an
// explicit pick that happens to match the device language. `overrideKey` (AppleLanguages)
// is what iOS actually reads at launch, so it's written alongside — a change needs an app
// restart to take effect (matches the Android app recreating its process).
enum LanguageController {
    static let overrideKey = "AppleLanguages"
    static let choiceKey = "c2k_app_language"

    static func current(from defaults: UserDefaults = .standard) -> AppLanguage {
        guard let raw = defaults.string(forKey: choiceKey),
              let language = AppLanguage(rawValue: raw) else {
            return .system
        }
        return language
    }

    static func apply(_ language: AppLanguage, to defaults: UserDefaults = .standard) {
        if let code = language.bcp47 {
            defaults.set(code, forKey: choiceKey)
            defaults.set([code], forKey: overrideKey)
        } else {
            defaults.removeObject(forKey: choiceKey)
            defaults.removeObject(forKey: overrideKey)
        }
    }

    /// The localization the app is actually running in right now (only changes on relaunch).
    static var activeBundleLanguage: String {
        Bundle.main.preferredLocalizations.first ?? "en"
    }
}

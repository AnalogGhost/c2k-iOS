import Foundation

// The in-app language options. `.system` follows the device language; the rest force
// a specific bundle localization via the AppleLanguages override (see LanguageController).
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case en
    case de
    case es
    case fr
    case gl
    case ptBR = "pt-BR"
    case ru
    case tr

    var id: String { rawValue }

    /// BCP-47 code to write into AppleLanguages, or nil to follow the system.
    var bcp47: String? { self == .system ? nil : rawValue }

    /// Language name in its own language (endonym) — never localized.
    var displayName: String {
        switch self {
        case .system: return String(localized: "settings_language_system")
        case .en:     return "English"
        case .de:     return "Deutsch"
        case .es:     return "Español"
        case .fr:     return "Français"
        case .gl:     return "Galego"
        case .ptBR:   return "Português (Brasil)"
        case .ru:     return "Русский"
        case .tr:     return "Türkçe"
        }
    }
}

import Foundation

/// How workout cues sound: spoken announcements, or chimes in their place (Tones mode). Stored
/// under the same "cue_style" values as Android's CueStyle enum.
enum CueStyle: String, CaseIterable, Identifiable {
    case voice = "VOICE"
    case tones = "TONES"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .voice: return String(localized: "settings_cue_style_voice")
        case .tones: return String(localized: "settings_cue_style_tones")
        }
    }

    static func fromStored(_ value: String?) -> CueStyle {
        value.flatMap(CueStyle.init(rawValue:)) ?? .voice
    }
}

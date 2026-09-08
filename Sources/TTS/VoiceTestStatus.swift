import Foundation

enum VoiceTestStatus: Equatable {
    case idle
    case initializing
    case playing
    case finished
    case voiceUnavailable
    case audioOutputFailure
    case synthesisFailure

    var isFailure: Bool {
        switch self {
        case .voiceUnavailable, .audioOutputFailure, .synthesisFailure: return true
        default: return false
        }
    }

    var localizedText: String? {
        switch self {
        case .idle:               return nil
        case .initializing:       return String(localized: "settings_tts_status_initializing")
        case .playing:            return String(localized: "settings_tts_status_playing")
        case .finished:           return String(localized: "settings_tts_status_finished")
        case .voiceUnavailable:   return String(localized: "settings_tts_status_voice_unavailable")
        case .audioOutputFailure: return String(localized: "settings_tts_status_audio_failure")
        case .synthesisFailure:   return String(localized: "settings_tts_status_synth_failure")
        }
    }
}

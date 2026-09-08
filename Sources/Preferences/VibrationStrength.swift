import UIKit

// Mirrors the Android app's LIGHT / MEDIUM / STRONG vibration-strength presets.
enum VibrationStrength: String, CaseIterable, Identifiable {
    case light, medium, strong

    var id: String { rawValue }

    var label: String {
        switch self {
        case .light:  return String(localized: "vibration_strength_light")
        case .medium: return String(localized: "vibration_strength_medium")
        case .strong: return String(localized: "vibration_strength_strong")
        }
    }

    // CoreHaptics event intensity (0…1) — roughly Android's amplitudes 96 / 166 / 255 ÷ 255.
    var intensity: Float {
        switch self {
        case .light:  return 0.4
        case .medium: return 0.65
        case .strong: return 1.0
        }
    }

    var sharpness: Float {
        switch self {
        case .light:  return 0.3
        case .medium: return 0.5
        case .strong: return 0.8
        }
    }

    // Used when CoreHaptics is unavailable (iPhone SE 1, iPad, simulator).
    var fallbackStyle: UIImpactFeedbackGenerator.FeedbackStyle {
        switch self {
        case .light:  return .light
        case .medium: return .medium
        case .strong: return .heavy
        }
    }
}

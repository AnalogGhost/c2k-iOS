import CoreHaptics
import UIKit

enum HapticCue {
    case intervalChange       // single pulse
    case runIntervalChange    // double pulse — entering a run interval
    case workoutComplete      // three pulses
}

// Test seam so WorkoutManager can be exercised with a spy.
protocol HapticCuePlaying: AnyObject {
    func configure(strength: VibrationStrength)
    func start()
    func stop()
    func play(_ cue: HapticCue)
}

// Interval-change and completion haptics. Uses CoreHaptics for structured,
// intensity-scaled patterns (parity with Android's VibrationEffect waveforms) and
// falls back to UIImpactFeedbackGenerator where no haptic engine is available.
@MainActor
final class HapticsPlayer: HapticCuePlaying {
    private var strength: VibrationStrength = .medium

    private let supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    private var engine: CHHapticEngine?

    nonisolated init() {}

    func configure(strength: VibrationStrength) { self.strength = strength }

    /// Relative pulse times (seconds) per cue — mirrors the Android pulse patterns.
    static func beats(for cue: HapticCue) -> [TimeInterval] {
        switch cue {
        case .intervalChange:    return [0]
        case .runIntervalChange: return [0, 0.16]
        case .workoutComplete:   return [0, 0.18, 0.36]
        }
    }

    func start() {
        guard supportsHaptics, engine == nil else { return }
        do {
            let e = try CHHapticEngine()
            e.isAutoShutdownEnabled = true
            e.resetHandler = { [weak e] in try? e?.start() }
            try e.start()
            engine = e
        } catch {
            engine = nil   // fall back to UIImpactFeedbackGenerator
        }
    }

    func stop() {
        engine?.stop()
        engine = nil
    }

    func play(_ cue: HapticCue) {
        if let engine, let pattern = try? pattern(for: cue) {
            do {
                try engine.start()
                let player = try engine.makePlayer(with: pattern)
                try player.start(atTime: 0)
                return
            } catch {
                // fall through to the generator
            }
        }
        fallback(cue)
    }

    private func pattern(for cue: HapticCue) throws -> CHHapticPattern {
        let events = Self.beats(for: cue).map { time in
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: strength.intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: strength.sharpness),
                ],
                relativeTime: time
            )
        }
        return try CHHapticPattern(events: events, parameters: [])
    }

    private func fallback(_ cue: HapticCue) {
        let generator = UIImpactFeedbackGenerator(style: strength.fallbackStyle)
        generator.prepare()
        let intensity = CGFloat(strength.intensity)
        for time in Self.beats(for: cue) {
            if time == 0 {
                generator.impactOccurred(intensity: intensity)
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + time) {
                    // Suppress a stray pulse if the workout ended between beats.
                    guard WorkoutManager.shared.isRunning || cue == .workoutComplete else { return }
                    generator.impactOccurred(intensity: intensity)
                }
            }
        }
    }
}

#if DEBUG
import Foundation
import SwiftData

/// Deterministic data for `fastlane snapshot`. Only ever runs when the app is
/// launched with `--screenshot-seed` against an in-memory store (see `CtoKApp`),
/// so it can never touch a real user's data.
enum ScreenshotSeed {

    /// Settings that make the walkthrough deterministic. Must be applied *before*
    /// `UserPreferences()` is constructed — that type snapshots `UserDefaults` once
    /// at init, and NSArgumentDomain string values don't coerce to `Bool`.
    static func applyDefaults() {
        let d = UserDefaults.standard
        d.set(true, forKey: "treadmill_mode")    // no GPS prompt, no "Acquiring GPS…"
        d.set(false, forKey: "gps_enabled")
        d.set(true, forKey: "countdown_warnings")
        d.set(70.0, forKey: "weight_kg")         // History shows a calorie total
        d.set("C25K", forKey: "last_program_id") // Home shows the "continue" shortcut
        // Simulator defaults outlive a launch, so put back every setting a walkthrough or UI test
        // may have changed: each launch starts from the same state.
        for key in ["cue_style", "countdown_warning_2_enabled", "skip_warmup", "skip_cooldown",
                    "skip_warmup_cooldown", "smartwatch_cues", "vibration_enabled",
                    "repeated_week", "progression_dismissed_at", "tts_enabled"] {
            d.removeObject(forKey: key)
        }
    }

    /// Three weeks of Couch to 5K history so the home streak, recent list, program
    /// grid, and history stats all fill in.
    static func seedHistory(context: ModelContext) {
        try? context.delete(model: RoutePoint.self)
        try? context.delete(model: WorkoutSession.self)

        let programId = Programs.idC25K
        let calendar = Calendar.current
        let now = Date()

        // (programWeek, day, minutes, kilometres)
        let sessions: [(week: Int, day: Int, minutes: Int, km: Double)] = [
            (1, 1, 21, 2.6), (1, 2, 22, 2.7), (1, 3, 20, 2.5),
            (2, 1, 24, 3.0), (2, 2, 25, 3.1), (2, 3, 26, 3.2),
            (3, 1, 28, 3.6), (3, 2, 30, 3.9),
        ]

        for (index, entry) in sessions.enumerated() {
            // Newest ~2 days ago, then one every 3 days going back.
            let daysAgo = 2 + (sessions.count - 1 - index) * 3
            let started = calendar.date(byAdding: .day, value: -daysAgo, to: now) ?? now

            let session = WorkoutSession(programId: programId, week: entry.week, day: entry.day)
            session.startedAt = started
            session.completedAt = started.addingTimeInterval(Double(entry.minutes) * 60)
            session.durationSeconds = entry.minutes * 60
            session.distanceMeters = entry.km * 1000
            session.completed = true
            context.insert(session)
        }

        // `--seed-early-stops`: two early stops on the next workout (week 3 day 3), so Home shows
        // the step-back suggestion (UI tests).
        if CommandLine.arguments.contains("--seed-early-stops") {
            for hoursAgo in [30.0, 6.0] {
                let stopped = WorkoutSession(programId: programId, week: 3, day: 3)
                stopped.startedAt = now.addingTimeInterval(-hoursAgo * 3600)
                stopped.durationSeconds = 10 * 60
                stopped.completed = false
                context.insert(stopped)
            }
        }

        do {
            try context.save()
        } catch {
            NSLog("ScreenshotSeed: save failed: \(error)")
        }
    }
}
#endif

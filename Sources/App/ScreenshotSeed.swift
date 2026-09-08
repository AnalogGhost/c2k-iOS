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

        do {
            try context.save()
        } catch {
            NSLog("ScreenshotSeed: save failed: \(error)")
        }
    }
}
#endif

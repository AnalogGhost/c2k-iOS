import Foundation

/// Totals for every finished workout in one program, shown when the runner completes it.
struct ProgramSummary: Equatable {
    var workouts: Int
    var durationSeconds: Int
    var distanceMeters: Double

    /// Adds the workout just finished, from its own figures, to the program's earlier finished
    /// workouts in `sessions`. The workout may not be saved as completed yet when the screen
    /// appears, so its saved row (`currentId`) is left out rather than trusted.
    static func of(sessions: [WorkoutSession], programId: String, currentId: UUID,
                   durationSeconds: Int, distanceMeters: Double) -> ProgramSummary {
        let earlier = sessions.filter { $0.programId == programId && $0.completed && $0.id != currentId }
        return ProgramSummary(
            workouts: earlier.count + 1,
            durationSeconds: earlier.reduce(durationSeconds) { $0 + $1.durationSeconds },
            distanceMeters: earlier.reduce(distanceMeters) { $0 + $1.distanceMeters }
        )
    }
}

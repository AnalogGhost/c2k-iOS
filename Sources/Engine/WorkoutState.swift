import Foundation

enum WorkoutState {
    case idle
    case active(ActiveSnapshot)
    case paused(snapshot: ActiveSnapshot)
    /// `skippedRun`: a run interval was never run to its end, so the workout doesn't count
    /// toward the runner's progress.
    case completed(sessionId: UUID, elapsedSessionSeconds: Int, skippedRun: Bool)

    struct ActiveSnapshot {
        let currentInterval: Interval
        let nextInterval: Interval?
        let intervalIndex: Int
        let totalIntervals: Int
        let remainingRunIntervals: Int
        let secondsRemainingInInterval: Int
        let elapsedSessionSeconds: Int
        let sessionId: UUID
    }
}

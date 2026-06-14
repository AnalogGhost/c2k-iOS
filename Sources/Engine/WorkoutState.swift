import Foundation

enum WorkoutState {
    case idle
    case active(ActiveSnapshot)
    case paused(snapshot: ActiveSnapshot)
    case completed(sessionId: UUID, elapsedSessionSeconds: Int)

    struct ActiveSnapshot {
        let currentInterval: Interval
        let nextInterval: Interval?
        let intervalIndex: Int
        let totalIntervals: Int
        let secondsRemainingInInterval: Int
        let elapsedSessionSeconds: Int
        let sessionId: UUID
    }
}

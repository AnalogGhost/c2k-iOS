import SwiftData
import Foundation

@Model
final class WorkoutSession {
    @Attribute(.unique) var id: UUID
    var programId: String
    var week: Int
    var day: Int
    var startedAt: Date
    /// When the workout ended, finished or stopped by the runner. Nil while it runs, and stays nil
    /// for a workout the app was closed during (by iOS, or a crash): that run is recovered on the
    /// next launch with the time and distance saved so far, but the runner didn't end it.
    var completedAt: Date?
    var durationSeconds: Int
    var distanceMeters: Double
    var completed: Bool

    init(programId: String, week: Int, day: Int) {
        self.id = UUID()
        self.programId = programId
        self.week = week
        self.day = day
        self.startedAt = .now
        self.durationSeconds = 0
        self.distanceMeters = 0
        self.completed = false
    }
}

import SwiftData
import Foundation

@Model
final class WorkoutSession {
    @Attribute(.unique) var id: UUID
    var programId: String
    var week: Int
    var day: Int
    var startedAt: Date
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

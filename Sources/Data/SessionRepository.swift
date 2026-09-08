import SwiftData
import Foundation

struct WeekDay: Hashable {
    let week: Int
    let day: Int
}

@MainActor
final class SessionRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    func startSession(programId: String, week: Int, day: Int) -> UUID {
        let session = WorkoutSession(programId: programId, week: week, day: day)
        context.insert(session)
        try? context.save()
        return session.id
    }

    func finishSession(id: UUID, durationSeconds: Int, distanceMeters: Double, completed: Bool) {
        guard let session = fetchSession(id: id) else { return }
        session.completedAt = .now
        session.durationSeconds = durationSeconds
        session.distanceMeters = distanceMeters
        session.completed = completed
        try? context.save()
    }

    func addRoutePoint(_ point: RoutePoint) {
        context.insert(point)
        try? context.save()
    }

    func deleteSession(id: UUID) {
        guard let session = fetchSession(id: id) else { return }
        let sessionId = session.id
        let routePoints = fetchRoutePoints(sessionId: sessionId)
        routePoints.forEach { context.delete($0) }
        context.delete(session)
        try? context.save()
    }

    func resetProgress(programId: String) {
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.programId == programId }
        )
        let sessions = (try? context.fetch(descriptor)) ?? []
        for session in sessions {
            let id = session.id
            fetchRoutePoints(sessionId: id).forEach { context.delete($0) }
            context.delete(session)
        }
        try? context.save()
    }

    func completedDays(programId: String) -> Set<WeekDay> {
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.programId == programId && $0.completed == true }
        )
        let sessions = (try? context.fetch(descriptor)) ?? []
        return Set(sessions.map { WeekDay(week: $0.week, day: $0.day) })
    }

    func bestSession(programId: String, week: Int, day: Int, excluding: UUID? = nil) -> WorkoutSession? {
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate {
                $0.programId == programId &&
                $0.week == week &&
                $0.day == day &&
                $0.completed == true
            }
        )
        let sessions = (try? context.fetch(descriptor)) ?? []
        return sessions
            .filter { $0.id != excluding }
            .min(by: { $0.durationSeconds < $1.durationSeconds })
    }

    func routePoints(sessionId: UUID) -> [RoutePoint] {
        fetchRoutePoints(sessionId: sessionId)
    }

    /// Re-derives every session's distance from its stored route points, applying the same
    /// implied-speed filter the live tracker now uses, so sessions recorded before that
    /// filter existed lose their teleporting-GPS kilometres (issue #30). Sessions without a
    /// route (treadmill mode, GPS off) are left untouched. Idempotent, so it's safe to re-run
    /// if interrupted.
    func recomputeSessionDistances() {
        let sessions = (try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? []
        for session in sessions {
            let points = fetchRoutePoints(sessionId: session.id)
            guard points.count >= 2 else { continue }
            let filtered = DistanceCalculator.filteredDistanceMeters(points: points)
            // 1 m tolerance: haversine vs CoreLocation's geodesic distance differ by
            // fractions of a metre, which shouldn't rewrite every clean session.
            if abs(filtered - session.distanceMeters) > 1 {
                session.distanceMeters = filtered
            }
        }
        try? context.save()
    }

    private func fetchSession(id: UUID) -> WorkoutSession? {
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.id == id }
        )
        return try? context.fetch(descriptor).first
    }

    private func fetchRoutePoints(sessionId: UUID) -> [RoutePoint] {
        let descriptor = FetchDescriptor<RoutePoint>(
            predicate: #Predicate { $0.sessionId == sessionId },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
}

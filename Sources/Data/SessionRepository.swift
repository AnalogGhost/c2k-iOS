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

    /// Saves a running workout's progress so far, so it survives the app being closed. Never
    /// touches a workout that has already ended.
    func checkpointSession(id: UUID, durationSeconds: Int, distanceMeters: Double) {
        guard let session = fetchSession(id: id), session.completedAt == nil else { return }
        session.durationSeconds = durationSeconds
        session.distanceMeters = distanceMeters
        try? context.save()
    }

    /// Recovers workouts the app was closed during (by iOS or a crash), started before `cutoff`
    /// so a workout starting right now is never touched. Each keeps its last saved time, with the
    /// distance rebuilt from its recorded route, which runs right up to the moment the app closed;
    /// its completedAt stays nil, marking it as not ended by the runner. One with nothing to keep
    /// (closed within its first seconds) is deleted. Safe to run on every launch. Returns how
    /// many workouts were recovered.
    @discardableResult
    func recoverInterruptedSessions(startedBefore cutoff: Date) -> Int {
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.completedAt == nil && $0.startedAt < cutoff }
        )
        var recovered = 0
        for session in (try? context.fetch(descriptor)) ?? [] {
            let points = fetchRoutePoints(sessionId: session.id)
            if session.durationSeconds == 0 && points.isEmpty {
                context.delete(session)
                continue
            }
            recovered += 1
            if points.count >= 2 {
                let routed = DistanceCalculator.filteredDistanceMeters(points: points)
                if routed > session.distanceMeters { session.distanceMeters = routed }
            }
        }
        try? context.save()
        return recovered
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

    /// Every workout and its route, oldest first, for the runner to keep as a file.
    func exportBackup(exportedAt: Date = .now) -> Backup {
        let sessions = (try? context.fetch(FetchDescriptor<WorkoutSession>(sortBy: [SortDescriptor(\.startedAt)]))) ?? []
        return Backup(exportedAt: exportedAt.millisecondsSince1970, sessions: sessions.map { session in
            Backup.Session(
                programId: session.programId,
                week: session.week,
                day: session.day,
                startedAt: session.startedAt.millisecondsSince1970,
                completedAt: session.completedAt?.millisecondsSince1970,
                durationSeconds: session.durationSeconds,
                distanceMeters: session.distanceMeters,
                completed: session.completed,
                route: fetchRoutePoints(sessionId: session.id).map {
                    Backup.Point(
                        latitude: $0.latitude,
                        longitude: $0.longitude,
                        altitudeMeters: $0.altitudeMeters,
                        speedMps: $0.speedMps.map(Double.init),
                        recordedAt: $0.timestamp.millisecondsSince1970
                    )
                }
            )
        })
    }

    /// Adds a backup's workouts to the history, all or none. Merges rather than replaces: a
    /// workout already here (same program and start time) is skipped, so importing the same file
    /// twice, or into a phone that's already been used, does no harm. Workouts from a program this
    /// version doesn't have are skipped too. Returns how many workouts were added.
    func importBackup(_ backup: Backup) throws -> Int {
        struct Key: Hashable { let programId: String; let startedAt: Int64 }
        let existingSessions = try context.fetch(FetchDescriptor<WorkoutSession>())
        var existing = Set(existingSessions.map { Key(programId: $0.programId, startedAt: $0.startedAt.millisecondsSince1970) })
        let knownPrograms = Set(Programs.all().map(\.programId))
        var added = 0
        for item in backup.sessions {
            guard knownPrograms.contains(item.programId), item.week >= 1, item.day >= 1,
                  existing.insert(Key(programId: item.programId, startedAt: item.startedAt)).inserted
            else { continue }
            let session = WorkoutSession(programId: item.programId, week: item.week, day: item.day)
            session.startedAt = Date(millisecondsSince1970: item.startedAt)
            session.completedAt = item.completedAt.map(Date.init(millisecondsSince1970:))
            session.durationSeconds = item.durationSeconds
            session.distanceMeters = item.distanceMeters
            session.completed = item.completed
            context.insert(session)
            for point in item.route {
                context.insert(RoutePoint(sessionId: session.id, update: LocationUpdate(
                    latitude: point.latitude,
                    longitude: point.longitude,
                    altitudeMeters: point.altitudeMeters,
                    speedMps: point.speedMps.map(Float.init),
                    timestamp: Date(millisecondsSince1970: point.recordedAt)
                )))
            }
            added += 1
        }
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        return added
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

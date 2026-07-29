import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @Environment(UserPreferences.self) private var prefs

    @Query(sort: \WorkoutSession.startedAt, order: .reverse)
    private var sessions: [WorkoutSession]

    @State private var deleteTarget: WorkoutSession?
    @State private var showDeleteConfirm = false

    var body: some View {
        Group {
            if sessions.isEmpty {
                ContentUnavailableView("No workouts yet", systemImage: "figure.run",
                                       description: Text("Complete a workout to see your history here."))
            } else {
                List {
                    Section {
                        StatsCard(sessions: sessions, weightKg: prefs.weightKg)
                    }

                    Section("Sessions") {
                        ForEach(sessions, id: \.id) { session in
                            SessionRow(session: session) {
                                exportGpx(session: session)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    deleteTarget = session
                                    showDeleteConfirm = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("History")
        .toolbar {
            if !sessions.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ShareLink(item: buildCsv(sessions: sessions),
                              subject: Text("C2K Workout History"),
                              message: Text("")) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .confirmationDialog("Delete workout?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let session = deleteTarget {
                    SessionRepository(context: context).deleteSession(id: session.id)
                }
                deleteTarget = nil
            }
            Button("Cancel", role: .cancel) { deleteTarget = nil }
        } message: {
            Text("This will permanently remove this session from your history.")
        }
    }

    private func exportGpx(session: WorkoutSession) {
        let points = SessionRepository(context: context).routePoints(sessionId: session.id)
        guard !points.isEmpty else { return }
        let gpx = buildGpx(session: session, points: points)
        let av = UIActivityViewController(activityItems: [gpx], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(av, animated: true)
        }
    }
}

private struct StatsCard: View {
    let sessions: [WorkoutSession]
    let weightKg: Double?

    private var completed: [WorkoutSession] { sessions.filter { $0.completed } }
    private var totalKm: Double { sessions.reduce(0) { $0 + $1.distanceMeters } / 1000 }
    private var totalSeconds: Int { sessions.reduce(0) { $0 + $1.durationSeconds } }

    private var eligible: [WorkoutSession] { sessions.filter { $0.completed && $0.distanceMeters > 0 } }

    private var totalCalories: Int? {
        guard let weightKg else { return nil }
        return sessions.reduce(0) { total, s in
            total + (CalorieCalculator.estimateCalories(
                distanceMeters: s.distanceMeters, durationSeconds: s.durationSeconds, weightKg: weightKg
            ) ?? 0)
        }
    }

    private var fastestPaceSecPerKm: Double? {
        eligible.map { Double($0.durationSeconds) / ($0.distanceMeters / 1000) }.min()
    }

    private var longestRunMeters: Double? {
        eligible.map(\.distanceMeters).max()
    }

    var body: some View {
        VStack(spacing: 4) {
            Text("Totals").font(.caption.bold()).foregroundStyle(.secondary)
            HStack {
                Spacer()
                StatItem(value: "\(completed.count)", label: workoutsLabel)
                Spacer()
                StatItem(value: String(format: "%.1f", totalKm), label: String(localized: "km"))
                Spacer()
                StatItem(value: formatDuration(totalSeconds), label: String(localized: "time"))
                Spacer()
            }

            if totalCalories != nil || fastestPaceSecPerKm != nil || longestRunMeters != nil {
                Divider().padding(.vertical, 8)
                Text("Personal bests").font(.caption.bold()).foregroundStyle(.secondary)
                HStack {
                    Spacer()
                    if let totalCalories {
                        StatItem(value: "\(totalCalories)", label: String(localized: "kcal"))
                        Spacer()
                    }
                    if let pace = fastestPaceSecPerKm {
                        StatItem(value: String(format: "%d:%02d", Int(pace) / 60, Int(pace) % 60), label: String(localized: "pace"))
                        Spacer()
                    }
                    if let longest = longestRunMeters {
                        StatItem(value: String(format: "%.2f", longest / 1000), label: String(localized: "longest"))
                        Spacer()
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var workoutsLabel: String {
        String.localizedStringWithFormat(NSLocalizedString("history_stats_workouts", comment: ""), completed.count)
    }
}

private struct StatItem: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.title2.bold())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }
}

private struct SessionRow: View {
    let session: WorkoutSession
    let onExportGpx: () -> Void

    private var displayName: String {
        Programs.all().first(where: { $0.programId == session.programId })?.displayName ?? session.programId
    }

    var body: some View {
        let weekDay = String(format: String(localized: "history_week_day"), session.week, session.day)
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if session.completed {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.warmCoolGreen)
                }
                Text("\(displayName)  ·  \(weekDay)")
                    .font(.headline)
                Spacer()
                if session.distanceMeters > 0 {
                    Button(action: onExportGpx) {
                        Image(systemName: "map").foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                }
            }
            Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.subheadline).foregroundStyle(.secondary)
            if session.distanceMeters > 0 {
                Text("\(distanceText(session.distanceMeters))  ·  \(formatDuration(session.durationSeconds))")
                    .font(.subheadline)
            } else {
                Text(formatDuration(session.durationSeconds)).font(.subheadline)
            }
        }
        .padding(.vertical, 4)
    }
}

private func formatDuration(_ totalSeconds: Int) -> String {
    let h = totalSeconds / 3600
    let m = (totalSeconds % 3600) / 60
    let s = totalSeconds % 60
    return h > 0
        ? String(format: "%d:%02d:%02d", h, m, s)
        : String(format: "%d:%02d", m, s)
}

private func buildCsv(sessions: [WorkoutSession]) -> String {
    let header = "Program,Week,Day,Date,Duration,Distance_m,Completed"
    let rows = sessions.map { s in
        let name = Programs.all().first(where: { $0.programId == s.programId })?.displayName ?? s.programId
        let date = s.startedAt.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false))
        return "\(name),\(s.week),\(s.day),\(date),\(formatDuration(s.durationSeconds)),\(Int(s.distanceMeters)),\(s.completed)"
    }
    return ([header] + rows).joined(separator: "\n")
}

private func buildGpx(session: WorkoutSession, points: [RoutePoint]) -> String {
    let dateStr = session.startedAt.ISO8601Format()
    var lines = [
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
        "<gpx version=\"1.1\" creator=\"C2K\" xmlns=\"http://www.topografix.com/GPX/1/1\">",
        "  <trk>",
        "    <name>C2K W\(session.week)D\(session.day)</name>",
        "    <trkseg>",
    ]
    for point in points {
        let alt = point.altitudeMeters.map { "      <ele>\($0)</ele>" } ?? ""
        let ts = point.timestamp.ISO8601Format()
        lines += [
            "      <trkpt lat=\"\(point.latitude)\" lon=\"\(point.longitude)\">",
            alt,
            "        <time>\(ts)</time>",
            "      </trkpt>",
        ]
    }
    lines += ["    </trkseg>", "  </trk>", "</gpx>"]
    return lines.filter { !$0.isEmpty }.joined(separator: "\n")
}

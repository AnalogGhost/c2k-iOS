import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(UserPreferences.self) private var prefs
    @Environment(WorkoutManager.self) private var workoutManager
    @Environment(\.modelContext) private var context

    @Query(sort: \WorkoutSession.startedAt, order: .reverse)
    private var allSessions: [WorkoutSession]

    @State private var path: [AppRoute] = []
    @State private var showContinuePreview = false

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if streak > 0 {
                    Section {
                        Text(streakText)
                            .foregroundColor(.runOrange)
                            .font(.subheadline)
                            .listRowBackground(Color.clear)
                    }
                }

                if workoutManager.isRunning, let info = workoutManager.currentWorkoutInfo {
                    Section {
                        Button {
                            path.append(.workout(programId: info.programId, week: info.week, day: info.day))
                        } label: {
                            Label("Workout in progress — tap to return", systemImage: "figure.run")
                                .foregroundColor(.warmCoolGreen)
                        }
                    }
                }

                if !workoutManager.isRunning, let next = nextWorkout {
                    Section {
                        Button {
                            showContinuePreview = true
                        } label: {
                            Label(continueWorkoutText(next), systemImage: "play.fill")
                        }
                    }
                    .sheet(isPresented: $showContinuePreview) {
                        WorkoutPreviewSheet(
                            week: next.week,
                            day: next.day,
                            workoutDay: next.workoutDay,
                            isCompleted: false
                        ) {
                            showContinuePreview = false
                            path.append(.workout(programId: next.programId, week: next.week, day: next.day))
                        }
                        .presentationDetents([.medium, .large])
                    }
                }

                Section("Choose a program") {
                    ForEach(Programs.all(), id: \.programId) { plan in
                        Button {
                            prefs.lastProgramId = plan.programId
                            path.append(.program(programId: plan.programId))
                        } label: {
                            ProgramRow(plan: plan)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !recentSessions.isEmpty {
                    Section("Recent workouts") {
                        ForEach(recentSessions, id: \.id) { session in
                            RecentSessionRow(session: session)
                        }
                    }
                }
            }
            .navigationTitle("C2K")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { path.append(.contributors) } label: {
                        Image(systemName: "person.2")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { path.append(.guide) } label: {
                        Image(systemName: "book")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { path.append(.history) } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { path.append(.settings) } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .program(let id):
                    ProgramSelectView(programId: id, path: $path)
                case .workout(let id, let week, let day):
                    WorkoutView(programId: id, week: week, day: day, path: $path)
                case .history:
                    HistoryView()
                case .settings:
                    SettingsView()
                case .guide:
                    GuideView()
                case .contributors:
                    ContributorsView()
                }
            }
        }
    }

    private var recentSessions: [WorkoutSession] {
        Array(allSessions.prefix(5))
    }

    private var streak: Int {
        let completed = allSessions.filter { $0.completed }
        let dayNumbers = Set(completed.map { Int($0.startedAt.timeIntervalSince1970) / 86400 })
        guard !dayNumbers.isEmpty else { return 0 }

        let today = Int(Date.now.timeIntervalSince1970) / 86400
        guard dayNumbers.contains(today) || dayNumbers.contains(today - 1) else { return 0 }

        let sorted = dayNumbers.sorted(by: >)
        var count = 1
        var expected = sorted[0] - 1
        for d in sorted.dropFirst() {
            if d == expected { count += 1; expected -= 1 }
            else if d < expected { break }
        }
        return count
    }

    private var streakText: String {
        String.localizedStringWithFormat(NSLocalizedString("home_streak", comment: ""), streak)
    }

    private func continueWorkoutText(_ next: NextWorkout) -> String {
        String(format: String(localized: "home_continue_workout"), next.displayName, next.week, next.day)
    }

    private var nextWorkout: NextWorkout? {
        guard let programId = prefs.lastProgramId else { return nil }
        guard let plan = Programs.all().first(where: { $0.programId == programId }) else { return nil }
        let repo = SessionRepository(context: context)
        let completed = repo.completedDays(programId: programId)
        for (weekIdx, days) in plan.weeks.enumerated() {
            for (dayIdx, workoutDay) in days.enumerated() {
                let wd = WeekDay(week: weekIdx + 1, day: dayIdx + 1)
                if !completed.contains(wd) {
                    return NextWorkout(
                        programId: programId,
                        displayName: plan.displayName,
                        week: weekIdx + 1,
                        day: dayIdx + 1,
                        workoutDay: workoutDay
                    )
                }
            }
        }
        return nil
    }
}

private struct NextWorkout {
    let programId: String
    let displayName: String
    let week: Int
    let day: Int
    let workoutDay: WorkoutDay
}

private struct ProgramRow: View {
    let plan: WorkoutPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(plan.displayName).font(.headline)
                Spacer()
                Text(String(format: String(localized: "home_program_weeks"), plan.totalWeeks))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if !plan.description.isEmpty {
                Text(plan.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let prereq = plan.prerequisite {
                Text(prereq)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct RecentSessionRow: View {
    let session: WorkoutSession

    var body: some View {
        let displayName = Programs.all().first(where: { $0.programId == session.programId })?.displayName
            ?? session.programId
        let weekDay = String(format: String(localized: "history_week_day"), session.week, session.day)
        HStack {
            Text("\(weekDay)  ·  \(displayName)")
                .font(.subheadline)
            Spacer()
            Text(session.startedAt, style: .date)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

enum AppRoute: Hashable {
    case program(programId: String)
    case workout(programId: String, week: Int, day: Int)
    case history
    case settings
    case guide
    case contributors
}

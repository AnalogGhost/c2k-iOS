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
                            .foregroundColor(.runOrangeText)
                            .font(.subheadline)
                            .listRowBackground(Color.clear)
                            .accessibilityIdentifier("home-streak")
                    }
                }

                if workoutManager.isRunning, let info = workoutManager.currentWorkoutInfo {
                    Section {
                        Button {
                            path.append(.workout(programId: info.programId, week: info.week, day: info.day))
                        } label: {
                            Label("Workout in progress — tap to return", systemImage: "figure.run")
                                .foregroundColor(.greenText)
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

                    if let suggestion = progressionSuggestion(for: next) {
                        Section {
                            ProgressionSuggestionCard(
                                suggestion: suggestion,
                                onAccept: { accept(suggestion, for: next) },
                                onDismiss: { prefs.progressionDismissedAt = .now }
                            )
                        }
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
                        .accessibilityIdentifier("program-\(plan.programId)")
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
                    .accessibilityIdentifier("nav-contributors")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { path.append(.guide) } label: {
                        Image(systemName: "book")
                    }
                    .accessibilityIdentifier("nav-guide")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { path.append(.history) } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .accessibilityIdentifier("nav-history")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { path.append(.settings) } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityIdentifier("nav-settings")
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
        WorkoutStats.streak(sessions: allSessions)
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
        // A week the runner chose to repeat comes first; once it's done again, the plan's usual
        // next workout (the day they were stuck on) takes over.
        guard let wd = ProgressionAdvisor.nextInRepeatedWeek(plan: plan, repeated: prefs.repeatedWeek, sessions: allSessions)
            ?? plan.nextWorkout(completedDays: completed) else { return nil }
        return NextWorkout(
            programId: programId,
            displayName: plan.localizedName,
            week: wd.week,
            day: wd.day,
            workoutDay: plan.workoutDay(week: wd.week, day: wd.day, skipWarmup: prefs.skipWarmup, skipCooldown: prefs.skipCooldown)
        )
    }
}

extension HomeView {
    private func progressionSuggestion(for next: NextWorkout) -> ProgressionSuggestion? {
        ProgressionAdvisor.suggest(plan: Programs.byId(next.programId), week: next.week, day: next.day,
                                   sessions: allSessions, dismissedAt: prefs.progressionDismissedAt)
    }

    private func accept(_ suggestion: ProgressionSuggestion, for next: NextWorkout) {
        switch suggestion {
        case .repeatWeek(let week, _):
            prefs.repeatedWeek = RepeatedWeek(programId: next.programId, week: week, since: .now)
        case .tryPreC25K:
            prefs.lastProgramId = Programs.idPreC25K
        }
    }
}

private struct ProgressionSuggestionCard: View {
    let suggestion: ProgressionSuggestion
    let onAccept: () -> Void
    let onDismiss: () -> Void

    private var message: String {
        let stops = String.localizedStringWithFormat(
            NSLocalizedString("progression_body_stops", comment: ""), suggestion.earlyStops)
        switch suggestion {
        case .repeatWeek(let week, _):
            return stops + " " + String(format: String(localized: "progression_body_repeat_week"), week)
        case .tryPreC25K:
            return stops + " " + String(localized: "progression_body_pre_c25k")
        }
    }

    private var action: String {
        switch suggestion {
        case .repeatWeek(let week, _):
            return String(format: String(localized: "progression_action_repeat_week"), week)
        case .tryPreC25K:
            return String(localized: "progression_action_pre_c25k")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("progression_title").font(.headline)
            Text(message).font(.subheadline)
            HStack {
                Spacer()
                Button("progression_action_dismiss", action: onDismiss)
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("progression-dismiss")
                Button(action, action: onAccept)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("progression-accept")
            }
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("progression-suggestion")
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
                Text(plan.localizedName).font(.headline)
                Spacer()
                Text(String(format: String(localized: "home_program_weeks"), plan.totalWeeks))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if !plan.localizedDescription.isEmpty {
                Text(plan.localizedDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let prereq = plan.localizedPrerequisite {
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
        let displayName = Programs.all().first(where: { $0.programId == session.programId })?.localizedName
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

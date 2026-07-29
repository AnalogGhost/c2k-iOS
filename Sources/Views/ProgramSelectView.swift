import SwiftUI
import SwiftData

struct ProgramSelectView: View {
    let programId: String
    @Binding var path: [AppRoute]

    @Environment(\.modelContext) private var context

    @Query private var sessions: [WorkoutSession]

    @State private var expandedWeeks: [Int: Bool] = [:]
    @State private var previewDay: WeekDay?
    @State private var showResetConfirm = false

    init(programId: String, path: Binding<[AppRoute]>) {
        self.programId = programId
        self._path = path
        _sessions = Query(filter: #Predicate<WorkoutSession> {
            $0.programId == programId && $0.completed == true
        })
    }

    private var plan: WorkoutPlan { Programs.byId(programId) }

    private var completedDays: Set<WeekDay> {
        Set(sessions.map { WeekDay(week: $0.week, day: $0.day) })
    }

    private var totalDays: Int { plan.weeks.reduce(0) { $0 + $1.count } }

    var body: some View {
        List {
            if !plan.description.isEmpty {
                Section {
                    Text(plan.description).foregroundStyle(.secondary)
                }
            }

            if !completedDays.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: Double(completedDays.count), total: Double(totalDays))
                        Text(String(format: String(localized: "program_progress"), completedDays.count, totalDays))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if let next = nextIncompleteDay {
                        Button {
                            previewDay = next
                        } label: {
                            Label(
                                String(format: String(localized: "program_next_workout"), next.week, next.day),
                                systemImage: "play.fill"
                            )
                        }
                    }
                }
            }

            ForEach(Array(plan.weeks.enumerated()), id: \.offset) { weekIdx, days in
                let week = weekIdx + 1
                let weekComplete = days.indices.allSatisfy { completedDays.contains(WeekDay(week: week, day: $0 + 1)) }
                let expanded = expandedWeeks[weekIdx] ?? !weekComplete

                Section {
                    if expanded {
                        if let tip = CoachingTips.tip(programId: programId, week: week) {
                            Text(tip).font(.caption).foregroundStyle(.secondary)
                        }
                        HStack(spacing: 8) {
                            ForEach(Array(days.enumerated()), id: \.offset) { dayIdx, workoutDay in
                                let day = dayIdx + 1
                                let done = completedDays.contains(WeekDay(week: week, day: day))
                                DayButton(day: day, durationMin: workoutDay.totalDurationSeconds / 60, completed: done) {
                                    previewDay = WeekDay(week: week, day: day)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Button {
                        expandedWeeks[weekIdx] = !expanded
                    } label: {
                        HStack {
                            Text(String(format: String(localized: "program_week_label"), week))
                                .font(.headline).foregroundStyle(.primary)
                            if weekComplete {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.warmCoolGreen).font(.subheadline)
                            }
                            Spacer()
                            Image(systemName: expanded ? "chevron.up" : "chevron.down")
                                .foregroundStyle(.secondary).font(.subheadline)
                        }
                    }
                }
            }
        }
        .navigationTitle(plan.displayName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if !completedDays.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(role: .destructive) { showResetConfirm = true } label: {
                            Label("Reset progress", systemImage: "arrow.counterclockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .confirmationDialog("Reset progress", isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("Reset", role: .destructive) {
                SessionRepository(context: context).resetProgress(programId: programId)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove all completed sessions for this program. Your overall history is kept.")
        }
        .sheet(item: Binding(get: { previewDay }, set: { previewDay = $0 })) { wd in
            let workoutDay = plan.weeks[wd.week - 1][wd.day - 1]
            WorkoutPreviewSheet(
                week: wd.week, day: wd.day,
                workoutDay: workoutDay,
                isCompleted: completedDays.contains(wd)
            ) {
                previewDay = nil
                path.append(.workout(programId: programId, week: wd.week, day: wd.day))
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var nextIncompleteDay: WeekDay? {
        for (weekIdx, days) in plan.weeks.enumerated() {
            for dayIdx in days.indices {
                let wd = WeekDay(week: weekIdx + 1, day: dayIdx + 1)
                if !completedDays.contains(wd) { return wd }
            }
        }
        return nil
    }
}

extension WeekDay: Identifiable {
    var id: String { "\(week)-\(day)" }
}

private struct DayButton: View {
    let day: Int
    let durationMin: Int
    let completed: Bool
    let action: () -> Void

    var body: some View {
        if completed {
            Button(action: action) { label }
                .buttonStyle(.bordered)
                .tint(.warmCoolGreen)
        } else {
            Button(action: action) { label }
                .buttonStyle(.borderedProminent)
        }
    }

    private var label: some View {
        VStack(spacing: 2) {
            if completed {
                Image(systemName: "checkmark.circle.fill").font(.caption)
            }
            Text(String(format: String(localized: "program_day_label"), day)).font(.subheadline.bold())
            Text("~\(durationMin)\(String(localized: "m"))").font(.caption2).opacity(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
}

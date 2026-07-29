import SwiftUI
import CoreLocation
import SwiftData

struct WorkoutView: View {
    let programId: String
    let week: Int
    let day: Int
    @Binding var path: [AppRoute]

    @Environment(UserPreferences.self) private var prefs
    @Environment(WorkoutManager.self) private var workoutManager
    @Environment(\.modelContext) private var context
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State private var permissionResolved = false
    @State private var showStopDialog = false
    @State private var personalBest: WorkoutSession?
    @State private var locationManager = CLLocationManager()

    private var programName: String {
        Programs.byId(programId).displayName
    }

    private var isLandscape: Bool { verticalSizeClass == .compact }

    private var navigationTitleText: String {
        let weekDay = String(format: String(localized: "history_week_day"), week, day)
        return String(format: String(localized: "workout_title"), programName, weekDay)
    }

    var body: some View {
        VStack(spacing: 24) {
            switch workoutManager.workoutState {
            case .active(let s):
                ActiveWorkoutContent(
                    state: s,
                    distanceMeters: workoutManager.distanceMeters,
                    currentSpeedMps: workoutManager.currentSpeedMps,
                    gpsActive: workoutManager.gpsActive,
                    hasGpsLock: workoutManager.hasGpsLock,
                    treadmillMode: prefs.treadmillMode,
                    isLandscape: isLandscape,
                    onPause: { workoutManager.pause() },
                    onStop: { showStopDialog = true }
                )
            case .paused(let s):
                PausedWorkoutContent(
                    state: s,
                    isLandscape: isLandscape,
                    onResume: { workoutManager.resume() },
                    onStop: { showStopDialog = true }
                )
            case .completed(let sessionId, let elapsed):
                CompletedContent(
                    elapsedSeconds: elapsed,
                    distanceMeters: workoutManager.distanceMeters,
                    weightKg: prefs.weightKg,
                    personalBest: personalBest,
                    onDone: { path.removeAll() }
                )
                .onAppear { loadPersonalBest(excluding: sessionId) }
            default:
                Text(workoutManager.isRunning ? "Reconnecting…" : "Starting…")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .navigationTitle(navigationTitleText)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    if case .completed = workoutManager.workoutState {
                        path.removeAll()
                    } else {
                        showStopDialog = true
                    }
                } label: {
                    if case .completed = workoutManager.workoutState {
                        Image(systemName: "chevron.left")
                    } else {
                        EmptyView()
                    }
                }
            }
        }
        .confirmationDialog("Stop workout?", isPresented: $showStopDialog, titleVisibility: .visible) {
            Button("Stop", role: .destructive) {
                workoutManager.stop()
                path.removeAll()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your progress will be saved as incomplete.")
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = prefs.keepScreenOn
            if prefs.gpsEnabled {
                locationManager.requestWhenInUseAuthorization()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                startWorkoutIfNeeded()
            }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    private func startWorkoutIfNeeded() {
        guard !workoutManager.isRunning else { return }
        let repo = SessionRepository(context: context)
        workoutManager.start(
            programId: programId, week: week, day: day,
            prefs: prefs, repository: repo
        )
    }

    private func loadPersonalBest(excluding sessionId: UUID) {
        let repo = SessionRepository(context: context)
        personalBest = repo.bestSession(programId: programId, week: week, day: day, excluding: sessionId)
    }
}

// MARK: - Active

private struct ActiveWorkoutContent: View {
    let state: WorkoutState.ActiveSnapshot
    let distanceMeters: Double
    let currentSpeedMps: Float?
    let gpsActive: Bool
    let hasGpsLock: Bool
    let treadmillMode: Bool
    let isLandscape: Bool
    let onPause: () -> Void
    let onStop: () -> Void

    private var ringColor: Color { intervalColor(state.currentInterval.type) }
    private var label: String { intervalLabel(state.currentInterval.type) }
    private var progress: Double {
        (1.0 - Double(state.secondsRemainingInInterval) / Double(state.currentInterval.durationSeconds))
            .clamped(to: 0...1)
    }

    var body: some View {
        ProgressView(value: Double(state.intervalIndex), total: Double(state.totalIntervals))

        if isLandscape {
            Spacer()
            HStack(spacing: 48) {
                ring(size: 180)
                VStack(spacing: 24) {
                    details
                    controls
                }
            }
            Spacer()
        } else {
            Spacer()
            ring(size: 220)
            if let next = state.nextInterval {
                Text(nextIntervalText(next))
                    .font(.subheadline)
                    .foregroundColor(intervalColor(next.type).opacity(0.75))
            }
            details
            Spacer()
            controls
        }
    }

    private func nextIntervalText(_ next: Interval) -> String {
        String(format: String(localized: "workout_next_interval"),
               intervalLabel(next.type), formatTime(next.durationSeconds))
    }

    private func ring(size: CGFloat) -> some View {
        IntervalRingView(
            progress: progress,
            ringColor: ringColor,
            accessibilityLabel: "\(label): \(formatTime(state.secondsRemainingInInterval)) remaining",
            size: size
        ) {
            VStack(spacing: 4) {
                Text(label).font(.title3.bold()).foregroundColor(ringColor)
                Text(formatTime(state.secondsRemainingInInterval))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
            }
        }
    }

    @ViewBuilder
    private var details: some View {
        VStack(spacing: 4) {
            if isLandscape, let next = state.nextInterval {
                Text(nextIntervalText(next))
                    .font(.subheadline)
                    .foregroundColor(intervalColor(next.type).opacity(0.75))
            }

            Text(String(format: String(localized: "workout_elapsed"), formatTime(state.elapsedSessionSeconds)))
                .font(.body)
                .foregroundStyle(.secondary)
            Text(String(format: String(localized: "workout_interval_progress"), state.intervalIndex + 1, state.totalIntervals))
                .font(.body)
                .foregroundStyle(.tertiary)

            if treadmillMode {
                Text(treadmillEffortCue(state.currentInterval.type))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if distanceMeters > 0 {
                HStack(spacing: 16) {
                    Text(distanceText(distanceMeters)).font(.body)
                    if let pace = paceString(speedMps: currentSpeedMps) {
                        Text(String(format: String(localized: "workout_pace"), pace)).font(.body)
                    }
                }
            } else if gpsActive && !hasGpsLock {
                Text("Acquiring GPS…").font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 16) {
            Button(action: onPause) {
                Label("Pause", systemImage: "pause.fill")
            }
            .buttonStyle(.borderedProminent)

            Button(action: onStop) {
                Label("Stop", systemImage: "stop.fill")
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
        }
    }

    private func paceString(speedMps: Float?) -> String? {
        guard let speed = speedMps, speed >= 0.5 else { return nil }
        let paceMinPerKm = 1000.0 / (Double(speed) * 60.0)
        let m = Int(paceMinPerKm)
        let s = Int((paceMinPerKm.truncatingRemainder(dividingBy: 1)) * 60)
        return String(format: "%d:%02d", m, s)
    }
}

private func treadmillEffortCue(_ type: IntervalType) -> String {
    switch type {
    case .run:      return String(localized: "Comfortable running pace")
    case .walk:     return String(localized: "Brisk walking pace")
    case .warmup, .cooldown:
                    return String(localized: "Easy walking pace")
    }
}

// MARK: - Paused

private struct PausedWorkoutContent: View {
    let state: WorkoutState.ActiveSnapshot
    let isLandscape: Bool
    let onResume: () -> Void
    let onStop: () -> Void

    private var ringColor: Color { intervalColor(state.currentInterval.type) }
    private var label: String { intervalLabel(state.currentInterval.type) }
    private var progress: Double {
        (1.0 - Double(state.secondsRemainingInInterval) / Double(state.currentInterval.durationSeconds))
            .clamped(to: 0...1)
    }

    var body: some View {
        ProgressView(value: Double(state.intervalIndex), total: Double(state.totalIntervals))

        if isLandscape {
            Spacer()
            HStack(spacing: 48) {
                ring(size: 180)
                VStack(spacing: 24) {
                    details
                    controls
                }
            }
            Spacer()
        } else {
            Spacer()
            ring(size: 220)
            details
            Spacer()
            controls
        }
    }

    private func ring(size: CGFloat) -> some View {
        IntervalRingView(
            progress: progress,
            ringColor: ringColor,
            accessibilityLabel: "Paused: \(label)",
            size: size
        ) {
            VStack(spacing: 4) {
                Text(label).font(.title3.bold()).foregroundColor(ringColor)
                Text(formatTime(state.secondsRemainingInInterval))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
            }
        }
    }

    private var details: some View {
        VStack(spacing: 4) {
            Text("PAUSED")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(String(format: String(localized: "workout_elapsed"), formatTime(state.elapsedSessionSeconds)))
                .font(.body)
        }
    }

    private var controls: some View {
        HStack(spacing: 16) {
            Button(action: onResume) {
                Label("Resume", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)

            Button(action: onStop) {
                Label("Stop", systemImage: "stop.fill")
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
        }
    }
}

// MARK: - Completed

private struct CompletedContent: View {
    let elapsedSeconds: Int
    let distanceMeters: Double
    let weightKg: Double?
    let personalBest: WorkoutSession?
    let onDone: () -> Void

    var body: some View {
        Spacer()

        VStack(spacing: 8) {
            Text("Workout Complete!")
                .font(.largeTitle.bold())
                .foregroundColor(.warmCoolGreen)
            Text("Great job! Keep up the good work.")
                .font(.body).foregroundStyle(.secondary)
        }

        VStack(spacing: 4) {
            Text(String(format: String(localized: "workout_complete_time"), formatTime(elapsedSeconds)))
                .font(.title2.bold())
            if distanceMeters > 0 {
                Text(distanceText(distanceMeters)).font(.title3)

                if let weightKg, let calories = CalorieCalculator.estimateCalories(
                    distanceMeters: distanceMeters, durationSeconds: elapsedSeconds, weightKg: weightKg
                ) {
                    Text(String(format: String(localized: "workout_calories_burned"), calories))
                        .font(.title3)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Set your weight in Settings to see calories burned")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.top, 16)

        if let best = personalBest {
            VStack(spacing: 4) {
                if elapsedSeconds < best.durationSeconds {
                    Text("New personal best!")
                        .font(.headline)
                        .foregroundColor(.warmCoolGreen)
                }
                Text(String(format: String(localized: "workout_previous_best"), formatTime(best.durationSeconds)))
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            .padding(.top, 8)
        }

        Spacer()

        Button("Done", action: onDone)
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 40)
    }
}

// MARK: - Helpers

private func intervalColor(_ type: IntervalType) -> Color {
    switch type {
    case .run:              return .runOrange
    case .walk:             return .walkBlue
    case .warmup, .cooldown: return .warmCoolGreen
    }
}

func intervalLabel(_ type: IntervalType) -> String {
    switch type {
    case .run:      return String(localized: "RUN")
    case .walk:     return String(localized: "WALK")
    case .warmup:   return String(localized: "WARM UP")
    case .cooldown: return String(localized: "COOL DOWN")
    }
}

func formatTime(_ totalSeconds: Int) -> String {
    let m = totalSeconds / 60
    let s = totalSeconds % 60
    return String(format: "%d:%02d", m, s)
}

func distanceText(_ distanceMeters: Double) -> String {
    String(format: String(localized: "workout_distance_km"), locale: Locale.current, distanceMeters / 1000)
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}


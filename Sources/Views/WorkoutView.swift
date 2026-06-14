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

    @State private var permissionResolved = false
    @State private var showStopDialog = false
    @State private var personalBest: WorkoutSession?
    @State private var locationManager = CLLocationManager()

    private var programName: String {
        Programs.byId(programId).displayName
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
                    onPause: { workoutManager.pause() },
                    onStop: { showStopDialog = true }
                )
            case .paused(let s):
                PausedWorkoutContent(
                    state: s,
                    onResume: { workoutManager.resume() },
                    onStop: { showStopDialog = true }
                )
            case .completed(let sessionId, let elapsed):
                CompletedContent(
                    elapsedSeconds: elapsed,
                    distanceMeters: workoutManager.distanceMeters,
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
        .navigationTitle("\(programName) · Week \(week), Day \(day)")
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
    let onPause: () -> Void
    let onStop: () -> Void

    var body: some View {
        let ringColor = intervalColor(state.currentInterval.type)
        let label = intervalLabel(state.currentInterval.type)
        let progress = 1.0 - Double(state.secondsRemainingInInterval) / Double(state.currentInterval.durationSeconds)

        ProgressView(value: Double(state.intervalIndex), total: Double(state.totalIntervals))

        Spacer()

        IntervalRingView(
            progress: progress.clamped(to: 0...1),
            ringColor: ringColor,
            accessibilityLabel: "\(label): \(formatTime(state.secondsRemainingInInterval)) remaining"
        ) {
            VStack(spacing: 4) {
                Text(label).font(.title3.bold()).foregroundColor(ringColor)
                Text(formatTime(state.secondsRemainingInInterval))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
            }
        }

        if let next = state.nextInterval {
            Text("Next: \(intervalLabel(next.type)) \(formatTime(next.durationSeconds))")
                .font(.subheadline)
                .foregroundColor(intervalColor(next.type).opacity(0.75))
        }

        VStack(spacing: 4) {
            Text("Elapsed: \(formatTime(state.elapsedSessionSeconds))").font(.body)
                .foregroundStyle(.secondary)
            Text("Interval \(state.intervalIndex + 1) of \(state.totalIntervals)").font(.body)
                .foregroundStyle(.tertiary)

            if distanceMeters > 0 {
                HStack(spacing: 16) {
                    Text(String(format: "%.2f km", distanceMeters / 1000)).font(.body)
                    if let pace = paceString(speedMps: currentSpeedMps) {
                        Text("\(pace) / km").font(.body)
                    }
                }
            } else if gpsActive && !hasGpsLock {
                Text("Acquiring GPS…").font(.subheadline).foregroundStyle(.secondary)
            }
        }

        Spacer()

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

// MARK: - Paused

private struct PausedWorkoutContent: View {
    let state: WorkoutState.ActiveSnapshot
    let onResume: () -> Void
    let onStop: () -> Void

    var body: some View {
        let ringColor = intervalColor(state.currentInterval.type)
        let label = intervalLabel(state.currentInterval.type)
        let progress = 1.0 - Double(state.secondsRemainingInInterval) / Double(state.currentInterval.durationSeconds)

        ProgressView(value: Double(state.intervalIndex), total: Double(state.totalIntervals))

        Spacer()

        IntervalRingView(
            progress: progress.clamped(to: 0...1),
            ringColor: ringColor,
            accessibilityLabel: "Paused: \(label)"
        ) {
            VStack(spacing: 4) {
                Text(label).font(.title3.bold()).foregroundColor(ringColor)
                Text(formatTime(state.secondsRemainingInInterval))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
            }
        }

        Text("PAUSED")
            .font(.headline)
            .foregroundStyle(.secondary)

        Text("Elapsed: \(formatTime(state.elapsedSessionSeconds))").font(.body)

        Spacer()

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
            Text("Time: \(formatTime(elapsedSeconds))").font(.title2.bold())
            if distanceMeters > 0 {
                Text(String(format: "%.2f km", distanceMeters / 1000)).font(.title3)
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
                Text("Previous best: \(formatTime(best.durationSeconds))")
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

private func intervalLabel(_ type: IntervalType) -> String {
    switch type {
    case .run:      return "RUN"
    case .walk:     return "WALK"
    case .warmup:   return "WARM UP"
    case .cooldown: return "COOL DOWN"
    }
}

func formatTime(_ totalSeconds: Int) -> String {
    let m = totalSeconds / 60
    let s = totalSeconds % 60
    return String(format: "%d:%02d", m, s)
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}


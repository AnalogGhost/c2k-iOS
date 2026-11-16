import SwiftUI
import SwiftData

@main
struct CtoKApp: App {
    @State private var prefs: UserPreferences
    private let container: ModelContainer
    // A workout runs in this process, so none can be running at launch: any that never ended
    // was cut off by iOS or a crash. The cutoff keeps a workout started in the next moments out.
    private let launchedAt = Date.now

    init() {
        #if DEBUG
        let screenshotMode = CommandLine.arguments.contains("--screenshot-seed")
        if screenshotMode {
            // Must run before UserPreferences() below reads UserDefaults.
            ScreenshotSeed.applyDefaults()
        }
        #else
        let screenshotMode = false
        #endif

        _prefs = State(initialValue: UserPreferences())

        if screenshotMode {
            #if DEBUG
            container = try! ModelContainer(
                for: WorkoutSession.self, RoutePoint.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            ScreenshotSeed.seedHistory(context: container.mainContext)
            #else
            container = try! ModelContainer(for: WorkoutSession.self, RoutePoint.self)
            #endif
        } else {
            container = try! ModelContainer(for: WorkoutSession.self, RoutePoint.self)
        }
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(prefs)
                .environment(WorkoutManager.shared)
                .task {
                    recoverInterruptedWorkouts()
                    repairGpsDistancesIfNeeded()
                }
        }
        .modelContainer(container)
    }

    @MainActor
    private func recoverInterruptedWorkouts() {
        #if DEBUG
        if CommandLine.arguments.contains("--screenshot-seed") { return }
        #endif
        SessionRepository(context: container.mainContext).recoverInterruptedSessions(startedBefore: launchedAt)
    }

    // One-time cleanup of distances inflated by faulty GPS data recorded before the
    // implied-speed filter existed (issue #30). Flag is set only after a full pass, so an
    // interrupted run simply retries on next launch.
    @MainActor
    private func repairGpsDistancesIfNeeded() {
        #if DEBUG
        if CommandLine.arguments.contains("--screenshot-seed") { return }
        #endif
        guard !prefs.gpsDistancesRecomputed else { return }
        SessionRepository(context: container.mainContext).recomputeSessionDistances()
        prefs.gpsDistancesRecomputed = true
    }
}

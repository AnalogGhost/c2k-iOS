import SwiftUI
import SwiftData

@main
struct CtoKApp: App {
    @State private var prefs = UserPreferences()
    private let container: ModelContainer

    init() {
        #if DEBUG
        if CommandLine.arguments.contains("--screenshot-seed") {
            container = try! ModelContainer(
                for: WorkoutSession.self, RoutePoint.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            ScreenshotSeed.populate(context: container.mainContext)
        } else {
            container = try! ModelContainer(for: WorkoutSession.self, RoutePoint.self)
        }
        #else
        container = try! ModelContainer(for: WorkoutSession.self, RoutePoint.self)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(prefs)
                .environment(WorkoutManager.shared)
                .task { repairGpsDistancesIfNeeded() }
        }
        .modelContainer(container)
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

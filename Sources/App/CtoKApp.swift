import SwiftUI
import SwiftData

@main
struct CtoKApp: App {
    @State private var prefs = UserPreferences()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(prefs)
                .environment(WorkoutManager.shared)
        }
        .modelContainer(for: [WorkoutSession.self, RoutePoint.self])
    }
}

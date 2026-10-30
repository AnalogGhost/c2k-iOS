import XCTest
import SwiftData
@testable import CtoK

@MainActor
final class HapticsSpy: HapticCuePlaying {
    private(set) var played: [HapticCue] = []
    private(set) var started = false
    func configure(strength: VibrationStrength) {}
    func start() { started = true }
    func stop() {}
    func play(_ cue: HapticCue) { played.append(cue) }
}

@MainActor
final class WatchCueSpy: WatchCuePosting {
    private(set) var posted: [String] = []
    private(set) var clears = 0
    func post(_ cue: WatchCue) {
        switch cue {
        case .interval(let interval): posted.append("interval:\(interval.type.rawValue)")
        case .complete:               posted.append("complete")
        }
    }
    func clear() { clears += 1 }
}

// Runs whole (seconds-long) workouts through WorkoutManager — engine, cue player, haptics, watch
// cues and the session store together — so the wiring between them is covered, not just each part.
@MainActor
final class WorkoutManagerTests: XCTestCase {
    // Every preference these tests set, saved and put back so they never leak into other tests.
    private let keys = ["tts_enabled", "gps_enabled", "treadmill_mode", "vibration_enabled", "smartwatch_cues",
                        "cue_style", "countdown_warnings", "keep_screen_on", "skip_warmup", "skip_cooldown"]
    private var saved: [String: Any] = [:]
    private var context: ModelContext!
    private var repo: SessionRepository!
    private var haptics: HapticsSpy!
    private var watch: WatchCueSpy!
    private var manager: WorkoutManager!

    override func setUpWithError() throws {
        for key in keys { saved[key] = UserDefaults.standard.object(forKey: key) }
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: "tts_enabled")      // no speech to wait for
        defaults.set(false, forKey: "gps_enabled")      // no location prompt
        defaults.set(true, forKey: "treadmill_mode")
        defaults.set(false, forKey: "countdown_warnings")
        defaults.set(true, forKey: "vibration_enabled")
        defaults.set(false, forKey: "smartwatch_cues")
        defaults.removeObject(forKey: "cue_style")

        let container = try ModelContainer(for: WorkoutSession.self, RoutePoint.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        context = ModelContext(container)
        repo = SessionRepository(context: context)
        haptics = HapticsSpy()
        watch = WatchCueSpy()
        manager = WorkoutManager(haptics: haptics, watchCues: watch)
    }

    override func tearDown() {
        if manager.isRunning { manager.stop() }
        for key in keys {
            if let value = saved[key] { UserDefaults.standard.set(value, forKey: key) }
            else { UserDefaults.standard.removeObject(forKey: key) }
        }
        super.tearDown()
    }

    private func shortDay(_ types: [IntervalType], seconds: Int = 1) -> WorkoutDay {
        WorkoutDay(week: 1, day: 1, intervals: types.map { Interval(type: $0, durationSeconds: seconds) })
    }

    private func start(_ day: WorkoutDay, prefs: UserPreferences = UserPreferences()) {
        manager.start(programId: Programs.idC25K, week: 1, day: 1, prefs: prefs, repository: repo, workoutDay: day)
    }

    private func waitUntil(timeout: TimeInterval = 10, _ predicate: () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !predicate() && Date() < deadline { try? await Task.sleep(for: .milliseconds(50)) }
    }

    private var sessions: [WorkoutSession] { (try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? [] }

    // MARK: - Completing a workout

    func testAFinishedWorkoutIsSavedAsCompleted() async {
        start(shortDay([.warmup, .run, .cooldown]))
        XCTAssertTrue(manager.isRunning)
        await waitUntil { !manager.isRunning }

        XCTAssertFalse(manager.isRunning)
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.completed, true)
        XCTAssertGreaterThanOrEqual(sessions.first?.durationSeconds ?? 0, 3)
        XCTAssertEqual(repo.completedDays(programId: Programs.idC25K), [WeekDay(week: 1, day: 1)])
    }

    func testThePhoneVibratesAtEachIntervalChangeAndAtTheEnd() async {
        start(shortDay([.warmup, .run, .walk]))
        await waitUntil { !manager.isRunning }

        XCTAssertTrue(haptics.started)
        XCTAssertEqual(haptics.played, [.runIntervalChange, .intervalChange, .workoutComplete])
    }

    func testWatchCuesMirrorThePhoneVibrationsWhenSwitchedOn() async {
        UserDefaults.standard.set(true, forKey: "smartwatch_cues")
        start(shortDay([.warmup, .run, .cooldown]))
        await waitUntil { !manager.isRunning }

        XCTAssertEqual(watch.posted, ["interval:run", "interval:cooldown", "complete"])
        // Cleanup clears the last interval cue before the completion cue is posted, so it stays.
        XCTAssertEqual(watch.clears, 1)
    }

    func testNoWatchCuesWhenTheSwitchIsOff() async {
        start(shortDay([.warmup, .run]))
        await waitUntil { !manager.isRunning }
        XCTAssertEqual(watch.posted, [])
    }

    func testWatchCuesNeedVibrationOn() async {
        UserDefaults.standard.set(true, forKey: "smartwatch_cues")
        UserDefaults.standard.set(false, forKey: "vibration_enabled")
        start(shortDay([.warmup, .run]))
        await waitUntil { !manager.isRunning }
        XCTAssertEqual(watch.posted, [])
        XCTAssertEqual(haptics.played, [])
    }

    func testAWorkoutInTonesModeRunsToCompletion() async {
        UserDefaults.standard.set(true, forKey: "tts_enabled")
        UserDefaults.standard.set(true, forKey: "countdown_warnings")
        UserDefaults.standard.set("TONES", forKey: "cue_style")
        start(shortDay([.warmup, .run, .cooldown]))
        await waitUntil(timeout: 15) { !manager.isRunning }

        XCTAssertFalse(manager.isRunning, "a workout with chimes should still finish and clean up")
        XCTAssertEqual(sessions.first?.completed, true)
    }

    // MARK: - Stopping, pausing and skipping

    func testStoppingEarlySavesAnIncompleteSessionAndClearsTheWatchCue() async {
        UserDefaults.standard.set(true, forKey: "smartwatch_cues")
        start(shortDay([.warmup, .run], seconds: 300))
        await waitUntil { if case .active = manager.workoutState { return true }; return false }

        manager.stop()
        XCTAssertFalse(manager.isRunning)
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.completed, false)
        XCTAssertEqual(watch.clears, 1)
        XCTAssertEqual(watch.posted, [])
    }

    func testPauseHoldsTheIntervalAndResumeCarriesOn() async {
        start(shortDay([.run], seconds: 300))
        await waitUntil { if case .active = manager.workoutState { return true }; return false }

        manager.pause()
        await waitUntil { if case .paused = manager.workoutState { return true }; return false }
        guard case .paused(let atPause) = manager.workoutState else { return XCTFail("expected paused") }
        try? await Task.sleep(for: .milliseconds(1200))
        guard case .paused(let later) = manager.workoutState else { return XCTFail("expected still paused") }
        XCTAssertEqual(atPause.secondsRemainingInInterval, later.secondsRemainingInInterval)

        manager.resume()
        await waitUntil { if case .active = manager.workoutState { return true }; return false }
        guard case .active = manager.workoutState else { return XCTFail("expected active after resume") }
    }

    func testSkippingTheWarmupThroughTheManagerMovesToTheRun() async {
        start(shortDay([.warmup, .run], seconds: 300))
        await waitUntil { if case .active = manager.workoutState { return true }; return false }

        manager.skipWarmupOrCooldown()
        await waitUntil {
            if case .active(let s) = manager.workoutState { return s.currentInterval.type == .run }
            return false
        }
        guard case .active(let s) = manager.workoutState else { return XCTFail("expected active") }
        XCTAssertEqual(s.currentInterval.type, .run)
    }

    func testASecondStartWhileRunningIsIgnored() async {
        start(shortDay([.run], seconds: 300))
        start(shortDay([.walk], seconds: 300))
        await waitUntil { if case .active = manager.workoutState { return true }; return false }

        guard case .active(let s) = manager.workoutState else { return XCTFail("expected active") }
        XCTAssertEqual(s.currentInterval.type, .run)
        XCTAssertEqual(sessions.count, 1)
    }

    func testSkipSettingsShapeTheDayWhenNoOverrideIsGiven() async {
        UserDefaults.standard.set(true, forKey: "skip_warmup")
        manager.start(programId: Programs.idC25K, week: 1, day: 1, prefs: UserPreferences(), repository: repo)
        await waitUntil { if case .active = manager.workoutState { return true }; return false }

        guard case .active(let s) = manager.workoutState else { return XCTFail("expected active") }
        XCTAssertEqual(s.currentInterval.type, .run, "the warm-up should have been skipped")
    }
}

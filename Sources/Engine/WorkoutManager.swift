import Foundation
import UIKit
import Observation

// Central coordinator for an active workout session.
// Equivalent role to the Android WorkoutService foreground service.
@Observable
@MainActor
final class WorkoutManager {
    static let shared = WorkoutManager()

    var workoutState: WorkoutState = .idle
    var isRunning = false
    var distanceMeters: Double = 0
    var hasGpsLock = false
    var gpsActive = false
    var currentWorkoutInfo: (programId: String, week: Int, day: Int)?
    var currentSpeedMps: Float?

    private var engine: WorkoutEngine?
    private var locationTracker: LocationTracker?
    private let ttsManager = TTSManager()
    private let backgroundAudio = BackgroundAudioManager()
    private let nowPlaying = NowPlayingManager()
    private var pollingTask: Task<Void, Never>?
    private var currentSessionId: UUID?
    private var repository: SessionRepository?

    private init() {}

    func start(
        programId: String, week: Int, day: Int,
        prefs: UserPreferences,
        repository: SessionRepository
    ) {
        guard !isRunning else { return }

        let workoutDay = Programs.byId(programId).weeks[week - 1][day - 1]
        self.repository = repository

        isRunning = true
        currentWorkoutInfo = (programId, week, day)
        distanceMeters = 0
        hasGpsLock = false

        backgroundAudio.start()
        ttsManager.setRate(prefs.ttsSpeechRate)
        ttsManager.setVolume(prefs.ttsVolume)

        nowPlaying.onPause = { [weak self] in self?.pause() }
        nowPlaying.onResume = { [weak self] in self?.resume() }
        nowPlaying.onStop = { [weak self] in self?.stop() }
        nowPlaying.start()

        if prefs.gpsEnabled && !prefs.treadmillMode {
            let tracker = LocationTracker()
            locationTracker = tracker
            tracker.onUpdate = { [weak self] update in
                guard let self else { return }
                self.distanceMeters = tracker.totalDistanceMeters
                self.hasGpsLock = tracker.hasGpsLock
                self.currentSpeedMps = update.speedMps
                if case .active = self.workoutState,
                   let sessionId = self.currentSessionId {
                    repository.addRoutePoint(RoutePoint(sessionId: sessionId, update: update))
                }
            }
            tracker.start()
            gpsActive = tracker.isAvailable
        } else {
            gpsActive = false
        }

        let sessionId = repository.startSession(programId: programId, week: week, day: day)
        currentSessionId = sessionId

        let eng = WorkoutEngine(
            day: workoutDay,
            tts: ttsManager,
            ttsEnabled: prefs.ttsEnabled,
            countdownWarnings: prefs.countdownWarnings,
            countdownWarningSeconds1: prefs.countdownWarning1,
            countdownWarningSeconds2: prefs.countdownWarning2,
            midIntervalCues: prefs.midIntervalCues
        )
        engine = eng
        eng.start(sessionId: sessionId)

        startPolling(vibrationEnabled: prefs.vibrationEnabled, repository: repository)
    }

    func pause() {
        engine?.pause()
        locationTracker?.pause()
    }

    func resume() {
        engine?.resume()
        locationTracker?.resume()
    }

    func stop() {
        guard let engine else { cleanup(); return }

        let elapsed: Int
        switch engine.state {
        case .active(let s): elapsed = s.elapsedSessionSeconds
        case .paused(let s): elapsed = s.elapsedSessionSeconds
        default:             elapsed = 0
        }

        engine.stop()

        if let sessionId = currentSessionId {
            let distance = locationTracker?.totalDistanceMeters ?? 0
            repository?.finishSession(id: sessionId, durationSeconds: elapsed,
                                      distanceMeters: distance, completed: false)
        }
        cleanup()
    }

    private func startPolling(vibrationEnabled: Bool, repository: SessionRepository) {
        pollingTask = Task { [weak self] in
            var lastIntervalIndex = -1
            while !Task.isCancelled {
                guard let self, let engine = self.engine else { return }

                let state = engine.state
                self.workoutState = state

                switch state {
                case .active(let s):
                    if s.intervalIndex != lastIntervalIndex && lastIntervalIndex >= 0 && vibrationEnabled {
                        self.vibrateInterval()
                    }
                    lastIntervalIndex = s.intervalIndex
                    self.updateNowPlaying(s, isPlaying: true)

                case .paused(let s):
                    self.updateNowPlaying(s, isPlaying: false)

                case .completed(let sessionId, let elapsed):
                    if vibrationEnabled { self.vibrateCompletion() }
                    let distance = self.locationTracker?.totalDistanceMeters ?? 0
                    repository.finishSession(id: sessionId, durationSeconds: elapsed,
                                             distanceMeters: distance, completed: true)
                    // Let the final "Workout complete" announcement finish speaking before
                    // cleanup() calls ttsManager.shutdown() -> stopSpeaking(.immediate), which
                    // would otherwise cut the cue off. Bounded so a stuck TTS engine can't hang.
                    await self.waitForSpeechToFinish()
                    self.cleanup()
                    return

                default: break
                }

                try? await Task.sleep(for: .milliseconds(200))
            }
        }
    }

    private func updateNowPlaying(_ snapshot: WorkoutState.ActiveSnapshot, isPlaying: Bool) {
        let elapsedInInterval = snapshot.currentInterval.durationSeconds - snapshot.secondsRemainingInInterval
        nowPlaying.update(
            title: intervalLabel(snapshot.currentInterval.type),
            subtitle: String(format: String(localized: "workout_interval_progress"),
                              snapshot.intervalIndex + 1, snapshot.totalIntervals),
            isPlaying: isPlaying,
            elapsedSeconds: Double(max(0, elapsedInInterval)),
            durationSeconds: Double(snapshot.currentInterval.durationSeconds)
        )
    }

    private func waitForSpeechToFinish() async {
        let timeoutMs = 8_000
        let pollMs = 100
        var waitedMs = 0
        while ttsManager.isSpeaking && waitedMs < timeoutMs {
            try? await Task.sleep(for: .milliseconds(pollMs))
            waitedMs += pollMs
        }
    }

    private func cleanup() {
        pollingTask?.cancel()
        pollingTask = nil
        engine?.stop()
        engine = nil
        locationTracker?.stop()
        locationTracker = nil
        ttsManager.shutdown()
        backgroundAudio.stop()
        nowPlaying.stop()
        UIApplication.shared.isIdleTimerDisabled = false
        isRunning = false
        currentWorkoutInfo = nil
        currentSessionId = nil
        currentSpeedMps = nil
        repository = nil
    }

    // MARK: - Haptics

    private func vibrateInterval() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    private func vibrateCompletion() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            generator.notificationOccurred(.success)
        }
    }
}

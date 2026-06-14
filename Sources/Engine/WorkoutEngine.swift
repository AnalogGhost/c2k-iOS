import Foundation
import Observation

@Observable
@MainActor
final class WorkoutEngine {
    var state: WorkoutState = .idle

    private let day: WorkoutDay
    private let tts: TTSManager
    private let ttsEnabled: Bool
    private let countdownWarnings: Bool

    private var timerTask: Task<Void, Never>?
    private var sessionId: UUID = UUID()
    private var sessionStartTime: Date = .now
    private var intervalStartTime: Date = .now
    private var pausedAt: Date?
    private var isPaused = false
    private var intervalIndex = 0
    private var warnedCountdowns: Set<Int> = []

    init(day: WorkoutDay, tts: TTSManager, ttsEnabled: Bool, countdownWarnings: Bool) {
        self.day = day
        self.tts = tts
        self.ttsEnabled = ttsEnabled
        self.countdownWarnings = countdownWarnings
    }

    func start(sessionId: UUID) {
        self.sessionId = sessionId
        intervalIndex = 0
        let now = Date.now
        sessionStartTime = now
        intervalStartTime = now
        isPaused = false
        warnedCountdowns.removeAll()
        announceInterval(at: intervalIndex)
        timerTask = Task { await runLoop() }
    }

    func pause() {
        guard !isPaused, case .active(let snapshot) = state else { return }
        isPaused = true
        pausedAt = .now
        state = .paused(snapshot: snapshot)
    }

    func resume() {
        guard isPaused, let pausedAt, case .paused(let snapshot) = state else { return }
        let pauseDuration = Date.now.timeIntervalSince(pausedAt)
        // Move reference times forward so elapsed time doesn't include the pause
        sessionStartTime = sessionStartTime.addingTimeInterval(pauseDuration)
        intervalStartTime = intervalStartTime.addingTimeInterval(pauseDuration)
        self.pausedAt = nil
        isPaused = false
        state = .active(snapshot)
    }

    func stop() {
        timerTask?.cancel()
        timerTask = nil
        // Does not emit .idle — callers handle cleanup directly
    }

    private func runLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { break }
            guard !isPaused else { continue }

            let now = Date.now
            let sessionElapsed = Int(now.timeIntervalSince(sessionStartTime))
            let intervalElapsed = Int(now.timeIntervalSince(intervalStartTime))
            let currentInterval = day.intervals[intervalIndex]
            let remaining = currentInterval.durationSeconds - intervalElapsed

            if remaining <= 0 {
                intervalIndex += 1
                if intervalIndex >= day.intervals.count {
                    if ttsEnabled { tts.announce(.workoutComplete) }
                    state = .completed(sessionId: sessionId, elapsedSessionSeconds: sessionElapsed)
                    return
                }
                intervalStartTime = now
                warnedCountdowns.removeAll()
                announceInterval(at: intervalIndex)
                continue
            }

            if countdownWarnings && ttsEnabled && !warnedCountdowns.contains(remaining) {
                if remaining == 10 {
                    warnedCountdowns.insert(10)
                    tts.announce(.countdownWarning(10))
                } else if remaining == 5 {
                    warnedCountdowns.insert(5)
                    tts.announce(.countdownWarning(5))
                    if intervalIndex + 1 < day.intervals.count {
                        tts.announce(.nextInterval(day.intervals[intervalIndex + 1]), queueAdd: true)
                    }
                }
            }

            state = .active(.init(
                currentInterval: day.intervals[intervalIndex],
                nextInterval: day.intervals[safe: intervalIndex + 1],
                intervalIndex: intervalIndex,
                totalIntervals: day.intervals.count,
                secondsRemainingInInterval: remaining,
                elapsedSessionSeconds: sessionElapsed,
                sessionId: sessionId
            ))
        }
    }

    private func announceInterval(at index: Int) {
        guard ttsEnabled else { return }
        tts.announce(.intervalStart(day.intervals[index]))
        guard index > 0 else { return }

        let isLastRun = day.intervals[index].type == .run &&
            !day.intervals.dropFirst(index + 1).contains(where: { $0.type == .run })
        if isLastRun {
            tts.announce(.lastRunInterval, queueAdd: true)
            return
        }
        if index == day.intervals.count / 2 {
            tts.announce(.halfway, queueAdd: true)
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

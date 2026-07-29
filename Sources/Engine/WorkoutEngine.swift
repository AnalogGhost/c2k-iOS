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
    private let midIntervalCues: Bool
    // Sorted descending, deduped: fires the larger threshold first, and the smallest one carries
    // the next-interval look-ahead announcement since it's the last warning before the interval ends.
    private let warningThresholds: [Int]

    private var timerTask: Task<Void, Never>?
    private var sessionId: UUID = UUID()
    private var sessionStartTime: Date = .now
    private var intervalStartTime: Date = .now
    private var pausedAt: Date?
    private var isPaused = false
    private var intervalIndex = 0
    private var warnedCountdowns: Set<Int> = []
    private var midpointAnnounced = false

    init(
        day: WorkoutDay, tts: TTSManager, ttsEnabled: Bool, countdownWarnings: Bool,
        countdownWarningSeconds1: Int = 10, countdownWarningSeconds2: Int = 5,
        midIntervalCues: Bool = true
    ) {
        self.day = day
        self.tts = tts
        self.ttsEnabled = ttsEnabled
        self.countdownWarnings = countdownWarnings
        self.midIntervalCues = midIntervalCues
        self.warningThresholds = Array(Set([countdownWarningSeconds1, countdownWarningSeconds2].filter { $0 > 0 }))
            .sorted(by: >)
    }

    func start(sessionId: UUID) {
        self.sessionId = sessionId
        intervalIndex = 0
        let now = Date.now
        sessionStartTime = now
        intervalStartTime = now
        isPaused = false
        warnedCountdowns.removeAll()
        midpointAnnounced = false
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
                let finishedInterval = day.intervals[intervalIndex]
                intervalIndex += 1
                if intervalIndex >= day.intervals.count {
                    // Pin a final Active frame to 0 before completing. If the screen locks, a
                    // suspended lifecycle-aware observer would otherwise freeze on the last
                    // Active value it received (1-3s left) even though the workout is done.
                    state = .active(.init(
                        currentInterval: finishedInterval,
                        nextInterval: nil,
                        intervalIndex: intervalIndex - 1,
                        totalIntervals: day.intervals.count,
                        secondsRemainingInInterval: 0,
                        elapsedSessionSeconds: sessionElapsed,
                        sessionId: sessionId
                    ))
                    if ttsEnabled { tts.announce(.workoutComplete) }
                    state = .completed(sessionId: sessionId, elapsedSessionSeconds: sessionElapsed)
                    return
                }
                intervalStartTime = now
                warnedCountdowns.removeAll()
                midpointAnnounced = false
                announceInterval(at: intervalIndex)
                continue
            }

            if countdownWarnings && ttsEnabled &&
                warningThresholds.contains(remaining) && !warnedCountdowns.contains(remaining) {
                warnedCountdowns.insert(remaining)
                tts.announce(.countdownWarning(remaining))
                if remaining == warningThresholds.last {
                    // Look-ahead: the smallest threshold is the last warning before the interval
                    // ends, so it also announces what's coming next.
                    if intervalIndex + 1 < day.intervals.count {
                        tts.announce(.nextInterval(day.intervals[intervalIndex + 1]), queueAdd: true)
                    }
                }
            }

            if midIntervalCues && ttsEnabled &&
                currentInterval.type == .run &&
                currentInterval.durationSeconds >= 60 &&
                intervalElapsed >= currentInterval.durationSeconds / 2 &&
                !midpointAnnounced {
                midpointAnnounced = true
                tts.announce(.intervalMidpoint(phraseIndex: intervalIndex), queueAdd: true)
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

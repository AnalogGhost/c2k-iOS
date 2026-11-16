import Foundation
import Observation

/// The countdown warnings that fire before each interval ends, in seconds remaining, sorted
/// descending and deduped so the larger threshold fires first. With the second warning off, the
/// first warning is the only (and therefore last) one. Shared with Tones mode so the engine and
/// the chimes agree on which warning comes second.
func countdownWarningThresholds(_ warningSeconds1: Int, _ warningSeconds2: Int, warning2Enabled: Bool) -> [Int] {
    let thresholds = [warningSeconds1] + (warning2Enabled ? [warningSeconds2] : [])
    return Array(Set(thresholds.filter { $0 > 0 })).sorted(by: >)
}

@Observable
@MainActor
final class WorkoutEngine {
    var state: WorkoutState = .idle

    private let day: WorkoutDay
    private let tts: any TTSAnnouncing
    private let ttsEnabled: Bool
    private let countdownWarnings: Bool
    private let midIntervalCues: Bool
    private let periodicTimeCues: Bool
    private let periodicTimeCueIntervalSeconds: Int
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
    private var lastPeriodicCueElapsed = -1
    // Set by skipWarmupOrCooldown(), consumed by the run loop.
    private var skipRequested = false
    private let clock: () -> Date

    // Up to this much lateness at an interval change is taken from the next interval.
    private static let maxCarriedOvershoot: TimeInterval = 1

    init(
        day: WorkoutDay, tts: any TTSAnnouncing, ttsEnabled: Bool, countdownWarnings: Bool,
        countdownWarningSeconds1: Int = 10, countdownWarningSeconds2: Int = 5,
        countdownWarning2Enabled: Bool = true,
        midIntervalCues: Bool = true,
        periodicTimeCues: Bool = false, periodicTimeCueIntervalSeconds: Int = 30,
        clock: @escaping () -> Date = { .now }
    ) {
        self.clock = clock
        self.day = day
        self.tts = tts
        self.ttsEnabled = ttsEnabled
        self.countdownWarnings = countdownWarnings
        self.midIntervalCues = midIntervalCues
        self.periodicTimeCues = periodicTimeCues
        self.periodicTimeCueIntervalSeconds = periodicTimeCueIntervalSeconds
        self.warningThresholds = countdownWarningThresholds(
            countdownWarningSeconds1, countdownWarningSeconds2, warning2Enabled: countdownWarning2Enabled)
    }

    func start(sessionId: UUID) {
        self.sessionId = sessionId
        intervalIndex = 0
        let now = clock()
        sessionStartTime = now
        intervalStartTime = now
        isPaused = false
        warnedCountdowns.removeAll()
        midpointAnnounced = false
        lastPeriodicCueElapsed = -1
        skipRequested = false
        announceInterval(at: intervalIndex)
        timerTask = Task { await runLoop() }
    }

    func pause() {
        guard !isPaused, case .active(let snapshot) = state else { return }
        isPaused = true
        pausedAt = clock()
        state = .paused(snapshot: snapshot)
    }

    func resume() {
        guard isPaused, let pausedAt, case .paused(let snapshot) = state else { return }
        let pauseDuration = clock().timeIntervalSince(pausedAt)
        // Move reference times forward so elapsed time doesn't include the pause
        sessionStartTime = sessionStartTime.addingTimeInterval(pauseDuration)
        intervalStartTime = intervalStartTime.addingTimeInterval(pauseDuration)
        self.pausedAt = nil
        isPaused = false
        state = .active(snapshot)
    }

    /// Ends the current warm-up or cool-down early; ignored while paused and during any other
    /// interval. Only raises a flag, which the run loop applies on its next tick, so a request
    /// landing just as an interval changes naturally can't cut the following interval short.
    func skipWarmupOrCooldown() {
        if !isPaused { skipRequested = true }
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
            guard tick(now: clock()) else { return }
        }
    }

    /// One pass of the run loop at `now`. Returns false once the workout has completed.
    /// Internal so tests can drive the engine on a virtual clock.
    @discardableResult
    func tick(now: Date) -> Bool {
        guard !isPaused else { return true }
        if case .completed = state { return false }
        if skipRequested {
            skipRequested = false
            let skippable = day.intervals[intervalIndex]
            if skippable.type == .warmup || skippable.type == .cooldown {
                // Backdate the interval start so the normal end-of-interval path below runs:
                // announcement and warning reset, or completion for a final cool-down.
                intervalStartTime = now.addingTimeInterval(-Double(skippable.durationSeconds))
            }
        }
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
                    remainingRunIntervals: remainingRunIntervals(from: intervalIndex - 1),
                    secondsRemainingInInterval: 0,
                    elapsedSessionSeconds: sessionElapsed,
                    sessionId: sessionId
                ))
                if ttsEnabled { tts.announce(.workoutComplete) }
                state = .completed(sessionId: sessionId, elapsedSessionSeconds: sessionElapsed)
                return false
            }
            // Start the next interval at the boundary, not at this tick, so the few milliseconds
            // each tick lands late don't add up over a workout (about 2 s on a 30-minute one).
            // After a longer stall (the phone briefly frozen), start it now instead: the runner
            // hears the cue late but still gets the whole interval.
            let boundary = intervalStartTime.addingTimeInterval(Double(finishedInterval.durationSeconds))
            intervalStartTime = now.timeIntervalSince(boundary) <= Self.maxCarriedOvershoot ? boundary : now
            warnedCountdowns.removeAll()
            midpointAnnounced = false
            lastPeriodicCueElapsed = -1
            announceInterval(at: intervalIndex)
            return true
        }

        // A threshold equal to the interval's length would fire on the first tick and flush
        // the interval-start cue (warnings don't queue), so only warn once time has passed.
        if countdownWarnings && ttsEnabled && remaining < currentInterval.durationSeconds &&
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

        if periodicTimeCues && ttsEnabled && periodicTimeCueIntervalSeconds > 0 &&
            intervalElapsed > 0 && intervalElapsed % periodicTimeCueIntervalSeconds == 0 &&
            intervalElapsed != lastPeriodicCueElapsed {
            lastPeriodicCueElapsed = intervalElapsed
            tts.announce(.periodicTimeRemaining(remaining), queueAdd: true)
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
            remainingRunIntervals: remainingRunIntervals(from: intervalIndex),
            secondsRemainingInInterval: remaining,
            elapsedSessionSeconds: sessionElapsed,
            sessionId: sessionId
        ))
        return true
    }

    // Counts the current interval too, so the figure only drops once a run has finished.
    private func remainingRunIntervals(from index: Int) -> Int {
        day.intervals.dropFirst(index).filter { $0.type == .run }.count
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

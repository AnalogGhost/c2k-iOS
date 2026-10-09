import XCTest
@testable import CtoK

// Records every announcement WorkoutEngine sends, keyed by a lightweight comparable
// projection of TTSManager.Announcement (which isn't itself Equatable).
enum AnnouncementKind: Equatable {
    case intervalStart(IntervalType, Int)
    case workoutComplete
    case countdownWarning(Int)
    case nextInterval(IntervalType)
    case lastRunInterval
    case halfway
    case intervalMidpoint(Int)
    case periodicTimeRemaining(Int)
}

@MainActor
final class TTSSpy: TTSAnnouncing {
    private(set) var calls: [(kind: AnnouncementKind, queueAdd: Bool)] = []

    func announce(_ announcement: TTSManager.Announcement, queueAdd: Bool) {
        let kind: AnnouncementKind
        switch announcement {
        case .intervalStart(let interval): kind = .intervalStart(interval.type, interval.durationSeconds)
        case .workoutComplete: kind = .workoutComplete
        case .countdownWarning(let seconds): kind = .countdownWarning(seconds)
        case .nextInterval(let interval): kind = .nextInterval(interval.type)
        case .lastRunInterval: kind = .lastRunInterval
        case .halfway: kind = .halfway
        case .intervalMidpoint(let phraseIndex): kind = .intervalMidpoint(phraseIndex)
        case .periodicTimeRemaining(let seconds): kind = .periodicTimeRemaining(seconds)
        }
        calls.append((kind, queueAdd))
    }

    func count(_ kind: AnnouncementKind) -> Int {
        calls.filter { $0.kind == kind }.count
    }
}

@MainActor
final class WorkoutEngineTests: XCTestCase {

    private func waitUntil(timeout: TimeInterval = 4.0, _ predicate: () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !predicate() && Date() < deadline {
            try? await Task.sleep(for: .milliseconds(50))
        }
    }

    private func makeEngine(
        intervals: [Interval], tts: TTSSpy, ttsEnabled: Bool = true,
        countdownWarnings: Bool = false, warning1: Int = 10, warning2: Int = 5,
        midIntervalCues: Bool = false,
        periodicTimeCues: Bool = false, periodicTimeCueInterval: Int = 30
    ) -> WorkoutEngine {
        let day = WorkoutDay(week: 1, day: 1, intervals: intervals)
        return WorkoutEngine(
            day: day, tts: tts, ttsEnabled: ttsEnabled, countdownWarnings: countdownWarnings,
            countdownWarningSeconds1: warning1, countdownWarningSeconds2: warning2,
            midIntervalCues: midIntervalCues,
            periodicTimeCues: periodicTimeCues, periodicTimeCueIntervalSeconds: periodicTimeCueInterval
        )
    }

    private func periodicCueCount(_ spy: TTSSpy) -> Int {
        spy.calls.filter { if case .periodicTimeRemaining = $0.kind { return true }; return false }.count
    }

    func testStartAnnouncesFirstIntervalImmediately() {
        let spy = TTSSpy()
        let engine = makeEngine(intervals: [Interval(type: .warmup, durationSeconds: 5)], tts: spy)
        engine.start(sessionId: UUID())
        XCTAssertEqual(spy.count(.intervalStart(.warmup, 5)), 1)
        engine.stop()
    }

    func testStartOnFirstIntervalDoesNotAnnounceHalfwayOrLastRun() {
        let spy = TTSSpy()
        let engine = makeEngine(intervals: [
            Interval(type: .warmup, durationSeconds: 5), Interval(type: .run, durationSeconds: 5),
        ], tts: spy)
        engine.start(sessionId: UUID())
        XCTAssertEqual(spy.count(.halfway), 0)
        XCTAssertEqual(spy.count(.lastRunInterval), 0)
        engine.stop()
    }

    func testPauseFreezesRemainingTime() async {
        let spy = TTSSpy()
        let engine = makeEngine(intervals: [Interval(type: .run, durationSeconds: 10)], tts: spy)
        engine.start(sessionId: UUID())

        await waitUntil { if case .active = engine.state { return true }; return false }
        engine.pause()
        guard case .paused(let snapshotAtPause) = engine.state else {
            XCTFail("expected paused state"); return
        }

        try? await Task.sleep(for: .milliseconds(600))
        guard case .paused(let snapshotAfterWait) = engine.state else {
            XCTFail("expected still paused"); return
        }
        XCTAssertEqual(snapshotAtPause.secondsRemainingInInterval, snapshotAfterWait.secondsRemainingInInterval)
        engine.stop()
    }

    func testResumeContinuesAfterPause() async {
        let spy = TTSSpy()
        let engine = makeEngine(intervals: [Interval(type: .run, durationSeconds: 10)], tts: spy)
        engine.start(sessionId: UUID())

        await waitUntil { if case .active = engine.state { return true }; return false }
        engine.pause()
        try? await Task.sleep(for: .milliseconds(300))
        engine.resume()

        guard case .active = engine.state else { XCTFail("expected active immediately after resume"); return }

        await waitUntil(timeout: 2) {
            guard case .active(let s) = engine.state else { return false }
            return s.secondsRemainingInInterval < 10
        }
        guard case .active(let s) = engine.state else { XCTFail("expected still active"); return }
        XCTAssertLessThan(s.secondsRemainingInInterval, 10)
        engine.stop()
    }

    func testFullDayReachesCompletedAndAnnouncesWorkoutComplete() async {
        let spy = TTSSpy()
        let engine = makeEngine(intervals: [
            Interval(type: .warmup, durationSeconds: 1),
            Interval(type: .run, durationSeconds: 1),
            Interval(type: .cooldown, durationSeconds: 1),
        ], tts: spy)
        let sessionId = UUID()
        engine.start(sessionId: sessionId)

        await waitUntil(timeout: 6) {
            if case .completed = engine.state { return true }; return false
        }

        guard case .completed(let completedId, let elapsed) = engine.state else {
            XCTFail("workout should have completed"); return
        }
        XCTAssertEqual(completedId, sessionId)
        XCTAssertGreaterThanOrEqual(elapsed, 3)
        XCTAssertEqual(spy.count(.workoutComplete), 1)
    }

    func testLastRunIntervalIsAnnouncedForFinalRunInterval() async {
        let spy = TTSSpy()
        let engine = makeEngine(intervals: [
            Interval(type: .warmup, durationSeconds: 1),
            Interval(type: .run, durationSeconds: 1),
            Interval(type: .cooldown, durationSeconds: 1),
        ], tts: spy)
        engine.start(sessionId: UUID())

        await waitUntil(timeout: 6) {
            if case .completed = engine.state { return true }; return false
        }
        // The run interval (index 1) is the last RUN interval in the day, so starting it
        // should have queued a "last run" announcement rather than a halfway one.
        XCTAssertEqual(spy.count(.lastRunInterval), 1)
        XCTAssertEqual(spy.count(.halfway), 0)
    }

    func testCountdownWarningFiresOncePerThresholdWithLookahead() async {
        let spy = TTSSpy()
        let engine = makeEngine(intervals: [
            Interval(type: .run, durationSeconds: 3),
            Interval(type: .walk, durationSeconds: 3),
        ], tts: spy, countdownWarnings: true, warning1: 2, warning2: 1)
        engine.start(sessionId: UUID())

        await waitUntil(timeout: 5) {
            guard case .active(let s) = engine.state else { return false }
            return s.intervalIndex == 1
        }

        XCTAssertEqual(spy.count(.countdownWarning(2)), 1)
        XCTAssertEqual(spy.count(.countdownWarning(1)), 1)
        // The smallest threshold (1s) carries the next-interval look-ahead announcement.
        XCTAssertEqual(spy.count(.nextInterval(.walk)), 1)
        engine.stop()
    }

    func testCountdownWarningsAreDisabledWhenToggledOff() async {
        let spy = TTSSpy()
        let engine = makeEngine(
            intervals: [Interval(type: .run, durationSeconds: 3)], tts: spy,
            countdownWarnings: false, warning1: 2, warning2: 1
        )
        engine.start(sessionId: UUID())

        try? await Task.sleep(for: .milliseconds(3500))
        XCTAssertEqual(spy.count(.countdownWarning(2)), 0)
        XCTAssertEqual(spy.count(.countdownWarning(1)), 0)
        engine.stop()
    }

    func testRemainingRunIntervalsCountsAllRunsFromTheStart() async {
        let spy = TTSSpy()
        let engine = makeEngine(intervals: [
            Interval(type: .warmup, durationSeconds: 5),
            Interval(type: .run, durationSeconds: 10),
            Interval(type: .walk, durationSeconds: 10),
            Interval(type: .run, durationSeconds: 10),
            Interval(type: .cooldown, durationSeconds: 5),
        ], tts: spy)
        engine.start(sessionId: UUID())

        await waitUntil { if case .active = engine.state { return true }; return false }
        guard case .active(let s) = engine.state else { XCTFail("expected active state"); return }
        XCTAssertEqual(s.remainingRunIntervals, 2, "Should count both run intervals before any has started")
        engine.stop()
    }

    func testRemainingRunIntervalsDecrementsOnlyAfterARunCompletes() async {
        let spy = TTSSpy()
        let engine = makeEngine(intervals: [
            Interval(type: .run, durationSeconds: 2),
            Interval(type: .walk, durationSeconds: 2),
            Interval(type: .run, durationSeconds: 2),
        ], tts: spy)
        engine.start(sessionId: UUID())

        func snapshot(atIndex index: Int) async -> WorkoutState.ActiveSnapshot? {
            await waitUntil(timeout: 6) {
                guard case .active(let s) = engine.state else { return false }
                return s.intervalIndex == index
            }
            guard case .active(let s) = engine.state, s.intervalIndex == index else { return nil }
            return s
        }

        let firstRun = await snapshot(atIndex: 0)
        XCTAssertEqual(firstRun?.remainingRunIntervals, 2)

        let walk = await snapshot(atIndex: 1)
        XCTAssertEqual(walk?.remainingRunIntervals, 1, "A completed run should no longer be counted")

        let secondRun = await snapshot(atIndex: 2)
        XCTAssertEqual(secondRun?.remainingRunIntervals, 1, "The currently active run should still count as remaining")
        engine.stop()
    }

    func testRemainingRunIntervalsIsZeroWhenNoRunsInWorkout() async {
        let spy = TTSSpy()
        let engine = makeEngine(intervals: [
            Interval(type: .warmup, durationSeconds: 5), Interval(type: .cooldown, durationSeconds: 5),
        ], tts: spy)
        engine.start(sessionId: UUID())

        await waitUntil { if case .active = engine.state { return true }; return false }
        guard case .active(let s) = engine.state else { XCTFail("expected active state"); return }
        XCTAssertEqual(s.remainingRunIntervals, 0)
        engine.stop()
    }

    func testPeriodicTimeCuesFireOncePerCadenceMark() async {
        let spy = TTSSpy()
        let engine = makeEngine(
            intervals: [Interval(type: .run, durationSeconds: 4)], tts: spy,
            periodicTimeCues: true, periodicTimeCueInterval: 2
        )
        engine.start(sessionId: UUID())

        // Several 200ms ticks land on the 2s-elapsed mark; only the first may announce.
        await waitUntil(timeout: 6) { if case .completed = engine.state { return true }; return false }
        XCTAssertEqual(spy.count(.periodicTimeRemaining(2)), 1)
        XCTAssertEqual(periodicCueCount(spy), 1)
        XCTAssertEqual(spy.calls.first { $0.kind == .periodicTimeRemaining(2) }?.queueAdd, true)
    }

    func testPeriodicTimeCuesDoNotFireWhenDisabled() async {
        let spy = TTSSpy()
        let engine = makeEngine(
            intervals: [Interval(type: .run, durationSeconds: 3)], tts: spy,
            periodicTimeCues: false, periodicTimeCueInterval: 1
        )
        engine.start(sessionId: UUID())

        await waitUntil(timeout: 5) { if case .completed = engine.state { return true }; return false }
        XCTAssertEqual(periodicCueCount(spy), 0)
    }

    func testPeriodicTimeCuesResetPerInterval() async {
        let spy = TTSSpy()
        let engine = makeEngine(intervals: [
            Interval(type: .run, durationSeconds: 3),
            Interval(type: .walk, durationSeconds: 3),
        ], tts: spy, periodicTimeCues: true, periodicTimeCueInterval: 2)
        engine.start(sessionId: UUID())

        // The 2s-elapsed mark is crossed once in each interval.
        await waitUntil(timeout: 8) { if case .completed = engine.state { return true }; return false }
        XCTAssertEqual(spy.count(.periodicTimeRemaining(1)), 2)
        XCTAssertEqual(periodicCueCount(spy), 2)
    }

    func testPeriodicTimeCuesAreSilentWhenVoiceIsDisabled() async {
        let spy = TTSSpy()
        let engine = makeEngine(
            intervals: [Interval(type: .run, durationSeconds: 3)], tts: spy, ttsEnabled: false,
            periodicTimeCues: true, periodicTimeCueInterval: 1
        )
        engine.start(sessionId: UUID())

        await waitUntil(timeout: 5) { if case .completed = engine.state { return true }; return false }
        XCTAssertTrue(spy.calls.isEmpty)
    }

    func testPeriodicTimeCuesWithANonPositiveCadenceNeverFireOrCrash() async {
        // A zero cadence would be a modulo-by-zero in the tick loop if it weren't guarded.
        for cadence in [0, -5] {
            let spy = TTSSpy()
            let engine = makeEngine(
                intervals: [Interval(type: .run, durationSeconds: 2)], tts: spy,
                periodicTimeCues: true, periodicTimeCueInterval: cadence
            )
            engine.start(sessionId: UUID())

            await waitUntil(timeout: 4) { if case .completed = engine.state { return true }; return false }
            guard case .completed = engine.state else { XCTFail("workout should have completed"); return }
            XCTAssertEqual(periodicCueCount(spy), 0)
        }
    }

    func testPeriodicTimeCueNeverAnnouncesZeroRemainingAtTheEndOfAnInterval() async {
        // The interval length is a multiple of the cadence, so the last mark coincides with
        // the interval ending — that tick must roll over to the next interval, not speak.
        let spy = TTSSpy()
        let engine = makeEngine(intervals: [
            Interval(type: .run, durationSeconds: 2),
            Interval(type: .walk, durationSeconds: 2),
        ], tts: spy, periodicTimeCues: true, periodicTimeCueInterval: 1)
        engine.start(sessionId: UUID())

        await waitUntil(timeout: 6) { if case .completed = engine.state { return true }; return false }
        XCTAssertEqual(spy.count(.periodicTimeRemaining(0)), 0)
        XCTAssertEqual(spy.count(.periodicTimeRemaining(1)), 2)
        XCTAssertEqual(periodicCueCount(spy), 2)
    }

    func testPeriodicTimeCuesDoNotFireWhilePaused() async {
        let spy = TTSSpy()
        let engine = makeEngine(
            intervals: [Interval(type: .run, durationSeconds: 10)], tts: spy,
            periodicTimeCues: true, periodicTimeCueInterval: 1
        )
        engine.start(sessionId: UUID())

        await waitUntil { self.periodicCueCount(spy) >= 1 }
        engine.pause()
        let countAtPause = periodicCueCount(spy)
        XCTAssertGreaterThanOrEqual(countAtPause, 1)

        try? await Task.sleep(for: .milliseconds(2500))
        XCTAssertEqual(periodicCueCount(spy), countAtPause, "No reminders while paused")

        engine.resume()
        await waitUntil { self.periodicCueCount(spy) > countAtPause }
        XCTAssertGreaterThan(periodicCueCount(spy), countAtPause, "Reminders pick up again after resume")
        engine.stop()
    }

    func testPeriodicTimeCueIsQueuedBehindACountdownWarningOnTheSameTick() async {
        // At 2s elapsed of a 4s interval both the countdown warning (2s left) and the periodic
        // reminder are due. The warning flushes the queue, so the reminder has to be added
        // after it or it would be cut off.
        let spy = TTSSpy()
        let engine = makeEngine(
            intervals: [Interval(type: .run, durationSeconds: 4)], tts: spy,
            countdownWarnings: true, warning1: 2, warning2: 2,
            periodicTimeCues: true, periodicTimeCueInterval: 2
        )
        engine.start(sessionId: UUID())

        await waitUntil(timeout: 6) { if case .completed = engine.state { return true }; return false }
        let warningIdx = spy.calls.firstIndex { $0.kind == .countdownWarning(2) }
        let cueIdx = spy.calls.firstIndex { $0.kind == .periodicTimeRemaining(2) }
        guard let warningIdx, let cueIdx else { XCTFail("expected both announcements"); return }
        XCTAssertLessThan(warningIdx, cueIdx)
        XCTAssertFalse(spy.calls[warningIdx].queueAdd)
        XCTAssertTrue(spy.calls[cueIdx].queueAdd)
    }

    func testPeriodicTimeCuesAreIndependentOfMidRunEncouragement() async {
        let spy = TTSSpy()
        let engine = makeEngine(
            intervals: [Interval(type: .walk, durationSeconds: 3)], tts: spy,
            midIntervalCues: false, periodicTimeCues: true, periodicTimeCueInterval: 2
        )
        engine.start(sessionId: UUID())

        // Fires on walk intervals too, not just runs.
        await waitUntil(timeout: 5) { if case .completed = engine.state { return true }; return false }
        XCTAssertEqual(spy.count(.periodicTimeRemaining(1)), 1)
    }

    func testRemainingRunIntervalsIsCarriedIntoThePausedSnapshot() async {
        let spy = TTSSpy()
        let engine = makeEngine(intervals: [
            Interval(type: .run, durationSeconds: 10), Interval(type: .run, durationSeconds: 10),
        ], tts: spy)
        engine.start(sessionId: UUID())

        await waitUntil { if case .active = engine.state { return true }; return false }
        engine.pause()
        guard case .paused(let s) = engine.state else { XCTFail("expected paused state"); return }
        XCTAssertEqual(s.remainingRunIntervals, 2)
        engine.stop()
    }
}

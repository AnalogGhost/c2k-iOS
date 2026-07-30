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
        intervals: [Interval], tts: TTSSpy,
        countdownWarnings: Bool = false, warning1: Int = 10, warning2: Int = 5,
        midIntervalCues: Bool = false
    ) -> WorkoutEngine {
        let day = WorkoutDay(week: 1, day: 1, intervals: intervals)
        return WorkoutEngine(
            day: day, tts: tts, ttsEnabled: true, countdownWarnings: countdownWarnings,
            countdownWarningSeconds1: warning1, countdownWarningSeconds2: warning2,
            midIntervalCues: midIntervalCues
        )
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
}

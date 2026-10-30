import XCTest
@testable import CtoK

final class WatchCueTests: XCTestCase {
    func testAnIntervalCueNamesTheIntervalAndItsLength() {
        let cue = WatchCue.interval(Interval(type: .run, durationSeconds: 90))
        XCTAssertEqual(cue.title, intervalLabel(.run))
        XCTAssertEqual(cue.body, formatTime(90))
    }

    func testTheCompletionCueSaysTheWorkoutIsDone() {
        XCTAssertEqual(WatchCue.complete.title, String(localized: "Workout Complete!"))
        XCTAssertFalse(WatchCue.complete.body.isEmpty)
    }
}

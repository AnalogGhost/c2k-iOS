import XCTest
@testable import CtoK

// Ported from the Android app's SplitCueTrackerTest, CueTextTest and DistanceCuesActiveTest.
final class SplitCueTrackerTests: XCTestCase {

    private func split(_ cue: TTSManager.Announcement?) -> (meters: Int, pace: Int?)? {
        guard case .distanceSplit(let meters, let pace)? = cue else { return nil }
        return (meters, pace)
    }

    func testAnnouncesOnceEachSplitIsPassed() {
        var tracker = SplitCueTracker(splitMeters: 1000)
        XCTAssertNil(tracker.onProgress(totalMeters: 999, elapsedSeconds: 399))
        XCTAssertEqual(split(tracker.onProgress(totalMeters: 1003, elapsedSeconds: 400))?.meters, 1000)
        XCTAssertNil(tracker.onProgress(totalMeters: 1500, elapsedSeconds: 600))
        XCTAssertEqual(split(tracker.onProgress(totalMeters: 2001, elapsedSeconds: 820))?.meters, 2000)
    }

    func testPaceIsAveragedOverTheSplitJustFinished() {
        var tracker = SplitCueTracker(splitMeters: 500)
        XCTAssertEqual(split(tracker.onProgress(totalMeters: 500, elapsedSeconds: 200))?.pace, 400)
        // The second 500 m took 150 s: 5:00/km, not the 5:50/km average since the start.
        XCTAssertEqual(split(tracker.onProgress(totalMeters: 1000, elapsedSeconds: 350))?.pace, 300)
    }

    func testAJumpPastSeveralSplitsAnnouncesOnlyTheLatest() {
        var tracker = SplitCueTracker(splitMeters: 500)
        let cue = split(tracker.onProgress(totalMeters: 1600, elapsedSeconds: 600))
        XCTAssertEqual(cue?.meters, 1500)
        XCTAssertEqual(cue?.pace, 400)
        XCTAssertNil(tracker.onProgress(totalMeters: 1700, elapsedSeconds: 640))
    }

    func testAnImplausiblePaceIsLeftOut() {
        var fast = SplitCueTracker(splitMeters: 1000)
        let glitch = split(fast.onProgress(totalMeters: 1000, elapsedSeconds: 90))   // 1:30/km
        XCTAssertEqual(glitch?.meters, 1000)
        XCTAssertNil(glitch?.pace)

        var slow = SplitCueTracker(splitMeters: 500)
        XCTAssertNil(split(slow.onProgress(totalMeters: 500, elapsedSeconds: 1000))?.pace)   // 33:20/km
    }

    func testOnlyActiveWithSpokenCuesAndGpsTracking() {
        XCTAssertTrue(SplitCueTracker.isActive(ttsEnabled: true, cueStyle: .voice, distanceCues: true, gpsTracking: true))
        XCTAssertFalse(SplitCueTracker.isActive(ttsEnabled: true, cueStyle: .tones, distanceCues: true, gpsTracking: true))
        XCTAssertFalse(SplitCueTracker.isActive(ttsEnabled: false, cueStyle: .voice, distanceCues: true, gpsTracking: true))
        XCTAssertFalse(SplitCueTracker.isActive(ttsEnabled: true, cueStyle: .voice, distanceCues: false, gpsTracking: true))
        XCTAssertFalse(SplitCueTracker.isActive(ttsEnabled: true, cueStyle: .voice, distanceCues: true, gpsTracking: false))
    }

    func testSpokenDistanceAndPace() {
        let tts = TTSManager()
        XCTAssertEqual(tts.text(for: .distanceSplit(meters: 2000, paceSecondsPerKm: 400)),
                       "2 kilometres. Pace 6 minutes and 40 seconds per kilometre")
        XCTAssertEqual(tts.text(for: .distanceSplit(meters: 1000, paceSecondsPerKm: nil)), "1 kilometre")
        XCTAssertEqual(tts.text(for: .distanceSplit(meters: 1500, paceSecondsPerKm: 360)),
                       "1 kilometre 500 metres. Pace 6 minutes per kilometre")
        XCTAssertEqual(tts.text(for: .distanceSplit(meters: 500, paceSecondsPerKm: nil)), "500 metres")
    }
}

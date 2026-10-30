import XCTest
@testable import CtoK

// Ported from the Android app's ChimeSynthTest and ToneCuesTest.
final class ChimeSynthTests: XCTestCase {

    private func peak(_ pcm: [Int16], _ range: Range<Int>? = nil) -> Int {
        (range ?? pcm.indices).map { abs(Int(pcm[$0])) }.max() ?? 0
    }

    // Goertzel: the signal's power at one frequency, enough to tell which of two notes dominates.
    private func power(_ pcm: [Int16], _ range: Range<Int>, at frequencyHz: Double) -> Double {
        let coefficient = 2 * cos(2 * .pi * frequencyHz / Double(ChimeSynth.sampleRate))
        var previous = 0.0, beforePrevious = 0.0
        for i in range {
            let current = Double(pcm[i]) + coefficient * previous - beforePrevious
            beforePrevious = previous
            previous = current
        }
        return previous * previous + beforePrevious * beforePrevious - coefficient * previous * beforePrevious
    }

    // Start sample and length of each note within a rendered chime.
    private func noteSpans(_ chime: Chime) -> [(start: Int, length: Int)] {
        var offset = 0
        return chime.notes.map { note in
            let length = ChimeSynth.samples(note.durationMs)
            defer { offset += length + ChimeSynth.samples(note.gapAfterMs) }
            return (offset, length)
        }
    }

    func testEveryChimeRendersExactlyItsNotesAndGaps() {
        for chime in Chime.allCases {
            let expected = chime.notes.reduce(0) { $0 + ChimeSynth.samples($1.durationMs) + ChimeSynth.samples($1.gapAfterMs) }
            XCTAssertEqual(ChimeSynth.render(chime).count, expected, "\(chime)")
        }
    }

    func testNotesStartAndEndAtZeroAndGapsAreSilent() {
        for chime in Chime.allCases {
            let pcm = ChimeSynth.render(chime)
            for (index, span) in noteSpans(chime).enumerated() {
                XCTAssertEqual(pcm[span.start], 0, "\(chime) note \(index) first sample")
                XCTAssertEqual(pcm[span.start + span.length - 1], 0, "\(chime) note \(index) last sample")
                let gapEnd = span.start + span.length + ChimeSynth.samples(chime.notes[index].gapAfterMs)
                XCTAssertEqual(peak(pcm, (span.start + span.length)..<gapEnd), 0, "\(chime) gap after note \(index)")
            }
        }
    }

    func testChimesAreLoudButNeverExceedTheHeadroom() {
        let limit = Int(ChimeSynth.peak * Double(Int16.max)) + 1
        for chime in Chime.allCases {
            let loudest = peak(ChimeSynth.render(chime))
            XCTAssertLessThanOrEqual(loudest, limit, "\(chime)")
            XCTAssertGreaterThan(loudest, limit / 2, "\(chime) is too quiet")
        }
    }

    func testRunRisesAndWalkFalls() {
        // In each rendered note, the chime's own pitch for that note outweighs its other note's.
        func soundsAsWritten(_ chime: Chime) {
            let pcm = ChimeSynth.render(chime)
            let pitches = chime.notes.map(\.frequencyHz)
            for (index, span) in noteSpans(chime).enumerated() {
                let own = pitches[index], other = pitches[1 - index]
                let range = span.start..<(span.start + span.length)
                XCTAssertGreaterThan(power(pcm, range, at: own), power(pcm, range, at: other),
                                     "\(chime) note \(index) should sound at \(own) Hz")
            }
        }
        XCTAssertGreaterThan(Chime.run.notes.last!.frequencyHz, Chime.run.notes.first!.frequencyHz)
        XCTAssertLessThan(Chime.walk.notes.last!.frequencyHz, Chime.walk.notes.first!.frequencyHz)
        soundsAsWritten(.run)
        soundsAsWritten(.walk)
    }

    func testRunIsQuickerAndHigherThanWalk() {
        let run = Chime.run.notes, walk = Chime.walk.notes
        XCTAssertLessThan(run.reduce(0) { $0 + $1.durationMs + $1.gapAfterMs },
                          walk.reduce(0) { $0 + $1.durationMs + $1.gapAfterMs })
        XCTAssertGreaterThan(run.last!.frequencyHz, 2 * walk.last!.frequencyHz)
    }

    func testEveryChimeIsDistinctAndShort() {
        XCTAssertEqual(Set(Chime.allCases.map(\.notes)).count, Chime.allCases.count)
        for chime in Chime.allCases {
            let ms = chime.notes.reduce(0) { $0 + $1.durationMs + $1.gapAfterMs }
            XCTAssertLessThanOrEqual(ms, 1_200, "\(chime) lasts \(ms) ms")
        }
    }

    func testTheSecondCountdownWarningIsTwoTicksOfTheFirst() {
        let first = Chime.countdownFirst.notes.first!
        let second = Chime.countdownSecond.notes
        XCTAssertEqual(second.count, 2)
        second.forEach { XCTAssertEqual($0.frequencyHz, first.frequencyHz) }
    }

    func testWavWrapsThePCMWithA44ByteHeader() {
        let pcm = ChimeSynth.render(.run)
        let wav = ChimeSynth.wav(pcm)
        XCTAssertEqual(wav.count, 44 + pcm.count * 2)
        XCTAssertEqual(String(decoding: wav.prefix(4), as: UTF8.self), "RIFF")
        XCTAssertEqual(String(decoding: wav[8..<12], as: UTF8.self), "WAVE")
    }
}

final class ToneCuesTests: XCTestCase {
    private let bothWarnings = countdownWarningThresholds(10, 5, warning2Enabled: true)

    private func start(_ type: IntervalType) -> TTSManager.Announcement {
        .intervalStart(Interval(type: type, durationSeconds: 60))
    }

    func testEachIntervalTypeStartsWithItsOwnChime() {
        XCTAssertEqual(ToneCues.chime(for: start(.warmup), countdownThresholds: bothWarnings), .warmup)
        XCTAssertEqual(ToneCues.chime(for: start(.run), countdownThresholds: bothWarnings), .run)
        XCTAssertEqual(ToneCues.chime(for: start(.walk), countdownThresholds: bothWarnings), .walk)
        XCTAssertEqual(ToneCues.chime(for: start(.cooldown), countdownThresholds: bothWarnings), .cooldown)
    }

    func testWorkoutCompletePlaysTheCompletionChime() {
        XCTAssertEqual(ToneCues.chime(for: .workoutComplete, countdownThresholds: bothWarnings), .complete)
    }

    func testTheFirstWarningTicksOnceAndTheSecondTwice() {
        XCTAssertEqual(ToneCues.chime(for: .countdownWarning(10), countdownThresholds: bothWarnings), .countdownFirst)
        XCTAssertEqual(ToneCues.chime(for: .countdownWarning(5), countdownThresholds: bothWarnings), .countdownSecond)
    }

    func testTheOrderTheWarningsFireInDecidesTheTicksNotWhichSettingTheyCameFrom() {
        let swapped = countdownWarningThresholds(5, 10, warning2Enabled: true)
        XCTAssertEqual(ToneCues.chime(for: .countdownWarning(10), countdownThresholds: swapped), .countdownFirst)
        XCTAssertEqual(ToneCues.chime(for: .countdownWarning(5), countdownThresholds: swapped), .countdownSecond)
    }

    func testALoneWarningIsASingleTick() {
        for thresholds in [countdownWarningThresholds(10, 5, warning2Enabled: false),
                           countdownWarningThresholds(8, 8, warning2Enabled: true)] {
            XCTAssertEqual(thresholds.count, 1)
            XCTAssertEqual(ToneCues.chime(for: .countdownWarning(thresholds[0]), countdownThresholds: thresholds),
                           .countdownFirst)
        }
    }

    func testWordOnlyCuesHaveNoChime() {
        let wordOnly: [TTSManager.Announcement] = [
            .nextInterval(Interval(type: .run, durationSeconds: 60)), .intervalMidpoint(phraseIndex: 0),
            .periodicTimeRemaining(30), .halfway, .lastRunInterval,
        ]
        for announcement in wordOnly {
            XCTAssertNil(ToneCues.chime(for: announcement, countdownThresholds: bothWarnings), "\(announcement)")
        }
    }
}

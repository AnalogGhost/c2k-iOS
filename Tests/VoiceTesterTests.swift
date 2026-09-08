import XCTest
@testable import CtoK

@MainActor
final class VoiceTesterTests: XCTestCase {
    func testBogusLanguageReportsVoiceUnavailable() {
        let tester = VoiceTester()
        tester.speakTest(rate: 1.0, volume: 1.0, language: "zz-ZZ")
        XCTAssertEqual(tester.status, .voiceUnavailable)
    }

    func testStartsIdle() {
        XCTAssertEqual(VoiceTester().status, .idle)
    }

    func testStatusFailureFlag() {
        XCTAssertTrue(VoiceTestStatus.voiceUnavailable.isFailure)
        XCTAssertTrue(VoiceTestStatus.audioOutputFailure.isFailure)
        XCTAssertTrue(VoiceTestStatus.synthesisFailure.isFailure)
        XCTAssertFalse(VoiceTestStatus.playing.isFailure)
        XCTAssertFalse(VoiceTestStatus.finished.isFailure)
    }

    func testIdleHasNoStatusText() {
        XCTAssertNil(VoiceTestStatus.idle.localizedText)
        XCTAssertNotNil(VoiceTestStatus.finished.localizedText)
    }
}

import AVFoundation
import XCTest
@testable import CtoK

/// Stands in for AVAudioSession; deactivating fails while `busyDeactivations` is above zero, as
/// it does while a cue's last buffer is still playing.
private final class FakeSession: AudioSessionControlling {
    var busyDeactivations = 0
    var isActive = false
    var options: AVAudioSession.CategoryOptions = []
    var notifiedOthers = 0

    func setCategory(_ category: AVAudioSession.Category, mode: AVAudioSession.Mode,
                     options: AVAudioSession.CategoryOptions) throws {
        self.options = options
    }

    func setActive(_ active: Bool, options: AVAudioSession.SetActiveOptions) throws {
        if !active && busyDeactivations > 0 {
            busyDeactivations -= 1
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(AVAudioSession.ErrorCode.isBusy.rawValue))
        }
        if !active && options.contains(.notifyOthersOnDeactivation) { notifiedOthers += 1 }
        isActive = active
    }
}

final class AudioDuckingTests: XCTestCase {
    private var session: FakeSession!
    private var scheduled: [DispatchWorkItem] = []
    private var manager: BackgroundAudioManager!

    override func setUp() {
        session = FakeSession()
        scheduled = []
        manager = BackgroundAudioManager(session: session, schedule: { [unowned self] _, work in
            scheduled.append(work)
        }, keepsAlive: false)
        manager.start()
    }

    /// Runs whatever the manager has scheduled, including anything that schedules again.
    private func drain() {
        while !scheduled.isEmpty {
            let work = scheduled.removeFirst()
            if !work.isCancelled { work.perform() }
        }
    }

    func testACueDucksOthersAndHandsTheirVolumeBack() {
        manager.beginDucking(mode: .voicePrompt)
        XCTAssertTrue(session.options.contains(.duckOthers))
        XCTAssertTrue(session.isActive)

        manager.endDucking()
        drain()
        XCTAssertEqual(session.notifiedOthers, 1)
        XCTAssertEqual(session.options, [.mixWithOthers])
        XCTAssertTrue(session.isActive, "the keep-alive session comes back after the cue")
    }

    func testABusySessionIsRetriedUntilOthersGetTheirVolumeBack() {
        manager.beginDucking(mode: .voicePrompt)
        session.busyDeactivations = 3
        manager.endDucking()
        drain()
        XCTAssertEqual(session.notifiedOthers, 1)
        XCTAssertEqual(session.options, [.mixWithOthers])
    }

    func testASessionThatStaysBusyIsEventuallyGivenUp() {
        manager.beginDucking(mode: .voicePrompt)
        session.busyDeactivations = 100
        manager.endDucking()
        drain()
        XCTAssertEqual(session.busyDeactivations, 100 - BackgroundAudioManager.maxReleaseAttempts)
        XCTAssertEqual(session.options, [.mixWithOthers], "the workout's own session is restored")
    }

    func testACueStraightAfterAnotherKeepsTheDuck() {
        manager.beginDucking(mode: .voicePrompt)
        manager.endDucking()
        manager.beginDucking(mode: .voicePrompt)
        drain()
        XCTAssertEqual(session.notifiedOthers, 0)
        XCTAssertTrue(session.options.contains(.duckOthers))

        manager.endDucking()
        drain()
        XCTAssertEqual(session.notifiedOthers, 1)
    }
}

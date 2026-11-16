import AVFoundation

// Plays a silent audio loop to prevent iOS from suspending the app mid-workout
// when GPS is not active. Requires UIBackgroundModes: audio in Info.plist.
//
// It also owns the audio session for the whole workout, so cue ducking goes through it: the
// silent loop has to stop while a cue holds the duck, because a session with running I/O can't
// be deactivated, and deactivating is the only thing that gives other apps their volume back.
final class BackgroundAudioManager: AudioDucking {
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var isRunning = false
    private var isDucking = false
    private var pendingRelease: DispatchWorkItem?
    private var releaseAttempts = 0

    private let session: AudioSessionControlling
    private let schedule: (TimeInterval, DispatchWorkItem) -> Void
    private let keepsAlive: Bool

    // Time for the synthesizer's last buffer to drain after didFinish; deactivating any sooner
    // fails with "session has running I/O" and leaves other apps ducked. If it still fails, the
    // release is retried this often, up to `maxReleaseAttempts` times.
    static let releaseDelay: TimeInterval = 0.3
    static let maxReleaseAttempts = 6

    /// `session`, `schedule` and `keepsAlive` are seams for tests; the app uses the defaults.
    init(session: AudioSessionControlling = AVAudioSession.sharedInstance(),
         schedule: @escaping (TimeInterval, DispatchWorkItem) -> Void = { delay, work in
             DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
         },
         keepsAlive: Bool = true) {
        self.session = session
        self.schedule = schedule
        self.keepsAlive = keepsAlive
    }

    func start() {
        #if DEBUG
        // The screenshot walkthrough never plays audio; skip the AVAudioEngine
        // keep-alive so a starved CoreAudio RPC can't abort the app mid-capture.
        if CommandLine.arguments.contains("--screenshot-seed") { return }
        #endif

        guard !isRunning, activateMixing() else { return }
        isRunning = true
        startKeepAlive()
    }

    func stop() {
        pendingRelease?.cancel()
        pendingRelease = nil
        isDucking = false
        isRunning = false
        stopKeepAlive()
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: AudioDucking

    func beginDucking(mode: AVAudioSession.Mode) {
        // A cue that follows straight on from the last one keeps the existing duck, so the music
        // doesn't bounce back up between them.
        pendingRelease?.cancel()
        pendingRelease = nil
        guard !isDucking else { return }
        guard isRunning else {
            StandaloneDucking.shared.beginDucking(mode: mode)
            return
        }
        isDucking = true
        stopKeepAlive()   // the cue's own audio keeps the app alive while it plays
        try? session.setActive(false, options: [])
        try? session.setCategory(.playback, mode: mode, options: [.duckOthers])
        try? session.setActive(true, options: [])
    }

    func endDucking() {
        guard isRunning else {
            StandaloneDucking.shared.endDucking()
            return
        }
        guard isDucking, pendingRelease == nil else { return }
        releaseAttempts = 0
        scheduleRelease()
    }

    private func scheduleRelease() {
        let work = DispatchWorkItem { [weak self] in self?.releaseDuck() }
        pendingRelease = work
        schedule(Self.releaseDelay, work)
    }

    private func releaseDuck() {
        pendingRelease = nil
        guard isDucking else { return }
        releaseAttempts += 1
        do {
            try session.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            // Still busy finishing the cue. Swallowing this left other apps ducked until the
            // runner restarted them, so try again shortly.
            if releaseAttempts < Self.maxReleaseAttempts {
                scheduleRelease()
                return
            }
            // Give up rather than hold the keep-alive off for the rest of the workout.
        }
        isDucking = false
        guard isRunning, activateMixing() else { return }
        startKeepAlive()
    }

    // MARK: Session and keep-alive

    @discardableResult
    private func activateMixing() -> Bool {
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true, options: [])
            return true
        } catch {
            return false
        }
    }

    private func startKeepAlive() {
        guard keepsAlive, audioEngine == nil else { return }
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)

        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4096) else { return }
        buffer.frameLength = 4096
        // Buffer data left as zeros — silent

        engine.connect(player, to: engine.mainMixerNode, format: format)
        do {
            try engine.start()
        } catch {
            return
        }

        player.scheduleBuffer(buffer, at: nil, options: .loops)
        player.play()

        self.audioEngine = engine
        self.playerNode = player
    }

    private func stopKeepAlive() {
        playerNode?.stop()
        audioEngine?.stop()
        playerNode = nil
        audioEngine = nil
    }
}

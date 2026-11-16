import AVFoundation

/// Lowers other apps' audio (Spotify, Music, podcasts) while a cue sounds and restores it after.
///
/// iOS only lowers other audio when a session that has `.duckOthers` becomes active, and only
/// restores it when that session is deactivated with `.notifyOthersOnDeactivation`. Swapping the
/// category of an already-active session leaves other apps in whatever state they were in, so
/// every cue has to go through a real activate/deactivate pair.
protocol AudioDucking: AnyObject {
    func beginDucking(mode: AVAudioSession.Mode)
    func endDucking()
}

/// The parts of AVAudioSession ducking uses, so tests can stand in for it.
protocol AudioSessionControlling: AnyObject {
    func setCategory(_ category: AVAudioSession.Category, mode: AVAudioSession.Mode,
                     options: AVAudioSession.CategoryOptions) throws
    func setActive(_ active: Bool, options: AVAudioSession.SetActiveOptions) throws
}

extension AVAudioSession: AudioSessionControlling {}

/// Ducking for cues played outside a workout (Settings' test buttons), where nothing else holds
/// the session.
final class StandaloneDucking: AudioDucking {
    static let shared = StandaloneDucking()

    // Bumped by each cue, so a release still waiting from the previous one stands down.
    private var generation = 0

    func beginDucking(mode: AVAudioSession.Mode) {
        generation += 1
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: mode, options: [.duckOthers])
        try? session.setActive(true)
    }

    func endDucking() {
        release(attempt: 1, generation: generation)
    }

    // Deactivating while the cue's last buffer is still playing fails and leaves other apps
    // ducked, so wait for it to drain and retry, as BackgroundAudioManager does.
    private func release(attempt: Int, generation: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + BackgroundAudioManager.releaseDelay) { [weak self] in
            guard let self, self.generation == generation else { return }
            do {
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            } catch where attempt < BackgroundAudioManager.maxReleaseAttempts {
                self.release(attempt: attempt + 1, generation: generation)
            } catch {}
        }
    }
}

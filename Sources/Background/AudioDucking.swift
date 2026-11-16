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

/// Ducking for cues played outside a workout (Settings' test buttons), where nothing else holds
/// the session.
final class StandaloneDucking: AudioDucking {
    static let shared = StandaloneDucking()

    func beginDucking(mode: AVAudioSession.Mode) {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: mode, options: [.duckOthers])
        try? session.setActive(true)
    }

    func endDucking() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

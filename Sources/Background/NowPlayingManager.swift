import MediaPlayer

// iOS-idiomatic equivalent of Android's persistent workout notification: surfaces the
// current interval, progress, and remaining time on the lock screen / Control Center via
// Now Playing info, with pause/resume/stop controls. Rides the same `audio` background
// mode BackgroundAudioManager already holds — no extra capability needed.
@MainActor
final class NowPlayingManager {
    var onPause: (() -> Void)?
    var onResume: (() -> Void)?
    var onStop: (() -> Void)?

    private let commandCenter = MPRemoteCommandCenter.shared()
    private var isActive = false

    func start() {
        guard !isActive else { return }
        isActive = true

        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.onPause?()
            return .success
        }
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.onResume?()
            return .success
        }
        commandCenter.stopCommand.isEnabled = true
        commandCenter.stopCommand.addTarget { [weak self] _ in
            self?.onStop?()
            return .success
        }
    }

    func update(title: String, subtitle: String, isPlaying: Bool, elapsedSeconds: Double, durationSeconds: Double) {
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPMediaItemPropertyTitle] = title
        info[MPMediaItemPropertyArtist] = subtitle
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsedSeconds
        info[MPMediaItemPropertyPlaybackDuration] = durationSeconds
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    func stop() {
        guard isActive else { return }
        isActive = false
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.stopCommand.removeTarget(nil)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
}

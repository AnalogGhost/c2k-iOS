import Foundation
import Observation

/// Plays the run chime, then the walk chime, for the Test tones button in Settings — the two cues
/// a runner most needs to tell apart. Mirrors Android's SettingsViewModel.testTones().
@Observable
@MainActor
final class ToneTester {
    private(set) var isPlaying = false
    private var task: Task<Void, Never>?

    private static let pauseBetweenMs = 400

    func playTest(volume: Float) {
        guard !WorkoutManager.shared.isRunning, !isPlaying else { return }
        isPlaying = true
        task = Task {
            let player = TonePlayer(volume: volume)
            player.play(.run)
            await Self.waitUntilQuiet(player)
            try? await Task.sleep(for: .milliseconds(Self.pauseBetweenMs))
            player.play(.walk)
            await Self.waitUntilQuiet(player)
            player.shutdown()
            isPlaying = false
        }
    }

    private static func waitUntilQuiet(_ player: TonePlayer) async {
        // Bounded in case the player never reports finishing.
        for _ in 0..<40 where player.isSpeaking {
            try? await Task.sleep(for: .milliseconds(50))
        }
    }
}

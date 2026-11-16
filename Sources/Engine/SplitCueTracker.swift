import Foundation

/// The split lengths Settings offers for distance-and-pace updates, in metres.
let distanceCueSplits = [500, 1000]

/// Decides when to announce distance and pace: once each time the run's total distance passes
/// another `splitMeters`. Pace is the average over the split just finished (moving time per
/// kilometre), which is far steadier than the GPS's instantaneous speed.
///
/// Fed the cumulative GPS distance and the session's elapsed time, both of which exclude pauses,
/// so a split spanning a pause still gets a true pace. Mirrors Android's SplitCueTracker.
struct SplitCueTracker {
    // Faster than 2:00/km is a GPS error, not a beginner runner; slower than a slow walk says
    // nothing useful.
    static let minPaceSecondsPerKm = 120
    static let maxPaceSecondsPerKm = 30 * 60

    let splitMeters: Int
    private var splitsAnnounced = 0
    private var lastSplitElapsedSeconds = 0
    private var lastSplitMeters = 0

    init(splitMeters: Int) {
        precondition(splitMeters > 0, "splitMeters must be positive")
        self.splitMeters = splitMeters
    }

    /// Returns the announcement for a split passed since the last call, or nil. If one GPS jump
    /// passes several splits at once, only the latest is announced, with the pace averaged over
    /// all of them.
    mutating func onProgress(totalMeters: Double, elapsedSeconds: Int) -> TTSManager.Announcement? {
        let splits = Int(totalMeters / Double(splitMeters))
        guard splits > splitsAnnounced else { return nil }

        let meters = splits * splitMeters
        let coveredMeters = meters - lastSplitMeters
        let seconds = elapsedSeconds - lastSplitElapsedSeconds
        splitsAnnounced = splits
        lastSplitMeters = meters
        lastSplitElapsedSeconds = elapsedSeconds

        let pace = seconds * 1000 / coveredMeters
        let usable = seconds > 0 && (Self.minPaceSecondsPerKm...Self.maxPaceSecondsPerKm).contains(pace)
        return .distanceSplit(meters: meters, paceSecondsPerKm: usable ? pace : nil)
    }

    /// Whether to speak distance and pace at each split: only with spoken cues (a chime can't
    /// carry a number) and only while GPS actually tracks the run (not treadmill mode, GPS off,
    /// or location denied).
    static func isActive(ttsEnabled: Bool, cueStyle: CueStyle, distanceCues: Bool, gpsTracking: Bool) -> Bool {
        ttsEnabled && cueStyle == .voice && distanceCues && gpsTracking
    }
}

import Foundation
import UserNotifications

/// What a smartwatch cue says: the interval that just started, or the end of the workout.
enum WatchCue {
    case interval(Interval)
    case complete

    var title: String {
        switch self {
        case .interval(let interval): return intervalLabel(interval.type)
        case .complete:               return String(localized: "Workout Complete!")
        }
    }

    var body: String {
        switch self {
        case .interval(let interval): return formatTime(interval.durationSeconds)
        case .complete:               return String(localized: "Great job! Keep up the good work.")
        }
    }
}

protocol WatchCuePosting: AnyObject {
    func post(_ cue: WatchCue)
    func clear()
}

/// Posts a short notification at each interval change and when the workout ends, so a paired
/// Apple Watch taps the wrist while the iPhone is locked in a pocket. iOS hands a notification to
/// the watch only when the phone is locked, and then doesn't alert on the phone too, so the
/// phone's own haptics stay as they are. Port of the Android app's smartwatch cues.
final class WatchCueNotifier: WatchCuePosting {
    private let center = UNUserNotificationCenter.current()
    private var lastIdentifier: String?

    // At most one cue exists at a time: the previous one is removed before the next is posted, so
    // they never stack up. Each gets a fresh identifier so it alerts as a new notification rather
    // than silently replacing the last one.
    func post(_ cue: WatchCue) {
        clear()
        let content = UNMutableNotificationContent()
        content.title = cue.title
        content.body = cue.body
        content.sound = .default
        content.threadIdentifier = "c2k-workout-cues"
        let identifier = "c2k-cue-\(UUID().uuidString)"
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: nil))
        lastIdentifier = identifier
    }

    func clear() {
        guard let lastIdentifier else { return }
        center.removeDeliveredNotifications(withIdentifiers: [lastIdentifier])
        center.removePendingNotificationRequests(withIdentifiers: [lastIdentifier])
        self.lastIdentifier = nil
    }

    /// Asks for permission to post cues; false if the runner declines or has turned
    /// notifications off for C2K.
    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }
}

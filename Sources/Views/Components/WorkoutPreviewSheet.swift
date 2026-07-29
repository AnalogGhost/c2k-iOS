import SwiftUI

struct WorkoutPreviewSheet: View {
    let week: Int
    let day: Int
    let workoutDay: WorkoutDay
    let isCompleted: Bool
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(String(format: String(localized: "program_preview_title"), week, day))
                .font(.title2.bold())
            Text(previewDurationText)
                .foregroundStyle(.secondary)
                .padding(.top, 2)

            Divider().padding(.vertical, 16)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(groupedIntervals.enumerated()), id: \.offset) { _, group in
                        IntervalGroupRow(group: group)
                    }
                }
            }

            Button(action: onStart) {
                Text(isCompleted ? "Redo" : "Start")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 24)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
        .padding(.top, 8)
    }

    private var groupedIntervals: [IntervalGroup] {
        workoutDay.intervals.grouped()
    }

    private var previewDurationText: String {
        let minutes = workoutDay.totalDurationSeconds / 60
        return String.localizedStringWithFormat(
            NSLocalizedString("program_preview_duration", comment: ""), minutes)
    }
}

private struct IntervalGroup {
    let type: IntervalType
    let durationSeconds: Int
    let count: Int
}

private struct IntervalGroupRow: View {
    let group: IntervalGroup

    var body: some View {
        HStack {
            Text(label + (group.count > 1 ? " × \(group.count)" : ""))
                .foregroundColor(color)
            Spacer()
            Text(formatDuration(group.durationSeconds))
        }
        .font(.body)
        .padding(.vertical, 6)
    }

    private var color: Color {
        switch group.type {
        case .run:              return .runOrange
        case .walk:             return .walkBlue
        case .warmup, .cooldown: return .warmCoolGreen
        }
    }

    private var label: String { intervalLabel(group.type) }

    private func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60, s = seconds % 60
        let mUnit = String(localized: "m"), sUnit = String(localized: "s"), minWord = String(localized: "min")
        if m > 0 && s > 0 { return "\(m)\(mUnit) \(s)\(sUnit)" }
        if m > 0 { return "\(m) \(minWord)" }
        return "\(s)\(sUnit)"
    }
}

private extension [Interval] {
    func grouped() -> [IntervalGroup] {
        guard !isEmpty else { return [] }
        var result: [IntervalGroup] = []
        var type = first!.type
        var duration = first!.durationSeconds
        var count = 1
        for interval in dropFirst() {
            if interval.type == type && interval.durationSeconds == duration {
                count += 1
            } else {
                result.append(IntervalGroup(type: type, durationSeconds: duration, count: count))
                type = interval.type; duration = interval.durationSeconds; count = 1
            }
        }
        result.append(IntervalGroup(type: type, durationSeconds: duration, count: count))
        return result
    }
}

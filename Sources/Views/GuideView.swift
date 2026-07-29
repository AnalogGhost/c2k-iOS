import SwiftUI

struct GuideView: View {
    var body: some View {
        List {
            ForEach(guideSections, id: \.title) { section in
                Section(section.title) {
                    ForEach(section.entries, id: \.questionKey) { entry in
                        DisclosureGroup(NSLocalizedString(entry.questionKey, comment: "")) {
                            Text(NSLocalizedString(entry.answerKey, comment: ""))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 4)
                        }
                        .font(.body)
                    }
                }
            }
        }
        .navigationTitle("Guide")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Data

private struct GuideEntry {
    let questionKey: String
    let answerKey: String
}

private struct GuideSection {
    let title: String
    let entries: [GuideEntry]
}

private func entry(_ id: String) -> GuideEntry {
    GuideEntry(questionKey: "guide_q_\(id)", answerKey: "guide_a_\(id)")
}

private let guideSections: [GuideSection] = [
    GuideSection(title: "Before You Start", entries: [
        entry("conversational_pace"),
        entry("gear_needed"),
        entry("first_week"),
        entry("safe_to_start"),
    ]),

    GuideSection(title: "During a Workout", entries: [
        entry("warmup"),
        entry("cooldown"),
        entry("pain_discomfort"),
        entry("breathing"),
        entry("cant_finish_interval"),
    ]),

    GuideSection(title: "Between Workouts", entries: [
        entry("rest_days"),
        entry("rest_day_activities"),
        entry("repeat_day"),
        entry("ready_next_session"),
        entry("stretch"),
    ]),

    GuideSection(title: "Glossary", entries: [
        entry("aerobic_fitness"),
        entry("interval_term"),
        entry("pace_term"),
        entry("doms"),
        entry("shin_splints"),
        entry("rpe"),
        entry("calorie_estimate"),
    ]),
]

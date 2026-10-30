import Foundation

// Translated program names, descriptions and prerequisites, looked up by program id like the
// Android app's ProgramStrings.kt. The English text in Programs.swift stays the fallback for an
// id without translations.
extension WorkoutPlan {
    var localizedName: String {
        localized(Self.nameKeys[programId], fallback: displayName)
    }

    var localizedDescription: String {
        localized(Self.descriptionKeys[programId], fallback: description)
    }

    var localizedPrerequisite: String? {
        guard let prerequisite else { return nil }
        return localized(Self.prerequisiteKeys[programId], fallback: prerequisite)
    }

    static let nameKeys = [
        Programs.idPreC25K: "program_pre_c25k", Programs.idC25K: "program_c25k",
        Programs.idC210K: "program_c210k", Programs.idB210K: "program_b210k",
        Programs.idOHR: "program_ohr", Programs.idFiveKI: "program_5ki",
    ]

    static let descriptionKeys = [
        Programs.idPreC25K: "program_pre_c25k_desc", Programs.idC25K: "program_c25k_desc",
        Programs.idC210K: "program_c210k_desc", Programs.idB210K: "program_b210k_desc",
        Programs.idOHR: "program_ohr_desc", Programs.idFiveKI: "program_5ki_desc",
    ]

    static let prerequisiteKeys = [
        Programs.idC210K: "program_prereq_after_c25k", Programs.idB210K: "program_prereq_after_c25k",
        Programs.idOHR: "program_prereq_after_b210k_or_c25k", Programs.idFiveKI: "program_prereq_for_5k_runners",
    ]

    private func localized(_ key: String?, fallback: String) -> String {
        guard let key else { return fallback }
        return Bundle.main.localizedString(forKey: key, value: fallback, table: nil)
    }
}

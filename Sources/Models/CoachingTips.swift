import Foundation

enum CoachingTips {

    private static let c25k: [Int: String] = [
        1: "coaching_c25k_w1", 2: "coaching_c25k_w2", 3: "coaching_c25k_w3",
        4: "coaching_c25k_w4", 5: "coaching_c25k_w5", 6: "coaching_c25k_w6",
        7: "coaching_c25k_w7", 8: "coaching_c25k_w8", 9: "coaching_c25k_w9",
    ]

    private static let c210k: [Int: String] = [
        10: "coaching_c210k_w10", 11: "coaching_c210k_w11", 12: "coaching_c210k_w12",
        13: "coaching_c210k_w13", 14: "coaching_c210k_w14",
    ]

    private static let b210k: [Int: String] = [
        1: "coaching_b210k_w1", 2: "coaching_b210k_w2", 3: "coaching_b210k_w3",
        4: "coaching_b210k_w4", 5: "coaching_b210k_w5", 6: "coaching_b210k_w6",
    ]

    private static let ohr: [Int: String] = [
        1: "coaching_ohr_w1", 4: "coaching_ohr_w4", 7: "coaching_ohr_w7",
        10: "coaching_ohr_w10", 13: "coaching_ohr_w13",
    ]

    private static let fiveKi: [Int: String] = [
        1: "coaching_5ki_w1", 2: "coaching_5ki_w2", 4: "coaching_5ki_w4",
        6: "coaching_5ki_w6", 8: "coaching_5ki_w8",
    ]

    static func tip(programId: String, week: Int) -> String? {
        let key: String?
        switch programId {
        case Programs.idC25K:   key = c25k[week]
        case Programs.idC210K:  key = c210k[week]
        case Programs.idB210K:  key = b210k[week]
        case Programs.idOHR:    key = ohr[week]
        case Programs.idFiveKI: key = fiveKi[week]
        default: key = nil
        }
        return key.map { NSLocalizedString($0, comment: "") }
    }
}

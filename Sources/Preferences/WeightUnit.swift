import Foundation

// Body weight is always stored in kg; this only controls how Settings displays and edits it.
enum WeightUnit: String, CaseIterable {
    case kg, lb, stone

    private var kgPerUnit: Double {
        switch self {
        case .kg:    return 1
        case .lb:    return 0.45359237
        case .stone: return 6.35029
        }
    }

    var label: String {
        switch self {
        case .kg:    return String(localized: "kg")
        case .lb:    return String(localized: "lb")
        case .stone: return String(localized: "st")
        }
    }

    func toKg(_ native: Double) -> Double { native * kgPerUnit }
    func fromKg(_ kg: Double) -> Double { kg / kgPerUnit }
}

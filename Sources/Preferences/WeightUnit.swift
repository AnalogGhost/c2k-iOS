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

/// Heaviest weight Settings accepts, in kg; anything above is a typo, not a runner.
let maxWeightKg = 500.0

/// Parses the weight field as typed, in `unit`'s terms, and returns kg, or nil while the text
/// isn't a usable weight. Accepts '.' or ',' as the decimal mark: the field shows the locale's
/// separator, and the decimal pad offers a comma in most of the app's languages.
func parseWeightKg(_ text: String, unit: WeightUnit) -> Double? {
    let normalized = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
    // Double() also accepts "nan", "inf" and exponents; only plain decimals are weights.
    guard normalized.range(of: #"^(\d+(\.\d*)?|\.\d+)$"#, options: .regularExpression) != nil,
          let value = Double(normalized) else { return nil }
    let kg = unit.toKg(value)
    return kg > 0 && kg <= maxWeightKg ? kg : nil
}

/// Formats `value` with at most one decimal, in `locale`'s separator, without a trailing ".0".
func formatWeight(_ value: Double, locale: Locale = .current) -> String {
    value.formatted(.number.precision(.fractionLength(0...1)).grouping(.never).locale(locale))
}

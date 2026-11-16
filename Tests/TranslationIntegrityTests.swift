import XCTest

/// Checks every string in the catalog in every language: a translation whose placeholders differ
/// from the English one crashes or garbles when formatted, and for a voice cue that happens
/// mid-run in one language only. Ported from the Android app's TranslationIntegrityTest.
final class TranslationIntegrityTests: XCTestCase {
    private static let languages = ["de", "es", "fr", "gl", "pt-BR", "ru", "tr"]

    // Units and names that read the same in some languages, so those leave them untranslated.
    private static let languageNeutral: Set<String> = ["C2K", "GitHub", "kg", "lb", "st", "m", "s", "min", "km", "kcal"]

    // The plural categories each language needs (CLDR, integers only).
    private static func pluralForms(_ language: String) -> Set<String> {
        language == "ru" ? ["one", "few", "many", "other"] : ["one", "other"]
    }

    private struct Entry {
        let key: String
        let localizations: [String: Any]
    }

    private func catalog() throws -> [Entry] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/Localizable.xcstrings")
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        let strings = try XCTUnwrap(json?["strings"] as? [String: [String: Any]])
        return strings.map { Entry(key: $0.key, localizations: $0.value["localizations"] as? [String: Any] ?? [:]) }
    }

    /// The text of each form: "" for a plain string, else the plural category.
    private func forms(_ localization: Any?) -> [String: String] {
        guard let loc = localization as? [String: Any] else { return [:] }
        if let unit = loc["stringUnit"] as? [String: Any] { return ["": unit["value"] as? String ?? ""] }
        let plural = (loc["variations"] as? [String: Any])?["plural"] as? [String: [String: Any]] ?? [:]
        return plural.compactMapValues { ($0["stringUnit"] as? [String: Any])?["value"] as? String }
    }

    /// Format specifiers by argument position, so "%1$@ %2$lld" and "%2$lld %1$@" match.
    private func placeholders(_ text: String) -> [String] {
        let regex = try! NSRegularExpression(pattern: #"%(?:(\d+)\$)?(?:\.\d+)?(lld|ld|d|@|f)"#)
        let stripped = text.replacingOccurrences(of: "%%", with: "")
        let ns = stripped as NSString
        return regex.matches(in: stripped, range: NSRange(location: 0, length: ns.length)).enumerated().map { i, m in
            let position = m.range(at: 1).location == NSNotFound ? "\(i + 1)" : ns.substring(with: m.range(at: 1))
            return "\(position):\(ns.substring(with: m.range(at: 2)))"
        }.sorted()
    }

    func testEveryStringIsTranslatedIntoEveryLanguage() throws {
        for entry in try catalog() where !Self.languageNeutral.contains(entry.key) {
            for language in Self.languages {
                XCTAssertFalse(forms(entry.localizations[language]).isEmpty, "\(entry.key) has no \(language) translation")
            }
            // Identifier keys (tts_seconds_remaining) have no English text of their own.
            if entry.key.contains("_") && entry.key == entry.key.lowercased() && !entry.key.contains(" ") {
                XCTAssertFalse(forms(entry.localizations["en"]).isEmpty, "\(entry.key) has no English text")
            }
        }
    }

    func testEveryTranslationTakesTheSameArgumentsAsEnglish() throws {
        for entry in try catalog() {
            let english = forms(entry.localizations["en"])
            let reference = placeholders(english["other"] ?? english[""] ?? entry.key)
            for language in Self.languages + ["en"] {
                for (form, text) in forms(entry.localizations[language]) {
                    // A "one" form may spell the number out ("Una semana") instead of printing it.
                    if form == "one" && placeholders(text).isEmpty { continue }
                    XCTAssertEqual(placeholders(text), reference, "\(entry.key) [\(language) \(form)]: \(text)")
                }
            }
        }
    }

    func testEveryPluralHasTheFormsItsLanguageNeeds() throws {
        for entry in try catalog() {
            for language in Self.languages + ["en"] {
                let f = forms(entry.localizations[language])
                guard !f.isEmpty, f[""] == nil else { continue }
                let needed = language == "en" ? ["one", "other"] : Self.pluralForms(language)
                XCTAssertTrue(needed.isSubset(of: Set(f.keys)),
                              "\(entry.key) [\(language)] has \(f.keys.sorted()), needs \(needed.sorted())")
            }
        }
    }
}

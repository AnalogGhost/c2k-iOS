import XCTest
@testable import CtoK

final class LanguageControllerTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        suiteName = "test.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
    }

    func testApplySystemClearsTheChoice() {
        LanguageController.apply(.de, to: defaults)
        XCTAssertEqual(LanguageController.current(from: defaults), .de)

        LanguageController.apply(.system, to: defaults)
        XCTAssertNil(defaults.string(forKey: LanguageController.choiceKey))
        XCTAssertEqual(LanguageController.current(from: defaults), .system)
    }

    func testApplyWritesBothKeys() {
        LanguageController.apply(.tr, to: defaults)
        XCTAssertEqual(defaults.string(forKey: LanguageController.choiceKey), "tr")
        XCTAssertEqual(defaults.array(forKey: LanguageController.overrideKey) as? [String], ["tr"])
        LanguageController.apply(.ptBR, to: defaults)
        XCTAssertEqual(defaults.string(forKey: LanguageController.choiceKey), "pt-BR")
        XCTAssertEqual(defaults.array(forKey: LanguageController.overrideKey) as? [String], ["pt-BR"])
    }

    func testCurrentRoundTripsEveryCase() {
        for language in AppLanguage.allCases {
            LanguageController.apply(language, to: defaults)
            XCTAssertEqual(LanguageController.current(from: defaults), language, "\(language)")
        }
    }

    func testUnknownStoredChoiceIsSystem() {
        defaults.set("zz-ZZ", forKey: LanguageController.choiceKey)
        XCTAssertEqual(LanguageController.current(from: defaults), .system)
    }

    func testNoChoiceIsSystem() {
        XCTAssertEqual(LanguageController.current(from: defaults), .system)
    }
}

final class AppLanguageTests: XCTestCase {
    func testSystemHasNoBcp47() {
        XCTAssertNil(AppLanguage.system.bcp47)
    }

    func testBcp47MatchesRawValueForRealLanguages() {
        for language in AppLanguage.allCases where language != .system {
            XCTAssertEqual(language.bcp47, language.rawValue)
        }
    }

    func testTurkishIsAnOption() {
        XCTAssertTrue(AppLanguage.allCases.contains(.tr))
        XCTAssertEqual(AppLanguage.tr.displayName, "Türkçe")
    }

    func testPortugueseKeepsRegionSuffix() {
        XCTAssertEqual(AppLanguage.ptBR.bcp47, "pt-BR")
    }
}

@MainActor
final class TTSManagerLanguageTests: XCTestCase {
    func testOverrideDrivesResolvedLanguage() {
        let tts = TTSManager()
        tts.setLanguage("de")
        XCTAssertEqual(tts.resolvedLanguageCode(), "de")
    }

    func testNilOverrideUsesSystemVoiceLanguage() {
        let tts = TTSManager()
        tts.setLanguage(nil)
        XCTAssertFalse(tts.resolvedLanguageCode().isEmpty)
    }

    func testGalicianOverrideResolvesWithoutCrashing() {
        let tts = TTSManager()
        tts.setLanguage("gl")
        XCTAssertEqual(tts.resolvedLanguageCode(), "gl")
    }
}

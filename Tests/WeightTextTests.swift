import XCTest
@testable import CtoK

// Ported from the Android app's WeightTextTest.
final class WeightTextTests: XCTestCase {
    func testAcceptsEitherDecimalMark() {
        XCTAssertEqual(parseWeightKg("72.5", unit: .kg), 72.5)
        XCTAssertEqual(parseWeightKg("72,5", unit: .kg), 72.5)
        XCTAssertEqual(parseWeightKg(" 72 ", unit: .kg), 72)
        XCTAssertEqual(parseWeightKg(",5", unit: .kg), 0.5)
    }

    func testConvertsFromTheChosenUnit() throws {
        XCTAssertEqual(try XCTUnwrap(parseWeightKg("160", unit: .lb)), 72.57, accuracy: 0.01)
        XCTAssertEqual(try XCTUnwrap(parseWeightKg("11,5", unit: .stone)), 73.03, accuracy: 0.01)
    }

    func testRejectsTextThatIsNotAWeight() {
        for text in ["", "abc", "nan", "inf", "1e2", "-5", "0", "72.5.1", "501"] {
            XCTAssertNil(parseWeightKg(text, unit: .kg), text)
        }
        XCTAssertNil(parseWeightKg("1200", unit: .lb))   // 544 kg
    }

    func testFormatsInTheLocaleSeparatorWithoutATrailingZero() {
        XCTAssertEqual(formatWeight(72.5, locale: Locale(identifier: "en_US")), "72.5")
        XCTAssertEqual(formatWeight(72.5, locale: Locale(identifier: "fr_FR")), "72,5")
        XCTAssertEqual(formatWeight(103, locale: Locale(identifier: "ru_RU")), "103")
        XCTAssertEqual(formatWeight(1103.04, locale: Locale(identifier: "de_DE")), "1103")
    }

    func testTheFieldReadsBackWhatItShows() {
        for id in ["en_US", "fr_FR", "de_DE", "ru_RU", "pt_BR"] {
            let shown = formatWeight(72.5, locale: Locale(identifier: id))
            XCTAssertEqual(parseWeightKg(shown, unit: .kg), 72.5, id)
        }
    }
}

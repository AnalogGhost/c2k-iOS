import XCTest

/// Functional UI tests for the screens the Android-parity features touch. Runs against the same
/// seeded in-memory store as the screenshot walkthrough (`--screenshot-seed`, see ScreenshotSeed),
/// in English unless a test says otherwise, and finds controls by accessibility identifier.
@MainActor
final class FeatureUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["--screenshot-seed", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
    }

    private func launch(_ extra: [String] = []) {
        app.launchArguments += extra
        app.launch()
        XCTAssertTrue(app.navigationBars["C2K"].waitForExistence(timeout: 30))
    }

    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    private func open(_ navButton: String, screen: String) {
        app.buttons[navButton].tap()
        XCTAssertTrue(element(screen).waitForExistence(timeout: 10), "\(screen) didn't open")
    }

    private func scrollTo(_ target: XCUIElement, maxSwipes: Int = 8) {
        var swipes = 0
        while !target.isHittable && swipes < maxSwipes {
            app.swipeUp()
            swipes += 1
        }
    }

    // MARK: - Settings

    func testChoosingTonesSwapsTheVoiceControlsForTestTones() {
        launch()
        open("nav-settings", screen: "screen-settings")

        let testVoice = app.buttons["settings-test-voice"]
        scrollTo(testVoice)
        XCTAssertTrue(testVoice.exists)

        let cueStyle = app.buttons["settings-cue-style"]
        app.swipeDown(); app.swipeDown()
        scrollTo(cueStyle)
        cueStyle.tap()
        app.buttons["Tones"].firstMatch.tap()

        let testTones = app.buttons["settings-test-tones"]
        scrollTo(testTones)
        XCTAssertTrue(testTones.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["settings-test-voice"].exists)
        XCTAssertFalse(app.switches["Mid-run encouragement"].exists)
        XCTAssertTrue(app.staticTexts["Tone volume"].exists)
    }

    func testTurningOffTheSecondWarningHidesItsSlider() {
        launch()
        open("nav-settings", screen: "screen-settings")

        let slider = app.sliders["Second warning"]
        scrollTo(slider)
        XCTAssertTrue(slider.exists)

        let toggle = app.switches["Second warning"]
        toggle.switches.firstMatch.tap()
        XCTAssertFalse(slider.waitForExistence(timeout: 2))
        XCTAssertEqual(toggle.value as? String, "0")
    }

    func testSkipWarmupAndCooldownAreSeparateSwitches() {
        launch()
        open("nav-settings", screen: "screen-settings")

        // The warm-up switch carries its caption in its label too.
        let warmup = app.switches.matching(NSPredicate(format: "label BEGINSWITH 'Skip warm-up'")).firstMatch
        scrollTo(warmup)
        XCTAssertTrue(warmup.exists)
        XCTAssertTrue(app.switches["Skip cool-down"].exists)
        warmup.switches.firstMatch.tap()
        XCTAssertEqual(warmup.value as? String, "1")
        XCTAssertEqual(app.switches["Skip cool-down"].value as? String, "0")
    }

    // MARK: - History

    func testHistoryShowsTheWeeklyStreakAndUnits() {
        launch()
        open("nav-history", screen: "screen-history")
        XCTAssertTrue(element("history-streak").waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label ENDSWITH ' / km'")).firstMatch.exists,
                      "the fastest pace should show its unit")
    }

    // MARK: - Step back

    func testNoStepBackSuggestionWithoutEarlyStops() {
        launch()
        XCTAssertFalse(element("progression-suggestion").waitForExistence(timeout: 3))
    }

    func testRepeatingTheSuggestedWeekMovesContinueBack() {
        launch(["--seed-early-stops"])
        XCTAssertTrue(element("progression-suggestion").waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["You've stopped this workout early 2 times. Repeating week 2 can help you build up to it."].exists)

        app.buttons["progression-accept"].tap()
        XCTAssertFalse(element("progression-suggestion").waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons.containing(NSPredicate(format: "label CONTAINS 'Week 2, Day 1'")).firstMatch.exists,
                      "Continue should now point at the first day of the repeated week")
    }

    func testNotNowHidesTheSuggestion() {
        launch(["--seed-early-stops"])
        XCTAssertTrue(element("progression-suggestion").waitForExistence(timeout: 10))
        app.buttons["progression-dismiss"].tap()
        XCTAssertFalse(element("progression-suggestion").waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons.containing(NSPredicate(format: "label CONTAINS 'Week 3, Day 3'")).firstMatch.exists)
    }

    // MARK: - Workout

    func testTheWarmupCanBeSkippedFromTheWorkoutScreen() {
        launch()
        app.buttons["program-C25K"].tap()
        XCTAssertTrue(app.buttons["day-3-3"].waitForExistence(timeout: 10))
        app.buttons["day-3-3"].tap()
        XCTAssertTrue(app.buttons["start-workout"].waitForExistence(timeout: 10))
        app.buttons["start-workout"].tap()

        let skip = app.buttons["workout-skip-phase"]
        XCTAssertTrue(skip.waitForExistence(timeout: 60))
        XCTAssertTrue(skip.label.contains("Skip warm-up"))
        skip.tap()
        // Run intervals can't be skipped, so the button goes once the warm-up is over.
        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: skip)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(app.buttons["workout-pause"].exists)

        app.buttons["workout-pause"].tap()
    }

    // MARK: - Localisation

    func testGuideHeadingsAreTranslated() {
        app.launchArguments = ["--screenshot-seed", "-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launch()
        XCTAssertTrue(app.navigationBars["C2K"].waitForExistence(timeout: 30))
        open("nav-guide", screen: "screen-guide")
        XCTAssertTrue(app.staticTexts["BEVOR DU STARTEST"].exists || app.staticTexts["Bevor du startest"].exists,
                      "the Guide's first heading should be in German")
        XCTAssertFalse(app.staticTexts["BEFORE YOU START"].exists || app.staticTexts["Before You Start"].exists)
    }

    func testProgramNamesAreTranslated() {
        app.launchArguments = ["--screenshot-seed", "-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launch()
        XCTAssertTrue(app.navigationBars["C2K"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.staticTexts["Vom Sofa zum 5K"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["9-week program to run 5K. Start here — no fitness required."].exists)
    }
}

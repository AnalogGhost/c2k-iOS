import XCTest

/// App Store screenshot walkthrough, driven by `fastlane snapshot`
/// (`bundle exec fastlane screenshots`). Launches the app against a seeded
/// in-memory store (`--screenshot-seed`, see `CtoKApp`) and captures one shot
/// per key screen. Navigation uses the accessibility identifiers added to the
/// relevant controls plus a few stable button titles.
@MainActor
final class ScreenshotTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        setupSnapshot(app)
        // Seeds deterministic history + settings (see CtoKApp / ScreenshotSeed).
        app.launchArguments += ["--screenshot-seed"]
        app.launch()
    }

    func testScreenshots() {
        // Home first. The History/Guide/Settings shots are taken before the workout
        // so History shows only the seeded sessions (no 7-second incomplete run).
        XCTAssertTrue(app.navigationBars["C2K"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.staticTexts["home-streak"].waitForExistence(timeout: 5),
                      "Seeded history is missing — ScreenshotSeed did not populate the store")
        snapshot("01_home")

        tap(app.buttons["nav-history"])
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 10))
        snapshot("05_history")
        goBack(from: "History")

        tap(app.buttons["nav-guide"])
        XCTAssertTrue(app.navigationBars["Guide"].waitForExistence(timeout: 10))
        snapshot("06_guide")
        goBack(from: "Guide")

        tap(app.buttons["nav-settings"])
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))
        snapshot("07_settings")
        goBack(from: "Settings")

        // Program → preview → active workout.
        tap(app.buttons["program-C25K"])
        XCTAssertTrue(app.navigationBars["Couch to 5K"].waitForExistence(timeout: 10))
        snapshot("02_program")

        tap(app.buttons["day-3-3"])   // week 3, day 3 — the next incomplete day
        XCTAssertTrue(app.buttons["start-workout"].waitForExistence(timeout: 10))
        snapshot("03_preview")

        app.buttons["start-workout"].tap()
        XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 20))
        Thread.sleep(forTimeInterval: 2)  // let the elapsed clock tick past 0:00
        snapshot("04_workout")
    }

    // MARK: - Helpers

    private func tap(_ element: XCUIElement, timeout: TimeInterval = 15) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout),
                      "\(element) never appeared")
        if !element.isHittable { app.swipeUp() }
        element.tap()
    }

    private func goBack(from title: String) {
        app.navigationBars[title].buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["C2K"].waitForExistence(timeout: 10))
    }
}

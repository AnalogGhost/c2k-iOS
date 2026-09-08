import XCTest

/// App Store screenshot walkthrough, driven by `fastlane snapshot`
/// (`bundle exec fastlane screenshots`). Launches the app against a seeded
/// in-memory store (`--screenshot-seed`, see `CtoKApp`) and captures one shot
/// per key screen. Navigation is entirely by accessibility identifier so it
/// works in every localisation — it must, since snapshot runs it per language.
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
        // "C2K" is the same in every language (it's the brand, not a localized key).
        XCTAssertTrue(app.navigationBars["C2K"].waitForExistence(timeout: 30))
        XCTAssertTrue(marker("home-streak").waitForExistence(timeout: 5),
                      "Seeded history is missing — ScreenshotSeed did not populate the store")
        snapshot("01_home")

        // History / Guide / Settings are captured before the workout so History shows
        // only the seeded sessions (no incomplete run from the walkthrough).
        tap(app.buttons["nav-history"])
        waitForScreen("screen-history")
        snapshot("05_history")
        goBack()

        tap(app.buttons["nav-guide"])
        waitForScreen("screen-guide")
        snapshot("06_guide")
        goBack()

        tap(app.buttons["nav-settings"])
        waitForScreen("screen-settings")
        snapshot("07_settings")
        goBack()

        // Program grid → preview sheet → active workout.
        tap(app.buttons["program-C25K"])
        XCTAssertTrue(app.buttons["day-3-3"].waitForExistence(timeout: 10))
        snapshot("02_program")

        tap(app.buttons["day-3-3"])            // week 3, day 3 — the next incomplete day
        XCTAssertTrue(app.buttons["start-workout"].waitForExistence(timeout: 10))
        snapshot("03_preview")

        app.buttons["start-workout"].tap()
        XCTAssertTrue(app.buttons["workout-pause"].waitForExistence(timeout: 20))
        Thread.sleep(forTimeInterval: 2)       // let the elapsed clock tick past 0:00
        snapshot("04_workout")
    }

    // MARK: - Helpers

    /// An element carrying `.accessibilityIdentifier(id)`, of whatever type.
    private func marker(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func waitForScreen(_ id: String, timeout: TimeInterval = 10) {
        XCTAssertTrue(marker(id).waitForExistence(timeout: timeout), "\(id) never appeared")
    }

    private func tap(_ element: XCUIElement, timeout: TimeInterval = 15) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "\(element) never appeared")
        if !element.isHittable { app.swipeUp() }
        element.tap()
    }

    /// Taps the leading (back) button of whatever nav bar is showing and waits for Home.
    private func goBack() {
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["C2K"].waitForExistence(timeout: 10))
    }
}

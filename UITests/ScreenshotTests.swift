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
        app.launchArguments += [
            "--screenshot-seed",         // seed deterministic history (CtoKApp)
            "-treadmill_mode", "YES",    // no GPS permission prompt during the run
            "-gps_enabled", "NO",
            "-last_program_id", "C25K",  // Home shows the "continue" shortcut
            "-weight_kg", "70",          // History shows a calorie total
        ]
        app.launch()
    }

    func testScreenshots() {
        // 1 — Home: program list, streak, recent workouts
        XCTAssertTrue(app.navigationBars["C2K"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.staticTexts["home-streak"].waitForExistence(timeout: 5),
                      "Seeded history is missing — ScreenshotSeed did not populate the store")
        snapshot("01_Home")

        // 2 — Program: week/day grid with progress
        tap(app.buttons["program-C25K"])
        XCTAssertTrue(app.navigationBars["Couch to 5K"].waitForExistence(timeout: 10))
        snapshot("02_Program")

        // 3 — Workout preview sheet (week 3, day 3 — the next incomplete day)
        tap(app.buttons["day-3-3"])
        XCTAssertTrue(app.buttons["start-workout"].waitForExistence(timeout: 10))
        snapshot("03_Preview")

        // 4 — Active workout
        app.buttons["start-workout"].tap()
        XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 20))
        Thread.sleep(forTimeInterval: 2)  // let the elapsed clock tick past 0:00
        snapshot("04_Workout")

        endWorkout()

        // 5 — History: totals and session list
        tap(app.buttons["nav-history"])
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 10))
        snapshot("05_History")
        goBack(from: "History")

        // 6 — Guide (FAQ)
        tap(app.buttons["nav-guide"])
        XCTAssertTrue(app.navigationBars["Guide"].waitForExistence(timeout: 10))
        snapshot("06_Guide")
        goBack(from: "Guide")

        // 7 — Settings
        tap(app.buttons["nav-settings"])
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))
        snapshot("07_Settings")
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

    private func endWorkout() {
        app.buttons["Stop"].firstMatch.tap()
        let sheet = app.sheets.firstMatch
        if sheet.waitForExistence(timeout: 3) {
            sheet.buttons["Stop"].tap()
        } else {
            app.buttons["Stop"].firstMatch.tap()
        }
        XCTAssertTrue(app.navigationBars["C2K"].waitForExistence(timeout: 10))
    }
}

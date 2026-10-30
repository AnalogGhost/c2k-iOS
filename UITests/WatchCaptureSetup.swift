import XCTest

/// Prepares the paired iPhone simulator for Tools/StoreScreenshots/capture-watch.sh: turns on
/// "Also notify smartwatch" (allowing notifications when iOS asks), then locks the phone, since
/// iOS only hands notifications to the watch while the phone is locked. Only that script runs it.
final class WatchCaptureSetup: XCTestCase {
    func testAllowNotificationsThenLock() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["nav-settings"].tap()

        let vibrate = app.switches["Vibrate on interval change"]
        scroll(app, to: vibrate)
        if (vibrate.value as? String) == "0" { vibrate.switches.firstMatch.tap() }

        let cues = app.switches["settings-smartwatch-cues"]
        scroll(app, to: cues)
        if (cues.value as? String) == "0" {
            cues.switches.firstMatch.tap()
            let allow = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.buttons.element(boundBy: 1)
            if allow.waitForExistence(timeout: 10) { allow.tap() }
        }
        XCTAssertTrue(NSPredicate(format: "value == '1'").evaluate(with: cues) || waitForOn(cues),
                      "notification permission was not granted")

        XCUIDevice.shared.perform(NSSelectorFromString("pressLockButton"))
        sleep(2)
        // The script waits for this file before it starts sending cues.
        if let marker = ProcessInfo.processInfo.environment["WATCH_CAPTURE_MARKER"] {
            FileManager.default.createFile(atPath: marker, contents: Data())
        }
    }

    private func waitForOn(_ element: XCUIElement) -> Bool {
        let on = expectation(for: NSPredicate(format: "value == '1'"), evaluatedWith: element)
        return XCTWaiter().wait(for: [on], timeout: 5) == .completed
    }

    private func scroll(_ app: XCUIApplication, to element: XCUIElement) {
        var swipes = 0
        while !element.isHittable && swipes < 8 { app.swipeUp(); swipes += 1 }
    }
}

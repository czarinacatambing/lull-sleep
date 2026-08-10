import XCTest

final class HoldToConfirmUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "--uitest-completed-onboarding",
            "--uitest-hold-confirm-fixture",
        ]
        app.launchEnvironment = [
            "UITEST_COMPLETED_ONBOARDING": "1",
            "UITEST_HOLD_CONFIRM_FIXTURE": "1",
        ]
    }

    func testShortHoldDoesNotCompleteAndFullHoldCompletesHero() {
        app.launch()

        XCTAssertTrue(
            app.descendants(matching: .any)["uitest-hold-fixture-active"].waitForExistence(timeout: 12)
        )

        let paywallClose = app.buttons["Close"]
        if paywallClose.waitForExistence(timeout: 2) {
            paywallClose.tap()
            XCTAssertFalse(paywallClose.waitForExistence(timeout: 3))
        }

        let heroLabel = app.staticTexts["Dim lights"]
        XCTAssertTrue(heroLabel.waitForExistence(timeout: 10))

        let hold = app.buttons["today-hero-hold-confirm"]
        XCTAssertTrue(hold.waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["today-hero-slip"].exists)
        XCTAssertTrue(hold.label.contains("Hold 3 sec to confirm"))
        XCTAssertTrue(hold.isHittable)

        let done = app.descendants(matching: .any)["today-done-dimLights"]
        let holdCenter = hold.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        holdCenter.press(forDuration: 0.5)
        XCTAssertFalse(done.exists, "A short hold must not complete the rule")
        XCTAssertTrue(hold.waitForExistence(timeout: 2))

        holdCenter.press(forDuration: 3.2)
        let readyForSleep = app.staticTexts["Ready for sleep"]
        XCTAssertTrue(
            done.waitForExistence(timeout: 4) || readyForSleep.waitForExistence(timeout: 4),
            "A full hold must complete the visible hero and advance the queue"
        )
    }
}

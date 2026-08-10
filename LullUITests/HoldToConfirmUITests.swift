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

    func testHoldToConfirmHeroShowsRequiredControls() {
        app.launch()

        XCTAssertTrue(
            app.descendants(matching: .any)["uitest-hold-fixture-active"].waitForExistence(timeout: 12)
        )

        let heroLabel = app.staticTexts["Dim lights"]
        XCTAssertTrue(heroLabel.waitForExistence(timeout: 10))

        let hold = app.descendants(matching: .any)["today-hero-hold-confirm"]
        XCTAssertTrue(hold.waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["today-hero-slip"].exists)
        XCTAssertTrue(hold.label.contains("Hold 3 sec to confirm"))
    }
}

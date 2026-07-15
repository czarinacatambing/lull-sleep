import XCTest

final class NavigationSmokeUITests: XCTestCase {
    func testMainTabsShowTrendsInsteadOfInsights() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-completed-onboarding"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Trends"].exists)
        XCTAssertTrue(app.staticTexts["Rules"].exists)
        XCTAssertFalse(app.staticTexts["Routine"].exists)
        XCTAssertFalse(app.staticTexts["Insights"].exists)
    }
}

import XCTest

final class NavigationSmokeUITests: XCTestCase {
    func testFreshInstallShowsWelcomeThenCurrentOnboarding() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-fresh-install"]
        app.launchEnvironment = ["UITEST_FRESH_INSTALL": "1"]
        app.launch()

        let start = app.buttons["Help me sleep"]
        XCTAssertTrue(start.waitForExistence(timeout: 8))
        XCTAssertFalse(app.staticTexts["Today"].exists)
        XCTAssertFalse(app.staticTexts["Routine"].exists)
        XCTAssertFalse(app.staticTexts["Insights"].exists)

        start.tap()

        let sleepThiefHeading = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'What steals'")
        ).firstMatch
        XCTAssertTrue(sleepThiefHeading.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Routine"].exists)
        XCTAssertFalse(app.staticTexts["Insights"].exists)
    }

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

    func testTrendsUsesSharedFireflyCalendarScene() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-completed-onboarding", "--uitest-start-trends"]
        app.launchEnvironment = ["UITEST_START_TRENDS": "1"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Trends"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.otherElements["shared-firefly-scene-calendar"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.otherElements["shared-firefly-scene-cluster"].exists)
    }
}

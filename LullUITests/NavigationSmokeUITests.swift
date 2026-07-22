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

    func testTrendsCalendarSceneScrollsWithContent() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-completed-onboarding"]
        app.launch()

        XCTAssertTrue(app.otherElements["shared-firefly-scene-cluster"].waitForExistence(timeout: 8))

        app.buttons["Trends"].tap()

        XCTAssertTrue(app.staticTexts["Trends"].waitForExistence(timeout: 4))
        let calendarScene = app.otherElements["trends-firefly-calendar-scene"]
        XCTAssertTrue(calendarScene.waitForExistence(timeout: 4))
        XCTAssertFalse(app.otherElements["shared-firefly-scene-cluster"].exists)

        let initialY = calendarScene.frame.minY
        app.swipeUp()
        XCTAssertLessThan(calendarScene.frame.minY, initialY - 20)
    }
}

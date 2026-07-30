import XCTest

final class WaterUpUITests: XCTestCase {
    @MainActor
    func testPrimaryTabsAreVisible() {
        let app = makeApp()

        XCTAssertTrue(app.tabBars.buttons["今日"].exists)
        XCTAssertTrue(app.tabBars.buttons["历史"].exists)
        XCTAssertTrue(app.tabBars.buttons["设置"].exists)
    }

    @MainActor
    func testQuickAddAndUndoRestoresTheTodayEmptyState() {
        let app = makeApp()
        let firstWaterButton = app.buttons["waterup.today.first-water"]

        XCTAssertTrue(firstWaterButton.waitForExistence(timeout: 3))
        firstWaterButton.tap()

        let undoButton = app.buttons["撤销"]
        XCTAssertTrue(undoButton.waitForExistence(timeout: 3))
        undoButton.tap()

        XCTAssertTrue(firstWaterButton.waitForExistence(timeout: 3))
    }

    @MainActor
    private func makeApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        return app
    }
}

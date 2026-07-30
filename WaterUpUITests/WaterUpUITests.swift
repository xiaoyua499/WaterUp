import XCTest

final class WaterUpUITests: XCTestCase {
    func testPrimaryTabsAreVisible() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["今日"].exists)
        XCTAssertTrue(app.tabBars.buttons["历史"].exists)
        XCTAssertTrue(app.tabBars.buttons["设置"].exists)
    }
}

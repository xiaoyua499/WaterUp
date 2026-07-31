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
        let quickWaterButton = app.buttons["waterup.today.quick-add.water"]

        tapWhenVisible(quickWaterButton, in: app)

        let recordRow = app.buttons["waterup.today.record-row"]
        XCTAssertTrue(recordRow.waitForExistence(timeout: 3))

        let undoButton = app.buttons["撤销"]
        XCTAssertTrue(undoButton.waitForExistence(timeout: 3))
        undoButton.tap()

        XCTAssertTrue(recordRow.waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["还没有饮水记录"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testCreateRecordOpensDetailAndCanBeDeleted() {
        let app = makeApp()
        let createButton = app.buttons["waterup.today.record-drink"]
        tapWhenVisible(createButton, in: app)

        let saveButton = app.buttons["waterup.record.save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3))
        saveButton.tap()

        let recordRow = app.buttons["waterup.today.record-row"]
        XCTAssertTrue(recordRow.waitForExistence(timeout: 3))
        tapWhenVisible(recordRow, in: app)

        let deleteButton = app.buttons["waterup.record.detail-delete"]
        tapWhenVisible(deleteButton, in: app)

        let confirmDeleteButton = app.buttons["确认删除"]
        XCTAssertTrue(confirmDeleteButton.waitForExistence(timeout: 3))
        confirmDeleteButton.tap()

        XCTAssertTrue(recordRow.waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["还没有饮水记录"].waitForExistence(timeout: 3))
    }

    @MainActor
    private func makeApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        return app
    }

    @MainActor
    private func tapWhenVisible(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<6 {
            if element.waitForExistence(timeout: 1), element.isHittable {
                element.tap()
                return
            }

            app.swipeUp()
        }

        XCTFail("未找到可点击元素：\(element)")
    }
}

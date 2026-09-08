import XCTest

final class HistoryCalendarRegressionTests: XCTestCase {
    @MainActor
    func testMonthsBeforeFirstGoalRemainNavigableAndReturnToRecordedDay() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        let quickAdd = app.buttons["waterup.today.quick-add.water"]
        XCTAssertTrue(quickAdd.waitForExistence(timeout: 5))
        quickAdd.tap()
        app.tabBars.buttons["历史"].tap()

        let previous = app.buttons["waterup.history.previous-month"]
        let next = app.buttons["waterup.history.next-month"]
        XCTAssertTrue(previous.waitForExistence(timeout: 5))
        capture("05-fixed-current-month")
        previous.tap()
        XCTAssertTrue(app.staticTexts["这一天没有饮水记录"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["历史记录暂时无法读取"].exists)
        XCTAssertTrue(next.isHittable)
        capture("05-fixed-before-first-goal")
        app.swipeUp()
        capture("05-fixed-empty-card")
        app.swipeDown()
        previous.tap()
        XCTAssertTrue(app.staticTexts["这一天没有饮水记录"].exists)
        next.tap()
        next.tap()
        XCTAssertFalse(app.staticTexts["历史记录暂时无法读取"].exists)
        XCTAssertTrue(app.staticTexts["目标饮水"].waitForExistence(timeout: 5))
        capture("05-fixed-return-to-records")
        app.swipeUp()
        capture("05-fixed-record-metrics")
        let dayDetail = app.buttons["waterup.history.day-detail"]
        if !dayDetail.isHittable { app.swipeUp() }
        dayDetail.tap()
        XCTAssertTrue(app.staticTexts["单日明细"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars.buttons.firstMatch.isHittable)
        app.navigationBars.buttons.firstMatch.tap()
        app.swipeDown()
        next.tap()
        XCTAssertTrue(app.staticTexts["请选择一个日期"].waitForExistence(timeout: 5))
        previous.tap()
        XCTAssertTrue(app.staticTexts["目标饮水"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIApplication().screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

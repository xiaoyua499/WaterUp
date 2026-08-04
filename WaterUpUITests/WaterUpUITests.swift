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
    func testGoalSettingsSupportsNumericInputAndQuickTargets() {
        let app = makeApp()
        app.tabBars.buttons["设置"].tap()

        let dailyGoal = app.buttons["waterup.settings.daily-goal"]
        tapWhenVisible(dailyGoal, in: app)

        let targetInput = app.descendants(matching: .any)["waterup.goal.target-input"]
        XCTAssertTrue(targetInput.waitForExistence(timeout: 3))
        targetInput.tap()
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 3))

        targetInput.typeText("1")
        XCTAssertTrue(
            app.staticTexts["请输入 500–5000 mL 之间且为 100 mL 步长的目标"]
                .waitForExistence(timeout: 3)
        )

        let quickTarget = app.buttons["waterup.goal.quick-2500"]
        tapWhenVisible(quickTarget, in: app)
        XCTAssertEqual(targetInput.value as? String, "2500")
        XCTAssertTrue(app.buttons["waterup.goal.save"].isEnabled)
    }

    @MainActor
    func testDrinkManagementShowsAllBuiltInDrinksAndSupportsUnlimitedFavorites() {
        let app = makeApp()
        app.tabBars.buttons["设置"].tap()

        let drinkManagement = app.buttons["waterup.settings.drink-management"]
        tapWhenVisible(drinkManagement, in: app)

        XCTAssertTrue(app.staticTexts["饮品管理"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["常用饮品 4"].waitForExistence(timeout: 3))

        for seedKey in ["water", "tea", "coffee", "milk", "juice", "soda", "sport"] {
            XCTAssertTrue(
                app.buttons["waterup.drink-management.edit.\(seedKey)"].waitForExistence(timeout: 3)
            )
        }

        for seedKey in ["juice", "soda", "sport"] {
            let drinkRow = app.buttons["waterup.drink-management.edit.\(seedKey)"]
            tapWhenVisible(drinkRow, in: app)

            let favoriteToggle = app.switches["waterup.drink-editor.favorite"]
            XCTAssertTrue(favoriteToggle.waitForExistence(timeout: 3))
            favoriteToggle.tap()

            tapWhenVisible(app.buttons["waterup.drink-editor.save"], in: app)
        }
        XCTAssertTrue(app.staticTexts["常用饮品 7"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testCreateCustomDrinkSupportsIconSelection() {
        let app = makeApp()
        app.tabBars.buttons["设置"].tap()

        let drinkManagement = app.buttons["waterup.settings.drink-management"]
        tapWhenVisible(drinkManagement, in: app)

        let addCustom = app.buttons["waterup.drink-management.add-custom"]
        tapWhenVisible(addCustom, in: app)

        let nameField = app.textFields["waterup.drink-editor.name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.tap()
        nameField.typeText("柠檬茶")

        let appearance = app.buttons["waterup.drink-editor.appearance"]
        tapWhenVisible(appearance, in: app)
        let teaIcon = app.buttons["waterup.drink-editor.icon.DrinkTea"]
        tapWhenVisible(teaIcon, in: app)
        tapWhenVisible(app.buttons["waterup.drink-editor.appearance.done"], in: app)

        let saveButton = app.buttons["waterup.drink-editor.save"]
        tapWhenVisible(saveButton, in: app)
        XCTAssertTrue(app.staticTexts["柠檬茶"].waitForExistence(timeout: 3))

        let editCustom = app.buttons["编辑柠檬茶"]
        tapWhenVisible(editCustom, in: app)
        XCTAssertTrue(app.staticTexts["自定义饮品"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.textFields["waterup.drink-editor.name"].isEnabled)
        XCTAssertTrue(app.textFields["waterup.drink-editor.water-ratio"].isEnabled)
        XCTAssertTrue(app.textFields["waterup.drink-editor.default-volume"].isEnabled)
    }

    @MainActor
    func testBuiltInDrinkEditorOnlyAllowsDefaultVolume() {
        let app = makeApp()
        app.tabBars.buttons["设置"].tap()

        let drinkManagement = app.buttons["waterup.settings.drink-management"]
        tapWhenVisible(drinkManagement, in: app)

        let editWater = app.buttons["waterup.drink-management.edit.water"]
        tapWhenVisible(editWater, in: app)

        XCTAssertTrue(app.staticTexts["编辑饮品"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.textFields["waterup.drink-editor.name"].isEnabled)
        XCTAssertFalse(app.textFields["waterup.drink-editor.water-ratio"].isEnabled)
        XCTAssertTrue(app.textFields["waterup.drink-editor.default-volume"].isEnabled)
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

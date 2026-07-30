import XCTest
import SwiftData
@testable import WaterUp

final class WaterUpTests: XCTestCase {
    func testPrimaryTabsUseDistinctTitles() {
        let tabs: [AppTab] = [.today, .history, .settings]
        let titles = Set(tabs.map(\.title))

        XCTAssertEqual(titles.count, 3)
    }

    func testDesignTokensMatchApprovedBaseline() {
        XCTAssertEqual(
            WaterUpTheme.Palette.backgroundBase,
            WaterUpColorToken(red: 244, green: 248, blue: 255)
        )
        XCTAssertEqual(
            WaterUpTheme.Palette.actionPrimary,
            WaterUpColorToken(red: 62, green: 152, blue: 245)
        )
        XCTAssertEqual(
            WaterUpTheme.Palette.statusError,
            WaterUpColorToken(red: 232, green: 94, blue: 104)
        )
        XCTAssertEqual(WaterUpTheme.Spacing.pageHorizontal, 20)
        XCTAssertEqual(WaterUpTheme.Radius.large, 24)
        XCTAssertEqual(WaterUpTheme.Layout.minimumTapTarget, 44)
        XCTAssertEqual(WaterUpTheme.Motion.progressDuration, 0.5)
        XCTAssertEqual(WaterUpTheme.Motion.confirmationDuration, 0.2)
        XCTAssertEqual(WaterUpTheme.Motion.undoTimeout, 5)
    }

    func testDrinkAssetKeysAreUnique() {
        let assetNames = WaterUpAsset.drinkNames

        XCTAssertEqual(Set(assetNames).count, assetNames.count)
    }

    func testEffectiveHydrationUsesIntegerRounding() throws {
        XCTAssertEqual(
            try HydrationCalculator.effectiveHydrationML(
                volumeML: 333,
                waterRatioPercent: 87
            ),
            290
        )
        XCTAssertEqual(
            try HydrationCalculator.effectiveHydrationML(
                volumeML: 300,
                waterRatioPercent: 0
            ),
            0
        )
    }

    func testEffectiveHydrationRejectsInvalidInput() {
        XCTAssertThrowsError(
            try HydrationCalculator.effectiveHydrationML(
                volumeML: 0,
                waterRatioPercent: 100
            )
        )
        XCTAssertThrowsError(
            try HydrationCalculator.effectiveHydrationML(
                volumeML: 250,
                waterRatioPercent: 101
            )
        )
    }

    func testBootstrapSeedsDataOnlyOnce() throws {
        let calendar = makeCalendar(timeZoneIdentifier: "Asia/Shanghai")
        let now = makeDate(
            year: 2026,
            month: 7,
            day: 30,
            hour: 9,
            calendar: calendar
        )
        let container = try WaterUpModelContainer.make(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let bootstrap = BootstrapService(
            dateBoundary: DateBoundaryService(calendar: calendar)
        )

        try bootstrap.initialize(in: context, now: now)
        try bootstrap.initialize(in: context, now: now)

        let metadata = try context.fetch(FetchDescriptor<AppMetadata>())
        let goals = try context.fetch(FetchDescriptor<DailyGoalChange>())
        let reminders = try context.fetch(FetchDescriptor<ReminderConfiguration>())
        let drinks = try context.fetch(FetchDescriptor<DrinkDefinition>())
        let favorites = drinks
            .filter(\.isFavorite)
            .sorted { left, right in
                guard let leftOrder = left.favoriteOrder,
                      let rightOrder = right.favoriteOrder else {
                    return false
                }

                return leftOrder < rightOrder
            }
        let reminder = try XCTUnwrap(reminders.first)

        XCTAssertEqual(metadata.count, 1)
        XCTAssertEqual(metadata.first?.firstUseDayKey, "2026-07-30")
        XCTAssertEqual(goals.count, 1)
        XCTAssertEqual(goals.first?.targetML, 2_000)
        XCTAssertEqual(reminders.count, 1)
        XCTAssertFalse(reminder.isEnabled)
        XCTAssertEqual(reminder.startMinuteOfDay, 9 * 60)
        XCTAssertEqual(reminder.endMinuteOfDay, 21 * 60)
        XCTAssertEqual(reminder.intervalMinutes, 120)
        XCTAssertEqual(drinks.count, 7)
        XCTAssertEqual(favorites.map(\.seedKey), ["water", "tea", "coffee", "milk"])

        let water = try XCTUnwrap(drinks.first { $0.seedKey == "water" })
        let milk = try XCTUnwrap(drinks.first { $0.seedKey == "milk" })
        XCTAssertEqual(water.waterRatioPercent, 100)
        XCTAssertEqual(water.defaultVolumeML, 250)
        XCTAssertEqual(milk.waterRatioPercent, 87)
        XCTAssertEqual(milk.defaultVolumeML, 250)
    }

    func testGoalUpsertPreservesHistoricalGoal() throws {
        let calendar = makeCalendar(timeZoneIdentifier: "Asia/Shanghai")
        let yesterday = makeDate(
            year: 2026,
            month: 7,
            day: 29,
            hour: 9,
            calendar: calendar
        )
        let today = makeDate(
            year: 2026,
            month: 7,
            day: 30,
            hour: 9,
            calendar: calendar
        )
        let container = try WaterUpModelContainer.make(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let dateBoundary = DateBoundaryService(calendar: calendar)
        let bootstrap = BootstrapService(dateBoundary: dateBoundary)
        let goalService = GoalService(dateBoundary: dateBoundary)

        try bootstrap.initialize(in: context, now: yesterday)
        try goalService.upsertToday(targetML: 2_500, now: today, in: context)
        try PersistenceService.saveChanges(in: context)

        XCTAssertEqual(try goalService.goal(for: yesterday, in: context).targetML, 2_000)
        XCTAssertEqual(try goalService.goal(for: today, in: context).targetML, 2_500)

        try goalService.upsertToday(targetML: 3_000, now: today, in: context)
        try PersistenceService.saveChanges(in: context)

        let goals = try context.fetch(FetchDescriptor<DailyGoalChange>())
        XCTAssertEqual(goals.count, 2)
        XCTAssertEqual(try goalService.goal(for: today, in: context).targetML, 3_000)
    }

    func testDayRangeFollowsLocalCalendarInsteadOfFixedTwentyFourHours() throws {
        let calendar = makeCalendar(timeZoneIdentifier: "America/New_York")
        let daylightSavingDate = makeDate(
            year: 2024,
            month: 3,
            day: 10,
            hour: 12,
            calendar: calendar
        )
        let dateBoundary = DateBoundaryService(calendar: calendar)
        let range = try XCTUnwrap(dateBoundary.dayRange(for: daylightSavingDate))

        XCTAssertEqual(range.duration, 23 * 60 * 60)
        XCTAssertEqual(dateBoundary.dayKey(for: daylightSavingDate), "2024-03-10")
    }

    func testSummaryDerivesValuesFromRecordsWithoutPersistingTotals() throws {
        let calendar = makeCalendar(timeZoneIdentifier: "Asia/Shanghai")
        let now = makeDate(
            year: 2026,
            month: 7,
            day: 30,
            hour: 12,
            calendar: calendar
        )
        let container = try WaterUpModelContainer.make(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let dateBoundary = DateBoundaryService(calendar: calendar)
        let bootstrap = BootstrapService(dateBoundary: dateBoundary)

        try bootstrap.initialize(in: context, now: now)

        let record = HydrationRecord(
            drinkID: UUID(),
            drinkNameSnapshot: "牛奶",
            categorySnapshot: DrinkCategory.dairy.rawValue,
            waterRatioPercentSnapshot: 87,
            colorTokenSnapshot: "purple",
            iconKeySnapshot: WaterUpAsset.Drink.milk,
            volumeML: 333,
            effectiveHydrationML: 290,
            consumedAt: now,
            createdAt: now,
            updatedAt: now
        )
        context.insert(record)
        try PersistenceService.saveChanges(in: context)

        let summary = try HydrationSummaryService(dateBoundary: dateBoundary)
            .summary(for: now, in: context)

        XCTAssertEqual(summary.targetML, 2_000)
        XCTAssertEqual(summary.totalVolumeML, 333)
        XCTAssertEqual(summary.totalEffectiveHydrationML, 290)
        XCTAssertEqual(summary.remainingML, 1_710)
        XCTAssertEqual(summary.progress, 0.145)
        XCTAssertEqual(summary.ringProgress, 0.145)
    }

    private func makeCalendar(timeZoneIdentifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier)!
        return calendar
    }

    private func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        calendar: Calendar
    ) -> Date {
        calendar.date(
            from: DateComponents(
                year: year,
                month: month,
                day: day,
                hour: hour
            )
        )!
    }
}

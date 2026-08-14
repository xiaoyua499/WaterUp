import Foundation
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

    func testBuiltInDrinkCatalogMatchesApprovedBaseline() throws {
        let now = makeDate(
            year: 2026,
            month: 7,
            day: 30,
            hour: 9,
            calendar: makeCalendar(timeZoneIdentifier: "Asia/Shanghai")
        )
        let container = try WaterUpModelContainer.make(isStoredInMemoryOnly: true)
        let context = ModelContext(container)

        try BootstrapService().initialize(in: context, now: now)

        let catalog = try DrinkCatalogService().activeCatalog(in: context)
        let values = catalog.builtIn.map { drink in
            (
                drink.seedKey,
                drink.name,
                drink.waterRatioPercent,
                drink.defaultVolumeML,
                drink.sourceRawValue,
                drink.statusRawValue
            )
        }

        XCTAssertEqual(values.count, 7)
        XCTAssertEqual(
            values.map { $0.0 },
            ["water", "tea", "coffee", "milk", "juice", "soda", "sport"]
        )
        XCTAssertEqual(
            values.map { $0.1 },
            ["饮用水", "茶", "咖啡", "牛奶", "果汁", "碳酸饮料", "运动饮料"]
        )
        XCTAssertEqual(values.map { $0.2 }, [100, 99, 99, 87, 88, 90, 94])
        XCTAssertEqual(values.map { $0.3 }, [250, 300, 250, 250, 250, 330, 500])
        XCTAssertTrue(values.allSatisfy { $0.4 == DrinkSource.builtIn.rawValue && $0.5 == DrinkStatus.active.rawValue })
    }

    func testFavoriteDrinkServiceAllowsAnyNumberOfFavoritesAndKeepsOrder() throws {
        let now = makeDate(
            year: 2026,
            month: 7,
            day: 30,
            hour: 9,
            calendar: makeCalendar(timeZoneIdentifier: "Asia/Shanghai")
        )
        let container = try WaterUpModelContainer.make(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let bootstrap = BootstrapService()
        let service = FavoriteDrinkService()

        try bootstrap.initialize(in: context, now: now)
        let juice = try fetchDrink(seedKey: "juice", in: context)
        let soda = try fetchDrink(seedKey: "soda", in: context)
        let sport = try fetchDrink(seedKey: "sport", in: context)

        try service.addToFavorites(id: juice.id, in: context)
        try service.addToFavorites(id: soda.id, in: context)

        try service.addToFavorites(id: sport.id, in: context)

        let favorites = try service.favoriteDrinks(in: context)
        XCTAssertEqual(favorites.map(\.seedKey), ["water", "tea", "coffee", "milk", "juice", "soda", "sport"])
        XCTAssertEqual(favorites.map(\.favoriteOrder), [0, 1, 2, 3, 4, 5, 6])
    }

    func testRemovingFavoriteCompactsOrderAndArchivingCustomDrinkRemovesFavorite() throws {
        let now = makeDate(
            year: 2026,
            month: 7,
            day: 30,
            hour: 9,
            calendar: makeCalendar(timeZoneIdentifier: "Asia/Shanghai")
        )
        let container = try WaterUpModelContainer.make(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let bootstrap = BootstrapService()
        let service = FavoriteDrinkService()

        try bootstrap.initialize(in: context, now: now)
        let tea = try fetchDrink(seedKey: "tea", in: context)
        let custom = DrinkDefinition(
            name: "柠檬水",
            category: .water,
            waterRatioPercent: 95,
            defaultVolumeML: 300,
            colorToken: "blue",
            iconKey: WaterUpAsset.Drink.custom,
            source: .custom,
            isFavorite: true,
            favoriteOrder: 4,
            createdAt: now,
            updatedAt: now
        )
        context.insert(custom)
        try PersistenceService.saveChanges(in: context)

        try service.removeFromFavorites(id: tea.id, in: context)

        let favoritesAfterRemoval = try service.favoriteDrinks(in: context)
        XCTAssertEqual(favoritesAfterRemoval.map(\.seedKey), ["water", "coffee", "milk", nil])
        XCTAssertEqual(favoritesAfterRemoval.map(\.favoriteOrder), [0, 1, 2, 3])

        try service.archiveCustomDrink(id: custom.id, in: context)

        XCTAssertEqual(custom.status, .archived)
        XCTAssertFalse(custom.isFavorite)
        XCTAssertNil(custom.favoriteOrder)
        XCTAssertEqual(try service.favoriteCount(in: context), 3)
    }

    func testBuiltInDrinkCannotBeArchived() throws {
        let now = makeDate(
            year: 2026,
            month: 7,
            day: 30,
            hour: 9,
            calendar: makeCalendar(timeZoneIdentifier: "Asia/Shanghai")
        )
        let container = try WaterUpModelContainer.make(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        try BootstrapService().initialize(in: context, now: now)

        let water = try fetchDrink(seedKey: "water", in: context)

        XCTAssertThrowsError(try FavoriteDrinkService().archiveCustomDrink(id: water.id, in: context)) { error in
            XCTAssertEqual(error as? FavoriteDrinkServiceError, .builtInDrinkCannotBeArchived)
        }
        XCTAssertEqual(water.status, .active)
        XCTAssertTrue(water.isFavorite)
    }

    func testCreateCustomDrinkTrimsNamePersistsIconAndAllowsZeroHydrationRatio() throws {
        let now = makeDate(
            year: 2026,
            month: 7,
            day: 30,
            hour: 9,
            calendar: makeCalendar(timeZoneIdentifier: "Asia/Shanghai")
        )
        let container = try WaterUpModelContainer.make(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        try BootstrapService().initialize(in: context, now: now)

        var draft = DrinkDraft.newDrink()
        draft.name = "  柠檬茶  "
        draft.categoryRawValue = DrinkCategory.tea.rawValue
        draft.waterRatioText = "0"
        draft.defaultVolumeText = "300"
        draft.colorToken = "purple"
        draft.iconKey = WaterUpAsset.Drink.tea
        draft.isFavorite = true

        let drink = try DrinkService().create(draft: draft, now: now, in: context)

        XCTAssertEqual(drink.name, "柠檬茶")
        XCTAssertEqual(drink.category, .tea)
        XCTAssertEqual(drink.waterRatioPercent, 0)
        XCTAssertEqual(drink.defaultVolumeML, 300)
        XCTAssertEqual(drink.colorToken, "purple")
        XCTAssertEqual(drink.iconKey, WaterUpAsset.Drink.tea)
        XCTAssertEqual(drink.source, .custom)
        XCTAssertTrue(drink.isFavorite)
        XCTAssertEqual(try FavoriteDrinkService().favoriteCount(in: context), 5)
    }

    func testDrinkDraftValidatesNameRatioAndVolumeRules() {
        var draft = DrinkDraft.newDrink()
        draft.name = " "
        draft.waterRatioText = "101"
        draft.defaultVolumeText = "2001"

        XCTAssertEqual(
            draft.validationErrors,
            [.emptyName, .invalidWaterRatio, .invalidDefaultVolume]
        )

        draft.name = String(repeating: "饮", count: 21)
        draft.waterRatioText = "0"
        draft.defaultVolumeText = "1"
        XCTAssertEqual(draft.validationErrors, [.nameTooLong])
    }

    func testBuiltInDrinkOnlyUpdatesDefaultVolumeAndKeepsHistoricalSnapshot() throws {
        let now = makeDate(
            year: 2026,
            month: 7,
            day: 30,
            hour: 9,
            calendar: makeCalendar(timeZoneIdentifier: "Asia/Shanghai")
        )
        let container = try WaterUpModelContainer.make(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        try BootstrapService().initialize(in: context, now: now)

        let water = try fetchDrink(seedKey: "water", in: context)
        let firstRecord = try RecordService().createQuickRecord(
            forDrinkID: water.id,
            at: now,
            in: context
        )
        var draft = DrinkDraft(drink: water)
        draft.name = "不应修改的名称"
        draft.waterRatioText = "80"
        draft.defaultVolumeText = "500"
        draft.iconKey = WaterUpAsset.Drink.tea

        try DrinkService().update(draft: draft, now: now, in: context)

        XCTAssertEqual(water.name, "饮用水")
        XCTAssertEqual(water.waterRatioPercent, 100)
        XCTAssertEqual(water.defaultVolumeML, 500)
        XCTAssertEqual(water.iconKey, WaterUpAsset.Drink.water)

        let historicalRecord = try RecordService().record(id: firstRecord.recordID, in: context)
        XCTAssertEqual(historicalRecord.volumeML, 250)
        XCTAssertEqual(historicalRecord.waterRatioPercentSnapshot, 100)
        XCTAssertEqual(historicalRecord.effectiveHydrationML, 250)

        let nextRecord = try RecordService().createQuickRecord(
            forDrinkID: water.id,
            at: now.addingTimeInterval(60),
            in: context
        )
        XCTAssertEqual(nextRecord.volumeML, 500)
        XCTAssertEqual(nextRecord.effectiveHydrationML, 500)
    }

    func testCustomDrinkCanEditAllFieldsAndNewRecordsUseUpdatedConfiguration() throws {
        let now = makeDate(
            year: 2026,
            month: 7,
            day: 30,
            hour: 9,
            calendar: makeCalendar(timeZoneIdentifier: "Asia/Shanghai")
        )
        let container = try WaterUpModelContainer.make(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        try BootstrapService().initialize(in: context, now: now)

        var createDraft = DrinkDraft.newDrink()
        createDraft.name = "原始饮品"
        createDraft.categoryRawValue = DrinkCategory.other.rawValue
        createDraft.waterRatioText = "90"
        createDraft.defaultVolumeText = "300"
        let drink = try DrinkService().create(draft: createDraft, now: now, in: context)
        let firstRecord = try RecordService().createQuickRecord(
            forDrinkID: drink.id,
            at: now,
            in: context
        )

        var editDraft = DrinkDraft(drink: drink)
        editDraft.name = "更新后的饮品"
        editDraft.categoryRawValue = DrinkCategory.juice.rawValue
        editDraft.waterRatioText = "80"
        editDraft.defaultVolumeText = "400"
        editDraft.colorToken = "red"
        editDraft.iconKey = WaterUpAsset.Drink.sport
        editDraft.isFavorite = true

        try DrinkService().update(draft: editDraft, now: now, in: context)

        XCTAssertEqual(drink.name, "更新后的饮品")
        XCTAssertEqual(drink.category, .juice)
        XCTAssertEqual(drink.waterRatioPercent, 80)
        XCTAssertEqual(drink.defaultVolumeML, 400)
        XCTAssertEqual(drink.colorToken, "red")
        XCTAssertEqual(drink.iconKey, WaterUpAsset.Drink.sport)
        XCTAssertTrue(drink.isFavorite)

        let historicalRecord = try RecordService().record(id: firstRecord.recordID, in: context)
        XCTAssertEqual(historicalRecord.drinkNameSnapshot, "原始饮品")
        XCTAssertEqual(historicalRecord.waterRatioPercentSnapshot, 90)
        XCTAssertEqual(historicalRecord.volumeML, 300)
        XCTAssertEqual(historicalRecord.effectiveHydrationML, 270)

        let nextRecord = try RecordService().createQuickRecord(
            forDrinkID: drink.id,
            at: now.addingTimeInterval(60),
            in: context
        )
        XCTAssertEqual(nextRecord.volumeML, 400)
        XCTAssertEqual(nextRecord.effectiveHydrationML, 320)
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

    func testGoalDraftAllowsBoundaryTargetsAndRejectsInvalidTargets() throws {
        XCTAssertEqual(try GoalDraft(targetML: 500).targetML, 500)
        XCTAssertEqual(try GoalDraft(targetML: 5_000).targetML, 5_000)

        let invalidTargets = [400, 5_100, 550]
        for targetML in invalidTargets {
            XCTAssertThrowsError(try GoalDraft(targetML: targetML)) { error in
                XCTAssertEqual(error as? GoalValidationError, .invalidTargetML)
            }
        }
    }

    func testGoalUpsertAcceptsBoundaryTargets() throws {
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
        let goalService = GoalService(dateBoundary: dateBoundary)

        try BootstrapService(dateBoundary: dateBoundary).initialize(in: context, now: now)
        try goalService.upsertToday(targetML: 500, now: now, in: context)
        XCTAssertEqual(try goalService.goal(for: now, in: context).targetML, 500)

        try goalService.upsertToday(targetML: 5_000, now: now, in: context)
        XCTAssertEqual(try goalService.goal(for: now, in: context).targetML, 5_000)
    }

    func testGoalChangeImmediatelyUpdatesTodayProgress() throws {
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
        let goalService = GoalService(dateBoundary: dateBoundary)

        try BootstrapService(dateBoundary: dateBoundary).initialize(in: context, now: now)
        context.insert(
            HydrationRecord(
                drinkID: UUID(),
                drinkNameSnapshot: "饮用水",
                categorySnapshot: DrinkCategory.water.rawValue,
                waterRatioPercentSnapshot: 100,
                colorTokenSnapshot: "blue",
                iconKeySnapshot: WaterUpAsset.Drink.water,
                volumeML: 1_000,
                effectiveHydrationML: 1_000,
                consumedAt: now,
                createdAt: now,
                updatedAt: now
            )
        )
        try PersistenceService.saveChanges(in: context)

        try goalService.upsertToday(targetML: 2_500, now: now, in: context)
        try PersistenceService.saveChanges(in: context)

        let summary = try HydrationSummaryService(dateBoundary: dateBoundary)
            .summary(for: now, in: context)
        XCTAssertEqual(summary.targetML, 2_500)
        XCTAssertEqual(summary.totalEffectiveHydrationML, 1_000)
        XCTAssertEqual(summary.progress, 0.4)
    }

    func testInvalidGoalSavePreservesStoredGoal() throws {
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
        let goalService = GoalService(dateBoundary: dateBoundary)

        try BootstrapService(dateBoundary: dateBoundary).initialize(in: context, now: now)

        XCTAssertThrowsError(
            try goalService.upsertToday(targetML: 550, now: now, in: context)
        )
        XCTAssertEqual(try goalService.goal(for: now, in: context).targetML, 2_000)
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

    func testQuickRecordUsesCurrentDrinkConfigurationAndPreservesSnapshot() throws {
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
        let favoriteDrinkService = FavoriteDrinkService()

        try bootstrap.initialize(in: context, now: now)

        let water = try XCTUnwrap(
            favoriteDrinkService.activeBuiltInWater(in: context)
        )
        let result = try RecordService().createQuickRecord(
            forDrinkID: water.id,
            at: now,
            in: context
        )

        water.name = "山泉水"
        water.waterRatioPercent = 95
        water.defaultVolumeML = 300
        try PersistenceService.saveChanges(in: context)

        let records = try HydrationRecordQueryService(dateBoundary: dateBoundary)
            .records(on: now, in: context)
        let record = try XCTUnwrap(records.first)
        let dashboard = try TodayDashboardService(dateBoundary: dateBoundary)
            .dashboard(for: now, in: context)

        XCTAssertEqual(result.volumeML, 250)
        XCTAssertEqual(result.effectiveHydrationML, 250)
        XCTAssertEqual(record.id, result.recordID)
        XCTAssertEqual(record.drinkNameSnapshot, "饮用水")
        XCTAssertEqual(record.waterRatioPercentSnapshot, 100)
        XCTAssertEqual(record.volumeML, 250)
        XCTAssertEqual(record.effectiveHydrationML, 250)
        XCTAssertEqual(dashboard.summary.totalEffectiveHydrationML, 250)
        XCTAssertEqual(dashboard.records.count, 1)
        XCTAssertEqual(dashboard.favoriteDrinks.first?.name, "山泉水")
    }

    func testQuickRecordUndoDeletesOnlyTheSpecifiedRecord() throws {
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

        let water = try XCTUnwrap(
            try FavoriteDrinkService().activeBuiltInWater(in: context)
        )
        let tea = try fetchDrink(seedKey: "tea", in: context)
        let recordService = RecordService()
        let waterResult = try recordService.createQuickRecord(
            forDrinkID: water.id,
            at: now,
            in: context
        )
        let teaResult = try recordService.createQuickRecord(
            forDrinkID: tea.id,
            at: now.addingTimeInterval(60),
            in: context
        )

        try recordService.deleteRecord(id: teaResult.recordID, in: context)

        let records = try HydrationRecordQueryService(dateBoundary: dateBoundary)
            .records(on: now, in: context)
        let summary = try HydrationSummaryService(dateBoundary: dateBoundary)
            .summary(for: now, in: context)

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.id, waterResult.recordID)
        XCTAssertEqual(summary.totalVolumeML, 250)
        XCTAssertEqual(summary.totalEffectiveHydrationML, 250)
    }

    func testTodayDashboardLimitsFavoritesToSixAndExcludesArchivedDrinks() throws {
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

        context.insert(
            makeFavoriteDrink(
                name: "柠檬水",
                favoriteOrder: 4,
                now: now
            )
        )
        context.insert(
            makeFavoriteDrink(
                name: "苏打水",
                favoriteOrder: 5,
                now: now
            )
        )
        context.insert(
            makeFavoriteDrink(
                name: "第七杯",
                favoriteOrder: 6,
                now: now
            )
        )
        context.insert(
            DrinkDefinition(
                name: "已归档饮品",
                category: .other,
                waterRatioPercent: 80,
                defaultVolumeML: 250,
                colorToken: "gray",
                iconKey: WaterUpAsset.Drink.custom,
                source: .custom,
                status: .archived,
                isFavorite: true,
                favoriteOrder: 0,
                createdAt: now,
                updatedAt: now
            )
        )
        try PersistenceService.saveChanges(in: context)

        let dashboard = try TodayDashboardService(dateBoundary: dateBoundary)
            .dashboard(for: now, in: context)

        XCTAssertEqual(dashboard.favoriteDrinks.count, 6)
        XCTAssertEqual(
            dashboard.favoriteDrinks.map(\.name),
            ["饮用水", "茶", "咖啡", "牛奶", "柠檬水", "苏打水"]
        )
        XCTAssertFalse(dashboard.favoriteDrinks.contains { $0.name == "已归档饮品" })
    }

    func testTodayDashboardPreservesRealProgressAboveOneHundredPercent() throws {
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
        context.insert(
            HydrationRecord(
                drinkID: UUID(),
                drinkNameSnapshot: "饮用水",
                categorySnapshot: DrinkCategory.water.rawValue,
                waterRatioPercentSnapshot: 100,
                colorTokenSnapshot: "blue",
                iconKeySnapshot: WaterUpAsset.Drink.water,
                volumeML: 2_300,
                effectiveHydrationML: 2_300,
                consumedAt: now,
                createdAt: now,
                updatedAt: now
            )
        )
        try PersistenceService.saveChanges(in: context)

        let dashboard = try TodayDashboardService(dateBoundary: dateBoundary)
            .dashboard(for: now, in: context)

        XCTAssertEqual(dashboard.summary.totalEffectiveHydrationML, 2_300)
        XCTAssertEqual(dashboard.summary.remainingML, 0)
        XCTAssertEqual(dashboard.summary.progress, 1.15)
        XCTAssertEqual(dashboard.summary.ringProgress, 1)
    }

    func testHydrationExplanationIsShownOnlyUntilDismissed() throws {
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
        let explanationService = HydrationExplanationService()

        try bootstrap.initialize(in: context, now: now)
        XCTAssertTrue(try explanationService.shouldShow(in: context))

        try explanationService.markAsShown(in: context)

        XCTAssertFalse(try explanationService.shouldShow(in: context))
    }

    func testRecordDraftRejectsInvalidVolumeFutureTimeAndLongNote() {
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let drink = DrinkDefinition(
            name: "测试饮品",
            category: .other,
            waterRatioPercent: 90,
            defaultVolumeML: 250,
            colorToken: "blue",
            iconKey: WaterUpAsset.Drink.custom,
            source: .custom,
            createdAt: now,
            updatedAt: now
        )
        let invalidVolumeValues = ["", "abc", "0", "5001"]

        for value in invalidVolumeValues {
            var draft = RecordDraft.newRecord(from: drink, consumedAt: now)
            draft.volumeText = value

            XCTAssertTrue(draft.validationErrors(at: now).contains(.invalidVolume))
        }

        var futureDraft = RecordDraft.newRecord(
            from: drink,
            consumedAt: now.addingTimeInterval(1)
        )
        futureDraft.volumeText = "300"
        XCTAssertEqual(futureDraft.validationErrors(at: now), [.futureConsumedAt])

        var longNoteDraft = RecordDraft.newRecord(from: drink, consumedAt: now)
        longNoteDraft.note = String(repeating: "水", count: 101)
        XCTAssertEqual(longNoteDraft.validationErrors(at: now), [.noteTooLong])
    }

    func testNewRecordSavesCompleteDrinkSnapshotAndEffectiveHydration() throws {
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let container = try WaterUpModelContainer.make(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let drink = DrinkDefinition(
            name: "椰子水",
            category: .sportsDrink,
            waterRatioPercent: 90,
            defaultVolumeML: 250,
            colorToken: "cyan",
            iconKey: WaterUpAsset.Drink.custom,
            source: .custom,
            createdAt: now,
            updatedAt: now
        )
        context.insert(drink)
        try PersistenceService.saveChanges(in: context)

        var draft = RecordDraft.newRecord(
            from: drink,
            consumedAt: now.addingTimeInterval(-60)
        )
        draft.volumeText = "300"
        draft.note = "训练后"

        let recordService = RecordService()
        let result = try recordService.save(draft: draft, now: now, in: context)
        let record = try recordService.record(id: result.recordID, in: context)

        XCTAssertEqual(record.drinkID, drink.id)
        XCTAssertEqual(record.drinkNameSnapshot, "椰子水")
        XCTAssertEqual(record.categorySnapshot, DrinkCategory.sportsDrink.rawValue)
        XCTAssertEqual(record.waterRatioPercentSnapshot, 90)
        XCTAssertEqual(record.colorTokenSnapshot, "cyan")
        XCTAssertEqual(record.iconKeySnapshot, WaterUpAsset.Drink.custom)
        XCTAssertEqual(record.volumeML, 300)
        XCTAssertEqual(record.effectiveHydrationML, 270)
        XCTAssertEqual(record.note, "训练后")
    }

    func testEditingWithoutReplacingDrinkKeepsHistoricalSnapshot() throws {
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let container = try WaterUpModelContainer.make(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let drink = DrinkDefinition(
            name: "旧配方",
            category: .other,
            waterRatioPercent: 90,
            defaultVolumeML: 300,
            colorToken: "blue",
            iconKey: WaterUpAsset.Drink.custom,
            source: .custom,
            createdAt: now,
            updatedAt: now
        )
        context.insert(drink)
        try PersistenceService.saveChanges(in: context)

        let recordService = RecordService()
        var newDraft = RecordDraft.newRecord(
            from: drink,
            consumedAt: now.addingTimeInterval(-3_600)
        )
        newDraft.volumeText = "300"
        let createResult = try recordService.save(
            draft: newDraft,
            now: now.addingTimeInterval(-3_500),
            in: context
        )
        let record = try recordService.record(id: createResult.recordID, in: context)

        drink.name = "新配方"
        drink.waterRatioPercent = 50
        drink.colorToken = "red"
        try PersistenceService.saveChanges(in: context)

        var editDraft = RecordDraft.editing(record)
        editDraft.volumeText = "500"
        _ = try recordService.save(draft: editDraft, now: now, in: context)

        XCTAssertEqual(record.drinkNameSnapshot, "旧配方")
        XCTAssertEqual(record.waterRatioPercentSnapshot, 90)
        XCTAssertEqual(record.colorTokenSnapshot, "blue")
        XCTAssertEqual(record.volumeML, 500)
        XCTAssertEqual(record.effectiveHydrationML, 450)
    }

    func testExplicitDrinkReplacementUsesCurrentConfigurationAndKeepsEditedVolume() throws {
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let container = try WaterUpModelContainer.make(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        try BootstrapService().initialize(in: context, now: now.addingTimeInterval(-3_600))

        let water = try fetchDrink(seedKey: "water", in: context)
        let milk = try fetchDrink(seedKey: "milk", in: context)
        let recordService = RecordService()
        let quickResult = try recordService.createQuickRecord(
            forDrinkID: water.id,
            at: now.addingTimeInterval(-1_800),
            in: context
        )
        let record = try recordService.record(id: quickResult.recordID, in: context)
        var draft = RecordDraft.editing(record)
        draft.volumeText = "500"
        draft.select(milk)

        _ = try recordService.save(draft: draft, now: now, in: context)

        XCTAssertEqual(record.drinkID, milk.id)
        XCTAssertEqual(record.drinkNameSnapshot, milk.name)
        XCTAssertEqual(record.categorySnapshot, milk.categoryRawValue)
        XCTAssertEqual(record.waterRatioPercentSnapshot, milk.waterRatioPercent)
        XCTAssertEqual(record.colorTokenSnapshot, milk.colorToken)
        XCTAssertEqual(record.iconKeySnapshot, milk.iconKey)
        XCTAssertEqual(record.volumeML, 500)
        XCTAssertEqual(record.effectiveHydrationML, 435)
    }

    func testEditingConsumedDateMovesRecordBetweenNaturalDays() throws {
        let calendar = makeCalendar(timeZoneIdentifier: "Asia/Shanghai")
        let yesterday = makeDate(
            year: 2026,
            month: 7,
            day: 29,
            hour: 20,
            calendar: calendar
        )
        let today = makeDate(
            year: 2026,
            month: 7,
            day: 30,
            hour: 12,
            calendar: calendar
        )
        let container = try WaterUpModelContainer.make(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let dateBoundary = DateBoundaryService(calendar: calendar)
        try BootstrapService(dateBoundary: dateBoundary).initialize(
            in: context,
            now: yesterday
        )

        let water = try fetchDrink(seedKey: "water", in: context)
        let recordService = RecordService(dateBoundary: dateBoundary)
        let quickResult = try recordService.createQuickRecord(
            forDrinkID: water.id,
            at: today,
            in: context
        )
        let record = try recordService.record(id: quickResult.recordID, in: context)
        var draft = RecordDraft.editing(record)
        draft.consumedAt = yesterday

        let result = try recordService.save(
            draft: draft,
            now: today.addingTimeInterval(60),
            in: context
        )
        let queryService = HydrationRecordQueryService(dateBoundary: dateBoundary)
        let yesterdayRecords = try queryService.records(on: yesterday, in: context)
        let todayRecords = try queryService.records(on: today, in: context)

        XCTAssertEqual(result.previousDayKey, "2026-07-30")
        XCTAssertEqual(result.currentDayKey, "2026-07-29")
        XCTAssertEqual(yesterdayRecords.map(\.id), [quickResult.recordID])
        XCTAssertTrue(todayRecords.isEmpty)
    }

    func testSaveFailureRollsBackOriginalRecordAndKeepsDraftValue() throws {
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let container = try WaterUpModelContainer.make(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let drink = DrinkDefinition(
            name: "回滚测试饮品",
            category: .other,
            waterRatioPercent: 80,
            defaultVolumeML: 250,
            colorToken: "blue",
            iconKey: WaterUpAsset.Drink.custom,
            source: .custom,
            createdAt: now,
            updatedAt: now
        )
        context.insert(drink)
        try PersistenceService.saveChanges(in: context)

        let normalService = RecordService()
        let quickResult = try normalService.createQuickRecord(
            forDrinkID: drink.id,
            at: now.addingTimeInterval(-60),
            in: context
        )
        let record = try normalService.record(id: quickResult.recordID, in: context)
        var draft = RecordDraft.editing(record)
        draft.volumeText = "500"
        draft.note = "输入不能丢失"
        let failingService = RecordService(saveChanges: { _ in
            throw IntentionalSaveError.failure
        })

        XCTAssertThrowsError(
            try failingService.save(draft: draft, now: now, in: context)
        )

        let verificationContext = ModelContext(container)
        let persistedRecord = try normalService.record(
            id: quickResult.recordID,
            in: verificationContext
        )
        XCTAssertEqual(persistedRecord.volumeML, 250)
        XCTAssertEqual(persistedRecord.effectiveHydrationML, 200)
        XCTAssertNil(persistedRecord.note)
        XCTAssertEqual(draft.volumeText, "500")
        XCTAssertEqual(draft.note, "输入不能丢失")
    }

    func testQuickRecordSaveFailureDoesNotCreateRecord() throws {
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let container = try WaterUpModelContainer.make(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        try BootstrapService().initialize(in: context, now: now)
        let water = try fetchDrink(seedKey: "water", in: context)
        let failingService = RecordService(saveChanges: { _ in
            throw IntentionalSaveError.failure
        })

        XCTAssertThrowsError(
            try failingService.createQuickRecord(forDrinkID: water.id, at: now, in: context)
        )

        let verificationContext = ModelContext(container)
        let records = try verificationContext.fetch(FetchDescriptor<HydrationRecord>())
        XCTAssertTrue(records.isEmpty)
    }

    func testDeleteSaveFailureKeepsRecord() throws {
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let container = try WaterUpModelContainer.make(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        try BootstrapService().initialize(in: context, now: now)
        let water = try fetchDrink(seedKey: "water", in: context)
        let normalService = RecordService()
        let result = try normalService.createQuickRecord(forDrinkID: water.id, at: now, in: context)
        let failingService = RecordService(saveChanges: { _ in
            throw IntentionalSaveError.failure
        })

        XCTAssertThrowsError(try failingService.deleteRecord(id: result.recordID, in: context))

        let verificationContext = ModelContext(container)
        let persistedRecord = try normalService.record(id: result.recordID, in: verificationContext)
        XCTAssertEqual(persistedRecord.id, result.recordID)
    }

    func testDrinkSaveFailureDoesNotInsertCustomDrink() throws {
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let container = try WaterUpModelContainer.make(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        try BootstrapService().initialize(in: context, now: now)

        var draft = DrinkDraft.newDrink()
        draft.name = "未保存饮品"
        draft.categoryRawValue = DrinkCategory.other.rawValue
        draft.waterRatioText = "80"
        draft.defaultVolumeText = "300"
        draft.isFavorite = true
        let failingService = DrinkService(saveChanges: { _ in
            throw IntentionalSaveError.failure
        })

        XCTAssertThrowsError(try failingService.create(draft: draft, now: now, in: context))

        let verificationContext = ModelContext(container)
        let drinks = try verificationContext.fetch(FetchDescriptor<DrinkDefinition>())
        XCTAssertEqual(drinks.count, 7)
        XCTAssertFalse(drinks.contains { $0.name == "未保存饮品" })
    }

    func testGoalSaveFailurePreservesPersistedTarget() throws {
        let calendar = makeCalendar(timeZoneIdentifier: "Asia/Shanghai")
        let now = makeDate(year: 2026, month: 8, day: 14, hour: 9, calendar: calendar)
        let container = try WaterUpModelContainer.make(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let dateBoundary = DateBoundaryService(calendar: calendar)
        try BootstrapService(dateBoundary: dateBoundary).initialize(in: context, now: now)

        let failingService = GoalService(
            dateBoundary: dateBoundary,
            saveChanges: { _ in throw IntentionalSaveError.failure }
        )

        XCTAssertThrowsError(
            try failingService.upsertToday(targetML: 2_500, now: now, in: context)
        )

        let verificationContext = ModelContext(container)
        let persistedGoal = try GoalService(dateBoundary: dateBoundary).goal(
            for: now,
            in: verificationContext
        )
        XCTAssertEqual(persistedGoal.targetML, 2_000)
    }

    func testReminderConfigurationSaveFailurePreservesPersistedValues() throws {
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let container = try WaterUpModelContainer.make(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        try BootstrapService().initialize(in: context, now: now)
        let configuration = try ReminderScheduleConfiguration(
            isEnabled: true,
            startMinuteOfDay: 8 * 60,
            endMinuteOfDay: 20 * 60,
            intervalMinutes: 60
        )
        let failingService = ReminderConfigurationService(saveChanges: { _ in
            throw IntentionalSaveError.failure
        })

        XCTAssertThrowsError(
            try failingService.save(configuration: configuration, in: context)
        )

        let verificationContext = ModelContext(container)
        let persistedConfiguration = try ReminderConfigurationService().configuration(
            in: verificationContext
        )
        XCTAssertFalse(persistedConfiguration.isEnabled)
        XCTAssertEqual(persistedConfiguration.startMinuteOfDay, 9 * 60)
        XCTAssertEqual(persistedConfiguration.endMinuteOfDay, 21 * 60)
        XCTAssertEqual(persistedConfiguration.intervalMinutes, 120)
    }

    func testHistoryMonthUsesMondayGridThreeStatesAndHistoricalGoals() throws {
        let calendar = makeCalendar(timeZoneIdentifier: "Asia/Shanghai")
        let firstUseDate = makeDate(
            year: 2026,
            month: 7,
            day: 1,
            hour: 9,
            calendar: calendar
        )
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
        let goalService = GoalService(dateBoundary: dateBoundary)

        try BootstrapService(dateBoundary: dateBoundary).initialize(in: context, now: firstUseDate)
        try goalService.upsertToday(
            targetML: 2_500,
            now: makeDate(year: 2026, month: 7, day: 20, hour: 9, calendar: calendar),
            in: context
        )

        context.insert(
            makeHistoryRecord(
                volumeML: 2_100,
                effectiveHydrationML: 2_100,
                consumedAt: makeDate(year: 2026, month: 7, day: 15, hour: 9, calendar: calendar)
            )
        )
        context.insert(
            makeHistoryRecord(
                volumeML: 2_300,
                effectiveHydrationML: 2_300,
                consumedAt: makeDate(year: 2026, month: 7, day: 22, hour: 9, calendar: calendar)
            )
        )
        try PersistenceService.saveChanges(in: context)

        let month = try HistoryService(calendar: calendar).month(for: now, now: now, in: context)
        let julyFirstIndex = try XCTUnwrap(month.days.firstIndex { day in
            day.dayNumber == 1
        })
        let reachedDay = try XCTUnwrap(month.days.first { day in
            day.dayNumber == 15
        })
        let belowTargetDay = try XCTUnwrap(month.days.first { day in
            day.dayNumber == 22
        })
        let noDataDay = try XCTUnwrap(month.days.first { day in
            day.dayNumber == 16
        })
        let futureDay = try XCTUnwrap(month.days.first { day in
            day.dayNumber == 31
        })

        XCTAssertEqual(julyFirstIndex, 2)
        XCTAssertEqual(reachedDay.state, .reachedTarget)
        XCTAssertEqual(belowTargetDay.state, .belowTarget)
        XCTAssertEqual(noDataDay.state, .noData)
        XCTAssertTrue(futureDay.isFuture)
        XCTAssertNil(futureDay.state)
    }

    func testHistoryDetailUsesRecordSnapshotsAndNewestRecordFirst() throws {
        let calendar = makeCalendar(timeZoneIdentifier: "Asia/Shanghai")
        let day = makeDate(
            year: 2026,
            month: 7,
            day: 30,
            hour: 12,
            calendar: calendar
        )
        let container = try WaterUpModelContainer.make(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let dateBoundary = DateBoundaryService(calendar: calendar)

        try BootstrapService(dateBoundary: dateBoundary).initialize(in: context, now: day)
        let olderRecord = makeHistoryRecord(
            drinkName: "茶",
            volumeML: 300,
            effectiveHydrationML: 297,
            consumedAt: makeDate(year: 2026, month: 7, day: 30, hour: 9, calendar: calendar)
        )
        let newerRecord = makeHistoryRecord(
            drinkName: "饮用水",
            volumeML: 250,
            effectiveHydrationML: 250,
            consumedAt: makeDate(year: 2026, month: 7, day: 30, hour: 14, calendar: calendar)
        )
        context.insert(olderRecord)
        context.insert(newerRecord)
        try PersistenceService.saveChanges(in: context)

        let detail = try HistoryService(calendar: calendar).detail(for: day, in: context)

        XCTAssertEqual(detail.summary.targetML, 2_000)
        XCTAssertEqual(detail.summary.totalVolumeML, 550)
        XCTAssertEqual(detail.summary.totalEffectiveHydrationML, 547)
        XCTAssertEqual(detail.records.map(\.id), [newerRecord.id, olderRecord.id])
        XCTAssertEqual(detail.records.map(\.drinkNameSnapshot), ["饮用水", "茶"])
    }

    func testSevenDayTrendUsesHistoricalGoalsAndFirstUseDayForAverage() throws {
        let calendar = makeCalendar(timeZoneIdentifier: "Asia/Shanghai")
        let firstUseDate = makeDate(year: 2026, month: 7, day: 28, hour: 9, calendar: calendar)
        let now = makeDate(year: 2026, month: 8, day: 3, hour: 12, calendar: calendar)
        let container = try WaterUpModelContainer.make(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let dateBoundary = DateBoundaryService(calendar: calendar)
        let goalService = GoalService(dateBoundary: dateBoundary)

        try BootstrapService(dateBoundary: dateBoundary).initialize(in: context, now: firstUseDate)
        try goalService.upsertToday(
            targetML: 2_500,
            now: makeDate(year: 2026, month: 8, day: 1, hour: 9, calendar: calendar),
            in: context
        )

        let records = [
            makeHistoryRecord(
                volumeML: 2_100,
                effectiveHydrationML: 2_100,
                consumedAt: makeDate(year: 2026, month: 7, day: 28, hour: 9, calendar: calendar)
            ),
            makeHistoryRecord(
                volumeML: 1_000,
                effectiveHydrationML: 1_000,
                consumedAt: makeDate(year: 2026, month: 7, day: 30, hour: 9, calendar: calendar)
            ),
            makeHistoryRecord(
                volumeML: 2_500,
                effectiveHydrationML: 2_500,
                consumedAt: makeDate(year: 2026, month: 8, day: 1, hour: 9, calendar: calendar)
            ),
            makeHistoryRecord(
                volumeML: 2_600,
                effectiveHydrationML: 2_600,
                consumedAt: makeDate(year: 2026, month: 8, day: 2, hour: 9, calendar: calendar)
            )
        ]
        for record in records {
            context.insert(record)
        }
        try PersistenceService.saveChanges(in: context)

        let dashboard = try TrendService(calendar: calendar).dashboard(
            for: .sevenDays,
            now: now,
            in: context
        )
        let july31 = try XCTUnwrap(dashboard.period.points.first { $0.dayKey == "2026-07-31" })
        let august1 = try XCTUnwrap(dashboard.period.points.first { $0.dayKey == "2026-08-01" })

        XCTAssertEqual(dashboard.period.points.count, 7)
        XCTAssertEqual(dashboard.period.summary.totalEffectiveHydrationML, 8_200)
        XCTAssertEqual(dashboard.period.summary.averageEffectiveHydrationML, 1_171)
        XCTAssertEqual(dashboard.period.summary.reachedTargetDayCount, 3)
        XCTAssertEqual(dashboard.period.summary.recordCoveragePercent, 57)
        XCTAssertEqual(july31.targetML, 2_000)
        XCTAssertEqual(august1.targetML, 2_500)
    }

    func testThirtyDayTrendExcludesDaysBeforeFirstUseFromCoverageAndAverage() throws {
        let calendar = makeCalendar(timeZoneIdentifier: "Asia/Shanghai")
        let firstUseDate = makeDate(year: 2026, month: 7, day: 31, hour: 9, calendar: calendar)
        let now = makeDate(year: 2026, month: 8, day: 3, hour: 12, calendar: calendar)
        let container = try WaterUpModelContainer.make(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let dateBoundary = DateBoundaryService(calendar: calendar)

        try BootstrapService(dateBoundary: dateBoundary).initialize(in: context, now: firstUseDate)
        context.insert(
            makeHistoryRecord(
                volumeML: 2_000,
                effectiveHydrationML: 2_000,
                consumedAt: firstUseDate
            )
        )
        try PersistenceService.saveChanges(in: context)

        let dashboard = try TrendService(calendar: calendar).dashboard(
            for: .thirtyDays,
            now: now,
            in: context
        )
        let july30 = try XCTUnwrap(dashboard.period.points.first { $0.dayKey == "2026-07-30" })

        XCTAssertEqual(dashboard.period.points.count, 30)
        XCTAssertEqual(dashboard.period.summary.statisticalDayCount, 4)
        XCTAssertEqual(dashboard.period.summary.averageEffectiveHydrationML, 500)
        XCTAssertEqual(dashboard.period.summary.recordCoveragePercent, 25)
        XCTAssertFalse(july30.isStatisticalDay)
        XCTAssertNil(july30.targetML)
    }

    func testSevenDayComparisonUsesActualFirstUseDaysInEachPeriod() throws {
        let calendar = makeCalendar(timeZoneIdentifier: "Asia/Shanghai")
        let firstUseDate = makeDate(year: 2026, month: 7, day: 21, hour: 9, calendar: calendar)
        let now = makeDate(year: 2026, month: 8, day: 3, hour: 12, calendar: calendar)
        let container = try WaterUpModelContainer.make(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let dateBoundary = DateBoundaryService(calendar: calendar)

        try BootstrapService(dateBoundary: dateBoundary).initialize(in: context, now: firstUseDate)
        for offset in 0..<14 {
            let date = calendar.date(byAdding: .day, value: offset, to: firstUseDate)!
            let hydration = offset < 7 ? 1_000 : 2_000
            context.insert(
                makeHistoryRecord(
                    volumeML: hydration,
                    effectiveHydrationML: hydration,
                    consumedAt: date
                )
            )
        }
        try PersistenceService.saveChanges(in: context)

        let dashboard = try TrendService(calendar: calendar).dashboard(
            for: .sevenDays,
            now: now,
            in: context
        )
        let comparison = try XCTUnwrap(dashboard.comparisonWithPreviousPeriod)

        XCTAssertEqual(comparison.averageDifferenceML, 1_000)
        XCTAssertEqual(comparison.percentageChange, 100)
    }

    func testF13PerformanceDataCoversFiveYearsForCoreQueries() throws {
        let calendar = makeCalendar(timeZoneIdentifier: "Asia/Shanghai")
        let now = makeDate(year: 2026, month: 8, day: 14, hour: 12, calendar: calendar)
        let container = try WaterUpModelContainer.make(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let dateBoundary = DateBoundaryService(calendar: calendar)

        try BootstrapService(dateBoundary: dateBoundary).initialize(in: context, now: now)
        try F13PerformanceDataService(calendar: calendar).seedIfNeeded(in: context, now: now)

        let records = try context.fetch(FetchDescriptor<HydrationRecord>())
        let today = try TodayDashboardService(dateBoundary: dateBoundary).dashboard(for: now, in: context)
        let month = try HistoryService(calendar: calendar).month(for: now, now: now, in: context)
        let sevenDayTrend = try TrendService(calendar: calendar).dashboard(
            for: .sevenDays,
            now: now,
            in: context
        )
        let thirtyDayTrend = try TrendService(calendar: calendar).dashboard(
            for: .thirtyDays,
            now: now,
            in: context
        )

        XCTAssertGreaterThanOrEqual(records.count, 1_825)
        XCTAssertGreaterThan(today.summary.totalEffectiveHydrationML, 0)
        XCTAssertTrue(month.days.contains { $0.dayNumber == 14 })
        XCTAssertEqual(sevenDayTrend.period.points.count, 7)
        XCTAssertEqual(thirtyDayTrend.period.points.count, 30)
    }

    func testReminderScheduleKeepsOnlyFutureTimesInsideConfiguredWindow() throws {
        let calendar = makeCalendar(timeZoneIdentifier: "Asia/Shanghai")
        let now = makeDate(year: 2026, month: 8, day: 14, hour: 10, calendar: calendar)
        let configuration = try ReminderScheduleConfiguration(
            isEnabled: true,
            startMinuteOfDay: 9 * 60,
            endMinuteOfDay: 21 * 60,
            intervalMinutes: 120
        )
        let dates = try ReminderScheduleCalculator(calendar: calendar).reminderDates(
            configuration: configuration,
            now: now,
            isGoalReached: { _ in false }
        )
        let todayTimes = dates
            .filter { calendar.isDate($0, inSameDayAs: now) }
            .map { calendar.dateComponents([.hour, .minute], from: $0) }

        XCTAssertEqual(todayTimes.map(\.hour), [11, 13, 15, 17, 19, 21])
        XCTAssertTrue(todayTimes.allSatisfy { $0.minute == 0 })
        XCTAssertEqual(dates.count, ReminderScheduleCalculator.maximumPendingRequestCount)
    }

    func testReminderScheduleStopsTodayAfterGoalAndKeepsTomorrowPlan() throws {
        let calendar = makeCalendar(timeZoneIdentifier: "Asia/Shanghai")
        let now = makeDate(year: 2026, month: 8, day: 14, hour: 10, calendar: calendar)
        let configuration = try ReminderScheduleConfiguration(
            isEnabled: true,
            startMinuteOfDay: 9 * 60,
            endMinuteOfDay: 21 * 60,
            intervalMinutes: 120
        )
        let dates = try ReminderScheduleCalculator(calendar: calendar).reminderDates(
            configuration: configuration,
            now: now,
            isGoalReached: { day in
                calendar.isDate(day, inSameDayAs: now)
            }
        )
        let tomorrow = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: now))

        XCTAssertFalse(dates.contains { calendar.isDate($0, inSameDayAs: now) })
        XCTAssertTrue(dates.contains { calendar.isDate($0, inSameDayAs: tomorrow) })
        XCTAssertEqual(calendar.component(.hour, from: try XCTUnwrap(dates.first)), 9)
    }

    func testReminderConfigurationRejectsInvalidTimeWindowAndInterval() {
        XCTAssertThrowsError(
            try ReminderScheduleConfiguration(
                isEnabled: true,
                startMinuteOfDay: 21 * 60,
                endMinuteOfDay: 9 * 60,
                intervalMinutes: 120
            )
        ) { error in
            XCTAssertEqual(error as? ReminderDraftValidationError, .invalidTimeWindow)
        }

        XCTAssertThrowsError(
            try ReminderScheduleConfiguration(
                isEnabled: true,
                startMinuteOfDay: 9 * 60,
                endMinuteOfDay: 21 * 60,
                intervalMinutes: 45
            )
        ) { error in
            XCTAssertEqual(error as? ReminderDraftValidationError, .invalidInterval)
        }
    }

    private func fetchDrink(seedKey: String, in context: ModelContext) throws -> DrinkDefinition {
        let descriptor = FetchDescriptor<DrinkDefinition>(
            predicate: #Predicate { drink in
                drink.seedKey == seedKey
            }
        )

        return try XCTUnwrap(context.fetch(descriptor).first)
    }

    private func makeFavoriteDrink(
        name: String,
        favoriteOrder: Int,
        now: Date
    ) -> DrinkDefinition {
        DrinkDefinition(
            name: name,
            category: .other,
            waterRatioPercent: 90,
            defaultVolumeML: 250,
            colorToken: "blue",
            iconKey: WaterUpAsset.Drink.custom,
            source: .custom,
            isFavorite: true,
            favoriteOrder: favoriteOrder,
            createdAt: now,
            updatedAt: now
        )
    }

    private func makeHistoryRecord(
        drinkName: String = "饮用水",
        volumeML: Int,
        effectiveHydrationML: Int,
        consumedAt: Date
    ) -> HydrationRecord {
        HydrationRecord(
            drinkID: UUID(),
            drinkNameSnapshot: drinkName,
            categorySnapshot: DrinkCategory.water.rawValue,
            waterRatioPercentSnapshot: 100,
            colorTokenSnapshot: "blue",
            iconKeySnapshot: WaterUpAsset.Drink.water,
            volumeML: volumeML,
            effectiveHydrationML: effectiveHydrationML,
            consumedAt: consumedAt,
            createdAt: consumedAt,
            updatedAt: consumedAt
        )
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

    private enum IntentionalSaveError: Error {
        case failure
    }
}

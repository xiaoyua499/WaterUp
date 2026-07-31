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

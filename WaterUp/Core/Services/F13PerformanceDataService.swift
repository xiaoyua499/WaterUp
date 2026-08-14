import Foundation
import SwiftData

/// 仅供 Debug 性能验收使用，通过启动参数写入五年本地记录。
struct F13PerformanceDataService {
    static let launchArgument = "--f13-performance-data"

    private static let marker = "F13 性能验证数据"

    private let calendar: Calendar
    private let dateBoundary: DateBoundaryService

    init(calendar: Calendar = .autoupdatingCurrent) {
        self.calendar = calendar
        dateBoundary = DateBoundaryService(calendar: calendar)
    }

    func seedIfNeeded(in context: ModelContext, now: Date = .now) throws {
        let records = try context.fetch(FetchDescriptor<HydrationRecord>())
        if records.contains(where: { $0.note == Self.marker }) {
            return
        }

        guard let metadata = try context.fetch(FetchDescriptor<AppMetadata>()).first,
              let water = try context.fetch(FetchDescriptor<DrinkDefinition>()).first(where: { $0.seedKey == "water" }),
              let todayRange = dateBoundary.dayRange(for: now),
              let firstDay = calendar.date(byAdding: .year, value: -5, to: todayRange.start) else {
            return
        }

        let firstDayKey = dateBoundary.dayKey(for: firstDay)
        metadata.firstUseDayKey = firstDayKey
        context.insert(
            DailyGoalChange(
                effectiveDayKey: firstDayKey,
                targetML: 2_000,
                createdAt: firstDay
            )
        )

        let dayCount = calendar.dateComponents([.day], from: firstDay, to: todayRange.end).day ?? 0
        for offset in 0..<dayCount {
            guard let day = calendar.date(byAdding: .day, value: offset, to: firstDay),
                  let consumedAt = calendar.date(byAdding: .hour, value: 9, to: day) else {
                continue
            }

            let hydration = hydrationAmount(for: offset)
            context.insert(
                HydrationRecord(
                    drinkID: water.id,
                    drinkNameSnapshot: water.name,
                    categorySnapshot: water.categoryRawValue,
                    waterRatioPercentSnapshot: water.waterRatioPercent,
                    colorTokenSnapshot: water.colorToken,
                    iconKeySnapshot: water.iconKey,
                    volumeML: hydration,
                    effectiveHydrationML: hydration,
                    consumedAt: consumedAt,
                    note: Self.marker,
                    createdAt: consumedAt,
                    updatedAt: consumedAt
                )
            )
        }

        try PersistenceService.saveChanges(in: context)
    }

    private func hydrationAmount(for dayOffset: Int) -> Int {
        let weeklyAmounts = [1_650, 1_900, 2_100, 2_250, 1_750, 2_400, 2_000]
        return weeklyAmounts[dayOffset % weeklyAmounts.count]
    }
}

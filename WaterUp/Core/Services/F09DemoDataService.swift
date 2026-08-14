import Foundation
import SwiftData

struct F09DemoDataService {
    private static let marker = "F09 趋势验证数据"

    private let calendar: Calendar
    private let dateBoundary: DateBoundaryService

    init(calendar: Calendar = .autoupdatingCurrent) {
        self.calendar = calendar
        dateBoundary = DateBoundaryService(calendar: calendar)
    }

    /// Debug 版首次运行写入趋势验收样本，避免每次启动重复插入。
    func seedIfNeeded(in context: ModelContext, now: Date = .now) throws {
        let records = try context.fetch(FetchDescriptor<HydrationRecord>())

        for record in records {
            if record.note == Self.marker {
                return
            }
        }

        guard let metadata = try context.fetch(FetchDescriptor<AppMetadata>()).first,
              let water = try context.fetch(FetchDescriptor<DrinkDefinition>()).first(where: { $0.seedKey == "water" }),
              let todayRange = dateBoundary.dayRange(for: now),
              let firstDay = calendar.date(byAdding: .day, value: -29, to: todayRange.start),
              let targetChangeDay = calendar.date(byAdding: .day, value: -10, to: todayRange.start) else {
            return
        }

        metadata.firstUseDayKey = dateBoundary.dayKey(for: firstDay)
        context.insert(
            DailyGoalChange(
                effectiveDayKey: dateBoundary.dayKey(for: firstDay),
                targetML: 2_000,
                createdAt: firstDay
            )
        )
        context.insert(
            DailyGoalChange(
                effectiveDayKey: dateBoundary.dayKey(for: targetChangeDay),
                targetML: 2_200,
                createdAt: targetChangeDay
            )
        )

        let hydrationAmounts = [
            1_600, 2_100, 1_850, 2_300, 0, 1_950, 2_400, 1_700, 2_050, 2_250,
            1_900, 2_350, 1_650, 2_100, 2_280, 0, 2_450, 1_800, 2_200, 2_350,
            1_750, 2_500, 2_100, 1_950, 2_300, 0, 2_400, 2_050, 2_250, 2_500
        ]

        for offset in 0..<hydrationAmounts.count {
            let hydration = hydrationAmounts[offset]
            guard hydration > 0,
                  let day = calendar.date(byAdding: .day, value: offset, to: firstDay),
                  let consumedAt = calendar.date(byAdding: .hour, value: 9, to: day) else {
                continue
            }

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
}

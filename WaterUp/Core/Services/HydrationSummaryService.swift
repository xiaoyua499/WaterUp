import Foundation
import SwiftData

struct DailyHydrationSummary: Equatable {
    let dayKey: String
    let targetML: Int
    let totalVolumeML: Int
    let totalEffectiveHydrationML: Int

    var remainingML: Int {
        max(targetML - totalEffectiveHydrationML, 0)
    }

    var progress: Double {
        guard targetML > 0 else {
            return 0
        }

        return Double(totalEffectiveHydrationML) / Double(targetML)
    }

    var roundedProgressPercentage: Int {
        guard targetML > 0 else {
            return 0
        }

        // 使用整数运算避免二进制浮点数把 .5 边界表示成略小于 .5。
        return (totalEffectiveHydrationML * 100 + targetML / 2) / targetML
    }

    var ringProgress: Double {
        min(max(progress, 0), 1)
    }
}

struct HydrationSummaryService {
    let dateBoundary: DateBoundaryService
    let recordQuery: HydrationRecordQueryService
    let goalService: GoalService

    init(dateBoundary: DateBoundaryService = DateBoundaryService()) {
        self.dateBoundary = dateBoundary
        recordQuery = HydrationRecordQueryService(dateBoundary: dateBoundary)
        goalService = GoalService(dateBoundary: dateBoundary)
    }

    func summary(for date: Date, in context: ModelContext) throws -> DailyHydrationSummary {
        let records = try recordQuery.records(on: date, in: context)
        let goal = try goalService.goal(for: date, in: context)
        var totalVolumeML = 0
        var totalEffectiveHydrationML = 0

        for record in records {
            totalVolumeML += record.volumeML
            totalEffectiveHydrationML += record.effectiveHydrationML
        }

        return DailyHydrationSummary(
            dayKey: dateBoundary.dayKey(for: date),
            targetML: goal.targetML,
            totalVolumeML: totalVolumeML,
            totalEffectiveHydrationML: totalEffectiveHydrationML
        )
    }
}

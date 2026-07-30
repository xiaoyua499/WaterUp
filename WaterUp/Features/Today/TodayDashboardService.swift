import Foundation
import SwiftData

struct TodayDashboard {
    let date: Date
    let summary: DailyHydrationSummary
    let favoriteDrinks: [DrinkDefinition]
    let defaultWater: DrinkDefinition?
    let records: [HydrationRecord]
    let shouldShowHydrationExplanation: Bool

    var recentRecords: [HydrationRecord] {
        Array(records.prefix(3))
    }

    var hasMoreRecords: Bool {
        records.count > recentRecords.count
    }
}

struct TodayDashboardService {
    let dateBoundary: DateBoundaryService
    let summaryService: HydrationSummaryService
    let recordQueryService: HydrationRecordQueryService
    let favoriteDrinkService: FavoriteDrinkService
    let hydrationExplanationService: HydrationExplanationService

    init(dateBoundary: DateBoundaryService = DateBoundaryService()) {
        self.dateBoundary = dateBoundary
        summaryService = HydrationSummaryService(dateBoundary: dateBoundary)
        recordQueryService = HydrationRecordQueryService(dateBoundary: dateBoundary)
        favoriteDrinkService = FavoriteDrinkService()
        hydrationExplanationService = HydrationExplanationService()
    }

    func dashboard(for date: Date = .now, in context: ModelContext) throws -> TodayDashboard {
        TodayDashboard(
            date: date,
            summary: try summaryService.summary(for: date, in: context),
            favoriteDrinks: try favoriteDrinkService.favoriteDrinks(in: context),
            defaultWater: try favoriteDrinkService.activeBuiltInWater(in: context),
            records: try recordQueryService.records(on: date, in: context),
            shouldShowHydrationExplanation: try hydrationExplanationService.shouldShow(in: context)
        )
    }
}

import Foundation
import SwiftData

enum HydrationRecordQueryError: Error, Equatable {
    case unavailableDayRange
}

struct HydrationRecordQueryService {
    let dateBoundary: DateBoundaryService

    init(dateBoundary: DateBoundaryService = DateBoundaryService()) {
        self.dateBoundary = dateBoundary
    }

    func records(on date: Date, in context: ModelContext) throws -> [HydrationRecord] {
        guard let range = dateBoundary.dayRange(for: date) else {
            throw HydrationRecordQueryError.unavailableDayRange
        }

        let start = range.start
        let end = range.end
        let descriptor = FetchDescriptor<HydrationRecord>(
            predicate: #Predicate { record in
                record.consumedAt >= start && record.consumedAt < end
            },
            sortBy: [
                SortDescriptor(\HydrationRecord.consumedAt, order: .reverse),
                SortDescriptor(\HydrationRecord.createdAt, order: .reverse)
            ]
        )

        return try context.fetch(descriptor)
    }
}

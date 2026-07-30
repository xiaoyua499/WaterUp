import Foundation
import SwiftData

enum RecordServiceError: Error, Equatable {
    case drinkNotFound
    case drinkIsNotAvailable
    case recordNotFound
}

struct QuickRecordResult: Equatable {
    let recordID: UUID
    let drinkName: String
    let volumeML: Int
    let effectiveHydrationML: Int
}

struct RecordService {
    func createQuickRecord(
        forDrinkID drinkID: UUID,
        at consumedAt: Date = .now,
        in context: ModelContext
    ) throws -> QuickRecordResult {
        let drink = try activeDrink(id: drinkID, in: context)
        let volumeML = drink.defaultVolumeML
        let effectiveHydrationML = try HydrationCalculator.effectiveHydrationML(
            volumeML: volumeML,
            waterRatioPercent: drink.waterRatioPercent
        )
        let record = HydrationRecord(
            drinkID: drink.id,
            drinkNameSnapshot: drink.name,
            categorySnapshot: drink.categoryRawValue,
            waterRatioPercentSnapshot: drink.waterRatioPercent,
            colorTokenSnapshot: drink.colorToken,
            iconKeySnapshot: drink.iconKey,
            volumeML: volumeML,
            effectiveHydrationML: effectiveHydrationML,
            consumedAt: consumedAt,
            createdAt: consumedAt,
            updatedAt: consumedAt
        )
        context.insert(record)
        try PersistenceService.saveChanges(in: context)

        return QuickRecordResult(
            recordID: record.id,
            drinkName: record.drinkNameSnapshot,
            volumeML: record.volumeML,
            effectiveHydrationML: record.effectiveHydrationML
        )
    }

    func deleteRecord(id: UUID, in context: ModelContext) throws {
        let descriptor = FetchDescriptor<HydrationRecord>(
            predicate: #Predicate { record in
                record.id == id
            }
        )

        guard let record = try context.fetch(descriptor).first else {
            throw RecordServiceError.recordNotFound
        }

        context.delete(record)
        try PersistenceService.saveChanges(in: context)
    }

    private func activeDrink(id: UUID, in context: ModelContext) throws -> DrinkDefinition {
        let descriptor = FetchDescriptor<DrinkDefinition>(
            predicate: #Predicate { drink in
                drink.id == id
            }
        )

        guard let drink = try context.fetch(descriptor).first else {
            throw RecordServiceError.drinkNotFound
        }

        guard drink.statusRawValue == DrinkStatus.active.rawValue else {
            throw RecordServiceError.drinkIsNotAvailable
        }

        return drink
    }
}

import Foundation
import SwiftData

enum RecordServiceError: Error, Equatable {
    case drinkNotFound
    case drinkIsNotAvailable
    case recordNotFound
    case invalidDraft(RecordDraftValidationError)
}

struct QuickRecordResult: Equatable {
    let recordID: UUID
    let drinkName: String
    let volumeML: Int
    let effectiveHydrationML: Int
}

struct RecordSaveResult: Equatable {
    let recordID: UUID
    let previousDayKey: String?
    let currentDayKey: String
}

struct RecordService {
    private let dateBoundary: DateBoundaryService
    private let saveChanges: (ModelContext) throws -> Void

    init(
        dateBoundary: DateBoundaryService = DateBoundaryService(),
        saveChanges: @escaping (ModelContext) throws -> Void = { context in
            try PersistenceService.saveChanges(in: context)
        }
    ) {
        self.dateBoundary = dateBoundary
        self.saveChanges = saveChanges
    }

    func record(id: UUID, in context: ModelContext) throws -> HydrationRecord {
        let descriptor = FetchDescriptor<HydrationRecord>(
            predicate: #Predicate { record in
                record.id == id
            }
        )

        guard let record = try context.fetch(descriptor).first else {
            throw RecordServiceError.recordNotFound
        }

        return record
    }

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
        try persistChanges(in: context)
        NotificationCenter.default.post(name: .waterUpRecordDidChange, object: nil)

        return QuickRecordResult(
            recordID: record.id,
            drinkName: record.drinkNameSnapshot,
            volumeML: record.volumeML,
            effectiveHydrationML: record.effectiveHydrationML
        )
    }

    func save(
        draft: RecordDraft,
        now: Date = .now,
        in context: ModelContext
    ) throws -> RecordSaveResult {
        try validate(draft: draft, now: now)

        guard let volumeML = draft.volumeML else {
            throw RecordServiceError.invalidDraft(.invalidVolume)
        }

        let snapshot = try resolvedSnapshot(for: draft, in: context)
        let effectiveHydrationML = try HydrationCalculator.effectiveHydrationML(
            volumeML: volumeML,
            waterRatioPercent: snapshot.waterRatioPercent
        )
        let previousDayKey: String?
        let record: HydrationRecord

        if let recordID = draft.recordID {
            record = try self.record(id: recordID, in: context)
            previousDayKey = dateBoundary.dayKey(for: record.consumedAt)
            apply(
                draft: draft,
                snapshot: snapshot,
                volumeML: volumeML,
                effectiveHydrationML: effectiveHydrationML,
                updatedAt: now,
                to: record
            )
        } else {
            previousDayKey = nil
            record = HydrationRecord(
                drinkID: snapshot.drinkID,
                drinkNameSnapshot: snapshot.name,
                categorySnapshot: snapshot.categoryRawValue,
                waterRatioPercentSnapshot: snapshot.waterRatioPercent,
                colorTokenSnapshot: snapshot.colorToken,
                iconKeySnapshot: snapshot.iconKey,
                volumeML: volumeML,
                effectiveHydrationML: effectiveHydrationML,
                consumedAt: draft.consumedAt,
                note: draft.noteForPersistence(),
                createdAt: now,
                updatedAt: now
            )
            context.insert(record)
        }

        try persistChanges(in: context)
        NotificationCenter.default.post(name: .waterUpRecordDidChange, object: nil)

        return RecordSaveResult(
            recordID: record.id,
            previousDayKey: previousDayKey,
            currentDayKey: dateBoundary.dayKey(for: draft.consumedAt)
        )
    }

    func deleteRecord(id: UUID, in context: ModelContext) throws {
        let record = try record(id: id, in: context)
        context.delete(record)
        try persistChanges(in: context)
        NotificationCenter.default.post(name: .waterUpRecordDidChange, object: nil)
    }

    private func validate(draft: RecordDraft, now: Date) throws {
        let errors = draft.validationErrors(at: now)

        if errors.contains(.invalidVolume) {
            throw RecordServiceError.invalidDraft(.invalidVolume)
        }

        if errors.contains(.futureConsumedAt) {
            throw RecordServiceError.invalidDraft(.futureConsumedAt)
        }

        if errors.contains(.noteTooLong) {
            throw RecordServiceError.invalidDraft(.noteTooLong)
        }
    }

    private func resolvedSnapshot(
        for draft: RecordDraft,
        in context: ModelContext
    ) throws -> RecordDrinkSnapshot {
        if draft.usesExistingRecordSnapshot {
            return RecordDrinkSnapshot(
                drinkID: draft.drinkID,
                name: draft.drinkName,
                categoryRawValue: draft.categoryRawValue,
                waterRatioPercent: draft.waterRatioPercent,
                colorToken: draft.colorToken,
                iconKey: draft.iconKey
            )
        }

        let drink = try activeDrink(id: draft.drinkID, in: context)
        return RecordDrinkSnapshot(drink: drink)
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

    private func apply(
        draft: RecordDraft,
        snapshot: RecordDrinkSnapshot,
        volumeML: Int,
        effectiveHydrationML: Int,
        updatedAt: Date,
        to record: HydrationRecord
    ) {
        record.drinkID = snapshot.drinkID
        record.drinkNameSnapshot = snapshot.name
        record.categorySnapshot = snapshot.categoryRawValue
        record.waterRatioPercentSnapshot = snapshot.waterRatioPercent
        record.colorTokenSnapshot = snapshot.colorToken
        record.iconKeySnapshot = snapshot.iconKey
        record.volumeML = volumeML
        record.effectiveHydrationML = effectiveHydrationML
        record.consumedAt = draft.consumedAt
        record.note = draft.noteForPersistence()
        record.updatedAt = updatedAt
    }

    private func persistChanges(in context: ModelContext) throws {
        do {
            try saveChanges(context)
        } catch {
            context.rollback()
            throw error
        }
    }
}

private struct RecordDrinkSnapshot {
    let drinkID: UUID
    let name: String
    let categoryRawValue: String
    let waterRatioPercent: Int
    let colorToken: String
    let iconKey: String

    init(
        drinkID: UUID,
        name: String,
        categoryRawValue: String,
        waterRatioPercent: Int,
        colorToken: String,
        iconKey: String
    ) {
        self.drinkID = drinkID
        self.name = name
        self.categoryRawValue = categoryRawValue
        self.waterRatioPercent = waterRatioPercent
        self.colorToken = colorToken
        self.iconKey = iconKey
    }

    init(drink: DrinkDefinition) {
        drinkID = drink.id
        name = drink.name
        categoryRawValue = drink.categoryRawValue
        waterRatioPercent = drink.waterRatioPercent
        colorToken = drink.colorToken
        iconKey = drink.iconKey
    }
}

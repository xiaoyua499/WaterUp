import Foundation

enum RecordDraftValidationError: Error, Hashable {
    case invalidVolume
    case futureConsumedAt
    case noteTooLong

    var message: String {
        switch self {
        case .invalidVolume:
            return "请输入 1–5000 mL 的整数"
        case .futureConsumedAt:
            return "记录时间不能晚于当前时间"
        case .noteTooLong:
            return "备注最多 100 个字符"
        }
    }
}

struct RecordDraft: Equatable {
    let recordID: UUID?
    var drinkID: UUID
    var drinkName: String
    var categoryRawValue: String
    var waterRatioPercent: Int
    var colorToken: String
    var iconKey: String
    var volumeText: String
    var consumedAt: Date
    var note: String
    var usesExistingRecordSnapshot: Bool

    static func newRecord(from drink: DrinkDefinition, consumedAt: Date) -> RecordDraft {
        RecordDraft(
            recordID: nil,
            drinkID: drink.id,
            drinkName: drink.name,
            categoryRawValue: drink.categoryRawValue,
            waterRatioPercent: drink.waterRatioPercent,
            colorToken: drink.colorToken,
            iconKey: drink.iconKey,
            volumeText: String(drink.defaultVolumeML),
            consumedAt: consumedAt,
            note: "",
            usesExistingRecordSnapshot: false
        )
    }

    static func editing(_ record: HydrationRecord) -> RecordDraft {
        let note: String
        if let recordNote = record.note {
            note = recordNote
        } else {
            note = ""
        }

        return RecordDraft(
            recordID: record.id,
            drinkID: record.drinkID,
            drinkName: record.drinkNameSnapshot,
            categoryRawValue: record.categorySnapshot,
            waterRatioPercent: record.waterRatioPercentSnapshot,
            colorToken: record.colorTokenSnapshot,
            iconKey: record.iconKeySnapshot,
            volumeText: String(record.volumeML),
            consumedAt: record.consumedAt,
            note: note,
            usesExistingRecordSnapshot: true
        )
    }

    mutating func select(_ drink: DrinkDefinition) {
        drinkID = drink.id
        drinkName = drink.name
        categoryRawValue = drink.categoryRawValue
        waterRatioPercent = drink.waterRatioPercent
        colorToken = drink.colorToken
        iconKey = drink.iconKey
        usesExistingRecordSnapshot = false

        if recordID == nil {
            volumeText = String(drink.defaultVolumeML)
        }
    }

    var volumeML: Int? {
        Int(volumeText)
    }

    var effectiveHydrationPreviewML: Int? {
        guard let volumeML else {
            return nil
        }

        return try? HydrationCalculator.effectiveHydrationML(
            volumeML: volumeML,
            waterRatioPercent: waterRatioPercent
        )
    }

    func validationErrors(at now: Date) -> Set<RecordDraftValidationError> {
        var errors = Set<RecordDraftValidationError>()

        if let volumeML {
            if !(1...5_000).contains(volumeML) {
                errors.insert(.invalidVolume)
            }
        } else {
            errors.insert(.invalidVolume)
        }

        if consumedAt > now {
            errors.insert(.futureConsumedAt)
        }

        if note.count > 100 {
            errors.insert(.noteTooLong)
        }

        return errors
    }

    func noteForPersistence() -> String? {
        if note.isEmpty {
            return nil
        }

        return note
    }
}

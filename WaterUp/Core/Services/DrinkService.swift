import Foundation
import SwiftData

enum DrinkServiceError: Error, Equatable {
    case invalidDraft(Set<DrinkDraftValidationError>)
    case drinkNotFound
    case drinkIsNotAvailable
    case builtInDrinkCannotBeEdited
}

struct DrinkService {
    private let saveChanges: (ModelContext) throws -> Void

    init(
        saveChanges: @escaping (ModelContext) throws -> Void = { context in
            try PersistenceService.saveChanges(in: context)
        }
    ) {
        self.saveChanges = saveChanges
    }

    @discardableResult
    func create(
        draft: DrinkDraft,
        now: Date = .now,
        in context: ModelContext
    ) throws -> DrinkDefinition {
        let values = try validatedValues(from: draft)
        let favoriteOrder: Int?

        if draft.isFavorite {
            favoriteOrder = try nextFavoriteOrder(in: context)
        } else {
            favoriteOrder = nil
        }

        let drink = DrinkDefinition(
            name: values.name,
            category: values.category,
            waterRatioPercent: values.waterRatioPercent,
            defaultVolumeML: values.defaultVolumeML,
            colorToken: draft.colorToken,
            iconKey: draft.iconKey,
            source: .custom,
            isFavorite: draft.isFavorite,
            favoriteOrder: favoriteOrder,
            createdAt: now,
            updatedAt: now
        )
        context.insert(drink)
        try persistChanges(in: context)
        postCatalogDidChange()

        return drink
    }

    @discardableResult
    func update(
        draft: DrinkDraft,
        now: Date = .now,
        in context: ModelContext
    ) throws -> DrinkDefinition {
        guard let drinkID = draft.drinkID else {
            throw DrinkServiceError.drinkNotFound
        }

        let drink = try drink(id: drinkID, in: context)
        let values = try validatedValues(from: draft)

        if drink.sourceRawValue == DrinkSource.builtIn.rawValue {
            drink.defaultVolumeML = values.defaultVolumeML
        } else if drink.sourceRawValue == DrinkSource.custom.rawValue {
            drink.name = values.name
            drink.categoryRawValue = values.category.rawValue
            drink.waterRatioPercent = values.waterRatioPercent
            drink.defaultVolumeML = values.defaultVolumeML
            drink.colorToken = draft.colorToken
            drink.iconKey = draft.iconKey
        } else {
            throw DrinkServiceError.builtInDrinkCannotBeEdited
        }

        try applyFavoriteState(draft.isFavorite, to: drink, in: context)
        drink.updatedAt = now
        try persistChanges(in: context)
        postCatalogDidChange()

        return drink
    }

    private func validatedValues(from draft: DrinkDraft) throws -> ValidatedDrinkValues {
        let errors = draft.validationErrors
        guard errors.isEmpty,
              let waterRatioPercent = draft.waterRatioPercent,
              let defaultVolumeML = draft.defaultVolumeML else {
            throw DrinkServiceError.invalidDraft(errors)
        }

        return ValidatedDrinkValues(
            name: draft.normalizedName,
            category: draft.category,
            waterRatioPercent: waterRatioPercent,
            defaultVolumeML: defaultVolumeML
        )
    }

    private func nextFavoriteOrder(in context: ModelContext) throws -> Int {
        let activeStatus = DrinkStatus.active.rawValue
        let descriptor = FetchDescriptor<DrinkDefinition>(
            predicate: #Predicate { drink in
                drink.statusRawValue == activeStatus && drink.isFavorite
            }
        )
        let favorites = try context.fetch(descriptor)

        return (favorites.compactMap(\.favoriteOrder).max() ?? (favorites.count - 1)) + 1
    }

    private func drink(id: UUID, in context: ModelContext) throws -> DrinkDefinition {
        let descriptor = FetchDescriptor<DrinkDefinition>(
            predicate: #Predicate { drink in
                drink.id == id
            }
        )

        guard let drink = try context.fetch(descriptor).first else {
            throw DrinkServiceError.drinkNotFound
        }

        guard drink.statusRawValue == DrinkStatus.active.rawValue else {
            throw DrinkServiceError.drinkIsNotAvailable
        }

        return drink
    }

    private func applyFavoriteState(
        _ shouldBeFavorite: Bool,
        to drink: DrinkDefinition,
        in context: ModelContext
    ) throws {
        if shouldBeFavorite, !drink.isFavorite {
            drink.isFavorite = true
            drink.favoriteOrder = try nextFavoriteOrder(in: context)
            return
        }

        guard !shouldBeFavorite, drink.isFavorite else {
            return
        }

        drink.isFavorite = false
        drink.favoriteOrder = nil
        try compactFavoriteOrders(in: context)
    }

    private func compactFavoriteOrders(in context: ModelContext) throws {
        let activeStatus = DrinkStatus.active.rawValue
        let descriptor = FetchDescriptor<DrinkDefinition>(
            predicate: #Predicate { drink in
                drink.statusRawValue == activeStatus && drink.isFavorite
            }
        )
        let favorites = try context.fetch(descriptor).sorted { left, right in
            switch (left.favoriteOrder, right.favoriteOrder) {
            case let (leftOrder?, rightOrder?):
                if leftOrder != rightOrder {
                    return leftOrder < rightOrder
                }

                return left.id.uuidString < right.id.uuidString
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                return left.id.uuidString < right.id.uuidString
            }
        }

        for (index, favorite) in favorites.enumerated() {
            favorite.favoriteOrder = index
        }
    }

    private func persistChanges(in context: ModelContext) throws {
        do {
            try saveChanges(context)
        } catch {
            context.rollback()
            throw error
        }
    }

    private func postCatalogDidChange() {
        NotificationCenter.default.post(name: .waterUpDrinkCatalogDidChange, object: nil)
    }
}

private struct ValidatedDrinkValues {
    let name: String
    let category: DrinkCategory
    let waterRatioPercent: Int
    let defaultVolumeML: Int
}

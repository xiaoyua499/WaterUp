import Foundation
import SwiftData

enum FavoriteDrinkServiceError: Error, Equatable {
    case drinkNotFound
    case drinkIsNotAvailable
    case builtInDrinkCannotBeArchived
}

extension Notification.Name {
    static let waterUpDrinkCatalogDidChange = Notification.Name("WaterUp.drinkCatalogDidChange")
}

struct FavoriteDrinkService {
    private let saveChanges: (ModelContext) throws -> Void

    init(
        saveChanges: @escaping (ModelContext) throws -> Void = { context in
            try PersistenceService.saveChanges(in: context)
        }
    ) {
        self.saveChanges = saveChanges
    }

    func favoriteCount(in context: ModelContext) throws -> Int {
        try activeFavoriteDrinks(in: context).count
    }

    func favoriteDrinks(in context: ModelContext) throws -> [DrinkDefinition] {
        try activeFavoriteDrinks(in: context)
    }

    func addToFavorites(id: UUID, in context: ModelContext) throws {
        let drink = try activeDrink(id: id, in: context)

        guard !drink.isFavorite else {
            return
        }

        let favorites = try activeFavoriteDrinks(in: context)

        drink.isFavorite = true
        drink.favoriteOrder = nextFavoriteOrder(from: favorites)
        drink.updatedAt = .now
        try persistChanges(in: context)
        postCatalogDidChange()
    }

    func removeFromFavorites(id: UUID, in context: ModelContext) throws {
        let drink = try activeDrink(id: id, in: context)

        guard drink.isFavorite else {
            return
        }

        drink.isFavorite = false
        drink.favoriteOrder = nil
        drink.updatedAt = .now
        try compactFavoriteOrders(in: context)
        try persistChanges(in: context)
        postCatalogDidChange()
    }

    /// F07 归档自定义饮品时复用，确保归档项不会残留在今日快捷入口。
    func archiveCustomDrink(id: UUID, in context: ModelContext) throws {
        let drink = try activeDrink(id: id, in: context)

        guard drink.sourceRawValue == DrinkSource.custom.rawValue else {
            throw FavoriteDrinkServiceError.builtInDrinkCannotBeArchived
        }

        drink.statusRawValue = DrinkStatus.archived.rawValue
        drink.isFavorite = false
        drink.favoriteOrder = nil
        drink.updatedAt = .now
        try compactFavoriteOrders(in: context)
        try persistChanges(in: context)
        postCatalogDidChange()
    }

    func activeBuiltInWater(in context: ModelContext) throws -> DrinkDefinition? {
        let waterSeedKey = "water"
        let activeStatus = DrinkStatus.active.rawValue
        let descriptor = FetchDescriptor<DrinkDefinition>(
            predicate: #Predicate { drink in
                drink.seedKey == waterSeedKey && drink.statusRawValue == activeStatus
            }
        )

        return try context.fetch(descriptor).first
    }

    private func activeFavoriteDrinks(in context: ModelContext) throws -> [DrinkDefinition] {
        let activeStatus = DrinkStatus.active.rawValue
        let descriptor = FetchDescriptor<DrinkDefinition>(
            predicate: #Predicate { drink in
                drink.statusRawValue == activeStatus && drink.isFavorite
            }
        )
        let drinks = try context.fetch(descriptor)

        return drinks.sorted(by: favoriteOrderComesBefore)
    }

    private func activeDrink(id: UUID, in context: ModelContext) throws -> DrinkDefinition {
        let descriptor = FetchDescriptor<DrinkDefinition>(
            predicate: #Predicate { drink in
                drink.id == id
            }
        )

        guard let drink = try context.fetch(descriptor).first else {
            throw FavoriteDrinkServiceError.drinkNotFound
        }

        guard drink.statusRawValue == DrinkStatus.active.rawValue else {
            throw FavoriteDrinkServiceError.drinkIsNotAvailable
        }

        return drink
    }

    private func nextFavoriteOrder(from drinks: [DrinkDefinition]) -> Int {
        guard let maximumOrder = drinks.compactMap(\.favoriteOrder).max() else {
            return drinks.count
        }

        return maximumOrder + 1
    }

    private func compactFavoriteOrders(in context: ModelContext) throws {
        let favorites = try activeFavoriteDrinks(in: context)

        for (index, drink) in favorites.enumerated() {
            drink.favoriteOrder = index
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

    private func favoriteOrderComesBefore(_ left: DrinkDefinition, _ right: DrinkDefinition) -> Bool {
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
}

import Foundation
import SwiftData

struct FavoriteDrinkService {
    private let maximumFavoriteCount = 6

    func favoriteDrinks(in context: ModelContext) throws -> [DrinkDefinition] {
        let activeStatus = DrinkStatus.active.rawValue
        let descriptor = FetchDescriptor<DrinkDefinition>(
            predicate: #Predicate { drink in
                drink.statusRawValue == activeStatus && drink.isFavorite
            }
        )
        let drinks = try context.fetch(descriptor)
        let orderedDrinks = drinks.sorted { left, right in
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

        return Array(orderedDrinks.prefix(maximumFavoriteCount))
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
}

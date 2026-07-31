import Foundation
import SwiftData

enum DrinkCatalogServiceError: Error, Equatable {
    case drinkNotFound
    case drinkIsNotAvailable
    case defaultWaterUnavailable
}

struct DrinkCatalog {
    let builtIn: [DrinkDefinition]
    let custom: [DrinkDefinition]
}

struct DrinkCatalogService {
    func activeDrink(id: UUID, in context: ModelContext) throws -> DrinkDefinition {
        let descriptor = FetchDescriptor<DrinkDefinition>(
            predicate: #Predicate { drink in
                drink.id == id
            }
        )

        guard let drink = try context.fetch(descriptor).first else {
            throw DrinkCatalogServiceError.drinkNotFound
        }

        guard drink.statusRawValue == DrinkStatus.active.rawValue else {
            throw DrinkCatalogServiceError.drinkIsNotAvailable
        }

        return drink
    }

    func defaultWater(in context: ModelContext) throws -> DrinkDefinition {
        let waterSeedKey = "water"
        let activeStatus = DrinkStatus.active.rawValue
        let descriptor = FetchDescriptor<DrinkDefinition>(
            predicate: #Predicate { drink in
                drink.seedKey == waterSeedKey && drink.statusRawValue == activeStatus
            }
        )

        guard let water = try context.fetch(descriptor).first else {
            throw DrinkCatalogServiceError.defaultWaterUnavailable
        }

        return water
    }

    func activeCatalog(in context: ModelContext) throws -> DrinkCatalog {
        let activeStatus = DrinkStatus.active.rawValue
        let descriptor = FetchDescriptor<DrinkDefinition>(
            predicate: #Predicate { drink in
                drink.statusRawValue == activeStatus
            }
        )
        let drinks = try context.fetch(descriptor)
        var builtIn = [DrinkDefinition]()
        var custom = [DrinkDefinition]()

        for drink in drinks {
            guard let source = DrinkSource(rawValue: drink.sourceRawValue) else {
                continue
            }

            switch source {
            case .builtIn:
                builtIn.append(drink)
            case .custom:
                custom.append(drink)
            }
        }

        builtIn.sort { left, right in
            let leftOrder = builtInOrder(for: left.seedKey)
            let rightOrder = builtInOrder(for: right.seedKey)

            if leftOrder != rightOrder {
                return leftOrder < rightOrder
            }

            return left.id.uuidString < right.id.uuidString
        }
        custom.sort { left, right in
            let comparison = left.name.localizedStandardCompare(right.name)

            if comparison != .orderedSame {
                return comparison == .orderedAscending
            }

            return left.id.uuidString < right.id.uuidString
        }

        return DrinkCatalog(builtIn: builtIn, custom: custom)
    }

    private func builtInOrder(for seedKey: String?) -> Int {
        guard let seedKey else {
            return 100
        }

        switch seedKey {
        case "water":
            return 0
        case "tea":
            return 1
        case "coffee":
            return 2
        case "milk":
            return 3
        case "juice":
            return 4
        case "soda":
            return 5
        case "sport":
            return 6
        default:
            return 100
        }
    }
}

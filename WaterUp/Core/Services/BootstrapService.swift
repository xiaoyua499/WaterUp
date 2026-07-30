import Foundation
import SwiftData

enum BootstrapServiceError: Error, Equatable {
    case multipleAppMetadataRecords
}

struct BootstrapService {
    static let currentSeedVersion = 1

    let dateBoundary: DateBoundaryService

    init(dateBoundary: DateBoundaryService = DateBoundaryService()) {
        self.dateBoundary = dateBoundary
    }

    func initialize(in context: ModelContext, now: Date = .now) throws {
        do {
            let metadata = try fetchMetadata(in: context)
            let isFirstInitialization = metadata == nil

            if isFirstInitialization {
                let firstUseDayKey = dateBoundary.dayKey(for: now)
                let newMetadata = AppMetadata(
                    firstUseDayKey: firstUseDayKey,
                    schemaSeedVersion: Self.currentSeedVersion
                )
                context.insert(newMetadata)

                context.insert(
                    DailyGoalChange(
                        effectiveDayKey: firstUseDayKey,
                        targetML: 2_000,
                        createdAt: now
                    )
                )
                context.insert(
                    ReminderConfiguration(
                        isEnabled: false,
                        startMinuteOfDay: 9 * 60,
                        endMinuteOfDay: 21 * 60,
                        intervalMinutes: 120
                    )
                )
            }

            try insertMissingBuiltInDrinks(
                isFirstInitialization: isFirstInitialization,
                now: now,
                in: context
            )

            try PersistenceService.saveChanges(in: context)
        } catch {
            context.rollback()
            throw error
        }
    }

    private func fetchMetadata(in context: ModelContext) throws -> AppMetadata? {
        let metadata = try context.fetch(FetchDescriptor<AppMetadata>())

        guard metadata.count <= 1 else {
            throw BootstrapServiceError.multipleAppMetadataRecords
        }

        return metadata.first
    }

    private func insertMissingBuiltInDrinks(
        isFirstInitialization: Bool,
        now: Date,
        in context: ModelContext
    ) throws {
        let existingDrinks = try context.fetch(FetchDescriptor<DrinkDefinition>())
        var existingSeedKeys = Set<String>()

        for drink in existingDrinks {
            guard let seedKey = drink.seedKey else {
                continue
            }

            existingSeedKeys.insert(seedKey)
        }

        for seed in BuiltInDrinkSeed.allCases {
            guard !existingSeedKeys.contains(seed.seedKey) else {
                continue
            }

            let favoriteOrder: Int?
            if isFirstInitialization {
                favoriteOrder = seed.initialFavoriteOrder
            } else {
                favoriteOrder = nil
            }

            let drink = DrinkDefinition(
                seedKey: seed.seedKey,
                name: seed.name,
                category: seed.category,
                waterRatioPercent: seed.waterRatioPercent,
                defaultVolumeML: seed.defaultVolumeML,
                colorToken: seed.colorToken,
                iconKey: seed.iconKey,
                source: .builtIn,
                isFavorite: favoriteOrder != nil,
                favoriteOrder: favoriteOrder,
                createdAt: now,
                updatedAt: now
            )
            context.insert(drink)
        }
    }
}

private enum BuiltInDrinkSeed: CaseIterable {
    case water
    case tea
    case coffee
    case milk
    case juice
    case soda
    case sport

    var seedKey: String {
        switch self {
        case .water:
            return "water"
        case .tea:
            return "tea"
        case .coffee:
            return "coffee"
        case .milk:
            return "milk"
        case .juice:
            return "juice"
        case .soda:
            return "soda"
        case .sport:
            return "sport"
        }
    }

    var name: String {
        switch self {
        case .water:
            return "饮用水"
        case .tea:
            return "茶"
        case .coffee:
            return "咖啡"
        case .milk:
            return "牛奶"
        case .juice:
            return "果汁"
        case .soda:
            return "碳酸饮料"
        case .sport:
            return "运动饮料"
        }
    }

    var category: DrinkCategory {
        switch self {
        case .water:
            return .water
        case .tea:
            return .tea
        case .coffee:
            return .coffee
        case .milk:
            return .dairy
        case .juice:
            return .juice
        case .soda:
            return .softDrink
        case .sport:
            return .sportsDrink
        }
    }

    var waterRatioPercent: Int {
        switch self {
        case .water:
            return 100
        case .tea, .coffee:
            return 99
        case .milk:
            return 87
        case .juice:
            return 88
        case .soda:
            return 90
        case .sport:
            return 94
        }
    }

    var defaultVolumeML: Int {
        switch self {
        case .water, .coffee, .milk, .juice:
            return 250
        case .tea:
            return 300
        case .soda:
            return 330
        case .sport:
            return 500
        }
    }

    var colorToken: String {
        switch self {
        case .water:
            return "blue"
        case .tea:
            return "green"
        case .coffee:
            return "brown"
        case .milk:
            return "purple"
        case .juice:
            return "orange"
        case .soda:
            return "red"
        case .sport:
            return "cyan"
        }
    }

    var iconKey: String {
        switch self {
        case .water:
            return WaterUpAsset.Drink.water
        case .tea:
            return WaterUpAsset.Drink.tea
        case .coffee:
            return WaterUpAsset.Drink.coffee
        case .milk:
            return WaterUpAsset.Drink.milk
        case .juice:
            return WaterUpAsset.Drink.juice
        case .soda:
            return WaterUpAsset.Drink.soda
        case .sport:
            return WaterUpAsset.Drink.sport
        }
    }

    var initialFavoriteOrder: Int? {
        switch self {
        case .water:
            return 0
        case .tea:
            return 1
        case .coffee:
            return 2
        case .milk:
            return 3
        case .juice, .soda, .sport:
            return nil
        }
    }
}

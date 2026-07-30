import Foundation
import SwiftData

enum DrinkCategory: String, CaseIterable, Codable {
    case water
    case tea
    case coffee
    case dairy
    case juice
    case softDrink
    case sportsDrink
    case other
}

enum DrinkSource: String, Codable {
    case builtIn
    case custom
}

enum DrinkStatus: String, Codable {
    case active
    case archived
}

@Model
final class DrinkDefinition {
    @Attribute(.unique) var id: UUID
    var seedKey: String?
    var name: String
    var categoryRawValue: String
    var waterRatioPercent: Int
    var defaultVolumeML: Int
    var colorToken: String
    var iconKey: String
    var sourceRawValue: String
    var statusRawValue: String
    var isFavorite: Bool
    var favoriteOrder: Int?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        seedKey: String? = nil,
        name: String,
        category: DrinkCategory,
        waterRatioPercent: Int,
        defaultVolumeML: Int,
        colorToken: String,
        iconKey: String,
        source: DrinkSource,
        status: DrinkStatus = .active,
        isFavorite: Bool = false,
        favoriteOrder: Int? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.seedKey = seedKey
        self.name = name
        categoryRawValue = category.rawValue
        self.waterRatioPercent = waterRatioPercent
        self.defaultVolumeML = defaultVolumeML
        self.colorToken = colorToken
        self.iconKey = iconKey
        sourceRawValue = source.rawValue
        statusRawValue = status.rawValue
        self.isFavorite = isFavorite
        self.favoriteOrder = favoriteOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var category: DrinkCategory? {
        DrinkCategory(rawValue: categoryRawValue)
    }

    var source: DrinkSource? {
        DrinkSource(rawValue: sourceRawValue)
    }

    var status: DrinkStatus? {
        DrinkStatus(rawValue: statusRawValue)
    }
}

@Model
final class HydrationRecord {
    @Attribute(.unique) var id: UUID
    var drinkID: UUID
    var drinkNameSnapshot: String
    var categorySnapshot: String
    var waterRatioPercentSnapshot: Int
    var colorTokenSnapshot: String
    var iconKeySnapshot: String
    var volumeML: Int
    var effectiveHydrationML: Int
    var consumedAt: Date
    var note: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        drinkID: UUID,
        drinkNameSnapshot: String,
        categorySnapshot: String,
        waterRatioPercentSnapshot: Int,
        colorTokenSnapshot: String,
        iconKeySnapshot: String,
        volumeML: Int,
        effectiveHydrationML: Int,
        consumedAt: Date,
        note: String? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.drinkID = drinkID
        self.drinkNameSnapshot = drinkNameSnapshot
        self.categorySnapshot = categorySnapshot
        self.waterRatioPercentSnapshot = waterRatioPercentSnapshot
        self.colorTokenSnapshot = colorTokenSnapshot
        self.iconKeySnapshot = iconKeySnapshot
        self.volumeML = volumeML
        self.effectiveHydrationML = effectiveHydrationML
        self.consumedAt = consumedAt
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class DailyGoalChange {
    @Attribute(.unique) var id: UUID
    var effectiveDayKey: String
    var targetML: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        effectiveDayKey: String,
        targetML: Int,
        createdAt: Date
    ) {
        self.id = id
        self.effectiveDayKey = effectiveDayKey
        self.targetML = targetML
        self.createdAt = createdAt
    }
}

@Model
final class ReminderConfiguration {
    @Attribute(.unique) var id: UUID
    var isEnabled: Bool
    var startMinuteOfDay: Int
    var endMinuteOfDay: Int
    var intervalMinutes: Int
    var lastScheduledAt: Date?

    init(
        id: UUID = UUID(),
        isEnabled: Bool,
        startMinuteOfDay: Int,
        endMinuteOfDay: Int,
        intervalMinutes: Int,
        lastScheduledAt: Date? = nil
    ) {
        self.id = id
        self.isEnabled = isEnabled
        self.startMinuteOfDay = startMinuteOfDay
        self.endMinuteOfDay = endMinuteOfDay
        self.intervalMinutes = intervalMinutes
        self.lastScheduledAt = lastScheduledAt
    }
}

@Model
final class AppMetadata {
    @Attribute(.unique) var id: UUID
    var firstUseDayKey: String
    var hasShownHydrationExplanation: Bool
    var schemaSeedVersion: Int

    init(
        id: UUID = UUID(),
        firstUseDayKey: String,
        hasShownHydrationExplanation: Bool = false,
        schemaSeedVersion: Int
    ) {
        self.id = id
        self.firstUseDayKey = firstUseDayKey
        self.hasShownHydrationExplanation = hasShownHydrationExplanation
        self.schemaSeedVersion = schemaSeedVersion
    }
}

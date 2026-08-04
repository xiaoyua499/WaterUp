import Foundation

enum DrinkDraftValidationError: Error, Hashable {
    case emptyName
    case nameTooLong
    case invalidWaterRatio
    case invalidDefaultVolume

    var message: String {
        switch self {
        case .emptyName:
            return "请输入饮品名称"
        case .nameTooLong:
            return "名称最多 20 个字符"
        case .invalidWaterRatio:
            return "请输入 0–100 的整数"
        case .invalidDefaultVolume:
            return "请输入 1–2000 mL 的整数"
        }
    }
}

struct DrinkDraft: Equatable {
    let drinkID: UUID?
    var name: String
    var categoryRawValue: String
    var waterRatioText: String
    var defaultVolumeText: String
    var colorToken: String
    var iconKey: String
    var isFavorite: Bool

    static func newDrink() -> DrinkDraft {
        DrinkDraft(
            drinkID: nil,
            name: "",
            categoryRawValue: DrinkCategory.other.rawValue,
            waterRatioText: "100",
            defaultVolumeText: "250",
            colorToken: "blue",
            iconKey: WaterUpAsset.Drink.custom,
            isFavorite: false
        )
    }

    init(drink: DrinkDefinition) {
        drinkID = drink.id
        name = drink.name
        categoryRawValue = drink.categoryRawValue
        waterRatioText = String(drink.waterRatioPercent)
        defaultVolumeText = String(drink.defaultVolumeML)
        colorToken = drink.colorToken
        iconKey = drink.iconKey
        isFavorite = drink.isFavorite
    }

    init(
        drinkID: UUID?,
        name: String,
        categoryRawValue: String,
        waterRatioText: String,
        defaultVolumeText: String,
        colorToken: String,
        iconKey: String,
        isFavorite: Bool
    ) {
        self.drinkID = drinkID
        self.name = name
        self.categoryRawValue = categoryRawValue
        self.waterRatioText = waterRatioText
        self.defaultVolumeText = defaultVolumeText
        self.colorToken = colorToken
        self.iconKey = iconKey
        self.isFavorite = isFavorite
    }

    var normalizedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var waterRatioPercent: Int? {
        Int(waterRatioText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    var defaultVolumeML: Int? {
        Int(defaultVolumeText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    var category: DrinkCategory {
        DrinkCategory(rawValue: categoryRawValue) ?? .other
    }

    var validationErrors: Set<DrinkDraftValidationError> {
        var errors = Set<DrinkDraftValidationError>()

        if normalizedName.isEmpty {
            errors.insert(.emptyName)
        } else if normalizedName.count > 20 {
            errors.insert(.nameTooLong)
        }

        guard let waterRatioPercent else {
            errors.insert(.invalidWaterRatio)
            return validateVolume(errors)
        }

        if !(0...100).contains(waterRatioPercent) {
            errors.insert(.invalidWaterRatio)
        }

        return validateVolume(errors)
    }

    var isZeroWaterRatio: Bool {
        waterRatioPercent == 0 && !validationErrors.contains(.invalidWaterRatio)
    }

    private func validateVolume(_ errors: Set<DrinkDraftValidationError>) -> Set<DrinkDraftValidationError> {
        var result = errors

        guard let defaultVolumeML else {
            result.insert(.invalidDefaultVolume)
            return result
        }

        if !(1...2_000).contains(defaultVolumeML) {
            result.insert(.invalidDefaultVolume)
        }

        return result
    }
}

extension DrinkCategory {
    var displayName: String {
        switch self {
        case .water:
            return "水"
        case .tea:
            return "茶饮"
        case .coffee:
            return "咖啡"
        case .dairy:
            return "乳制品"
        case .juice:
            return "果汁"
        case .softDrink:
            return "软饮料"
        case .sportsDrink:
            return "功能饮料"
        case .other:
            return "其他"
        }
    }
}

enum WaterUpAsset {
    enum Drink {
        static let water = "DrinkWater"
        static let tea = "DrinkTea"
        static let coffee = "DrinkCoffee"
        static let milk = "DrinkMilk"
        static let juice = "DrinkJuice"
        static let soda = "DrinkSoda"
        static let sport = "DrinkSport"
        static let custom = "DrinkCustom"
    }

    enum Background {
        static let light = "WaterUpLightBackground"
    }

    enum SystemSymbol {
        static let back = "chevron.backward"
        static let calendar = "calendar"
        static let settings = "gearshape"
        static let add = "plus"
        static let alert = "exclamationmark.triangle.fill"
    }

    static let drinkNames = [
        Drink.water,
        Drink.tea,
        Drink.coffee,
        Drink.milk,
        Drink.juice,
        Drink.soda,
        Drink.sport,
        Drink.custom
    ]
}

import SwiftData

enum WaterUpSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        Schema.Version(1, 0, 0)
    }

    static var models: [any PersistentModel.Type] {
        [
            DrinkDefinition.self,
            HydrationRecord.self,
            DailyGoalChange.self,
            ReminderConfiguration.self,
            AppMetadata.self
        ]
    }
}

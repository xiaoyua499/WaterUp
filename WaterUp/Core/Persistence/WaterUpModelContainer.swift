import SwiftData

enum WaterUpModelContainer {
    static func make(isStoredInMemoryOnly: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: WaterUpSchemaV1.self)
        let configuration = ModelConfiguration(
            "WaterUp",
            schema: schema,
            isStoredInMemoryOnly: isStoredInMemoryOnly
        )

        return try ModelContainer(for: schema, configurations: [configuration])
    }
}

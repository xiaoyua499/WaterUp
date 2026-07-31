import SwiftData

enum WaterUpPreviewData {
    /// 每个 Preview 使用独立且完成默认初始化的内存数据库，避免读取或污染正式 App 数据。
    @MainActor
    static func makeModelContainer() -> ModelContainer {
        do {
            let container = try WaterUpModelContainer.make(isStoredInMemoryOnly: true)
            let context = ModelContext(container)
            try BootstrapService().initialize(in: context)
            return container
        } catch {
            fatalError("无法初始化 WaterUp Preview 数据：\(error.localizedDescription)")
        }
    }
}

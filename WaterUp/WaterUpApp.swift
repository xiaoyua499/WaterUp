import SwiftUI
import SwiftData

@main
struct WaterUpApp: App {
    private let modelContainer: ModelContainer

    init() {
        do {
            let container = try WaterUpModelContainer.make()
            let context = ModelContext(container)
            try BootstrapService().initialize(in: context)
            modelContainer = container
        } catch {
            fatalError("无法初始化 WaterUp 本地数据：\(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(modelContainer)
    }
}

import Foundation
import SwiftUI
import SwiftData

@main
struct WaterUpApp: App {
    private let modelContainer: ModelContainer

    init() {
        do {
            let isRunningUITests = ProcessInfo.processInfo.arguments.contains("--ui-testing")
            let container = try WaterUpModelContainer.make(
                isStoredInMemoryOnly: isRunningUITests
            )
            let context = ModelContext(container)
            try BootstrapService().initialize(in: context)

            #if DEBUG
            if !isRunningUITests {
                if ProcessInfo.processInfo.arguments.contains(F13PerformanceDataService.launchArgument) {
                    try F13PerformanceDataService().seedIfNeeded(in: context)
                } else {
                    try F09DemoDataService().seedIfNeeded(in: context)
                }
            }
            #endif

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

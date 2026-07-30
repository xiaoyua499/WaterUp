import SwiftUI

struct RootTabView: View {
    @State private var selectedTab: AppTab = .today

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                AppPlaceholderView(
                    title: AppTab.today.title,
                    systemImage: AppTab.today.systemImage,
                    description: "应用骨架已就绪。今日记录功能将在本地数据基座完成后接入。"
                )
            }
            .tabItem {
                Label(AppTab.today.title, systemImage: AppTab.today.systemImage)
            }
            .tag(AppTab.today)

            NavigationStack {
                AppPlaceholderView(
                    title: AppTab.history.title,
                    systemImage: AppTab.history.systemImage,
                    description: "历史日历与趋势将在记录闭环完成后接入。"
                )
            }
            .tabItem {
                Label(AppTab.history.title, systemImage: AppTab.history.systemImage)
            }
            .tag(AppTab.history)

            NavigationStack {
                AppPlaceholderView(
                    title: AppTab.settings.title,
                    systemImage: AppTab.settings.systemImage,
                    description: "目标、饮品与提醒设置将在相应功能模块完成后接入。"
                )
            }
            .tabItem {
                Label(AppTab.settings.title, systemImage: AppTab.settings.systemImage)
            }
            .tag(AppTab.settings)
        }
        .accessibilityIdentifier("waterup.root.tab")
    }
}

enum AppTab: Hashable {
    case today
    case history
    case settings

    var title: String {
        switch self {
        case .today:
            return "今日"
        case .history:
            return "历史"
        case .settings:
            return "设置"
        }
    }

    var systemImage: String {
        switch self {
        case .today:
            return "drop.fill"
        case .history:
            return "calendar"
        case .settings:
            return "gearshape"
        }
    }
}

private struct AppPlaceholderView: View {
    let title: String
    let systemImage: String
    let description: String

    var body: some View {
        ContentUnavailableView(
            title,
            systemImage: systemImage,
            description: Text(description)
        )
        .navigationTitle(title)
    }
}

#Preview {
    RootTabView()
}

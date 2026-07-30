import SwiftUI

struct RootTabView: View {
    @State private var selectedTab: AppTab = .today

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                AppFoundationPlaceholderView(tab: .today)
            }
            .tabItem {
                Label(AppTab.today.title, systemImage: AppTab.today.systemImage)
            }
            .tag(AppTab.today)

            NavigationStack {
                AppFoundationPlaceholderView(tab: .history)
            }
            .tabItem {
                Label(AppTab.history.title, systemImage: AppTab.history.systemImage)
            }
            .tag(AppTab.history)

            NavigationStack {
                AppFoundationPlaceholderView(tab: .settings)
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

private struct AppFoundationPlaceholderView: View {
    let tab: AppTab

    var body: some View {
        WaterUpPage(title: tab.title) {
            WaterUpCard {
                HStack(alignment: .center, spacing: WaterUpTheme.Spacing.x4) {
                    Image(tab.illustrationAsset)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: WaterUpTheme.Spacing.x1) {
                        Text("F01 工程与设计系统")
                            .font(WaterUpTheme.Typography.headline)
                            .foregroundStyle(WaterUpTheme.Palette.textPrimary.color)

                        Text("已建立统一的颜色、排版、间距、圆角和组件基线。")
                            .font(WaterUpTheme.Typography.body)
                            .foregroundStyle(WaterUpTheme.Palette.textSecondary.color)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            WaterUpStatusMessage(
                kind: .info,
                title: "业务数据尚未接入",
                message: tab.placeholderMessage
            )

            WaterUpCard {
                WaterUpEmptyState(
                    systemImage: tab.systemImage,
                    title: tab.emptyTitle,
                    message: "下一阶段将建立本地数据模型、默认初始化与统一计算服务。"
                )
            }
        }
    }
}

private extension AppTab {
    var illustrationAsset: String {
        switch self {
        case .today:
            return WaterUpAsset.Drink.water
        case .history:
            return WaterUpAsset.Drink.tea
        case .settings:
            return WaterUpAsset.Drink.custom
        }
    }

    var placeholderMessage: String {
        switch self {
        case .today:
            return "今日记录、进度与快捷添加将在 F02 本地数据基座完成后接入。"
        case .history:
            return "历史日历、单日明细与趋势将在记录闭环完成后接入。"
        case .settings:
            return "目标、饮品和提醒设置将在各业务模块完成后接入。"
        }
    }

    var emptyTitle: String {
        switch self {
        case .today:
            return "准备记录第一杯水"
        case .history:
            return "历史数据将在这里呈现"
        case .settings:
            return "设置模块正在准备"
        }
    }
}

#Preview {
    RootTabView()
}

#Preview("辅助字号") {
    RootTabView()
        .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
}

#Preview("减弱动态效果") {
    RootTabView()
        .transaction { transaction in
            transaction.animation = nil
        }
}

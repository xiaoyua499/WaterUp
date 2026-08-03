import SwiftUI

struct RootTabView: View {
    @State private var selectedTab: AppTab = .today

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                TodayView {
                    selectedTab = .history
                }
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
                SettingsView()
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
                        Text(tab.placeholderTitle)
                            .font(WaterUpTheme.Typography.headline)
                            .foregroundStyle(WaterUpTheme.Palette.textPrimary.color)

                        Text(tab.placeholderDescription)
                            .font(WaterUpTheme.Typography.body)
                            .foregroundStyle(WaterUpTheme.Palette.textSecondary.color)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            WaterUpStatusMessage(
                kind: .info,
                title: "功能开发中",
                message: tab.placeholderMessage
            )

            WaterUpCard {
                WaterUpEmptyState(
                    systemImage: tab.systemImage,
                    title: tab.emptyTitle,
                    message: tab.emptyMessage
                )
            }
        }
    }
}

private extension AppTab {
    var placeholderTitle: String {
        switch self {
        case .today:
            return "今日记录已就绪"
        case .history:
            return "历史功能正在准备"
        case .settings:
            return "设置功能正在准备"
        }
    }

    var placeholderDescription: String {
        switch self {
        case .today:
            return "今日进度、快捷记录与撤销已使用本地数据基座。"
        case .history:
            return "饮水记录已保存到本机，日历与单日明细将在后续阶段接入。"
        case .settings:
            return "目标、饮品、提醒与隐私设置会在相应功能阶段陆续接入。"
        }
    }

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
            return "今日首页使用记录快照与有效补水量计算，数据仅保存在本机。"
        case .history:
            return "查看全部会保留在历史模块；完整日历、单日明细与趋势将在后续阶段提供。"
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

    var emptyMessage: String {
        switch self {
        case .today:
            return "使用常用饮品即可按默认杯量快速记录。"
        case .history:
            return "完成日历与单日明细后，可按日期查看已保存的饮水记录。"
        case .settings:
            return "完成设置模块后，可在这里统一管理每日目标、饮品和提醒。"
        }
    }
}

#Preview {
    RootTabView()
        .modelContainer(WaterUpPreviewData.makeModelContainer())
}

#Preview("辅助字号") {
    RootTabView()
        .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
        .modelContainer(WaterUpPreviewData.makeModelContainer())
}

#Preview("减弱动态效果") {
    RootTabView()
        .transaction { transaction in
            transaction.animation = nil
        }
        .modelContainer(WaterUpPreviewData.makeModelContainer())
}

import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var targetDetail = "读取中"
    @State private var drinkDetail = "读取中"
    @State private var reminderDetail = "读取中"
    @State private var isShowingReadError = false
    @State private var isShowingGoalSettings = false
    @State private var isShowingDrinkManagement = false
    @State private var isShowingReminderSettings = false
    @State private var isShowingUnitExplanation = false
    @State private var isShowingPrivacy = false

    private let goalService = GoalService()
    private let drinkCatalogService = DrinkCatalogService()
    private let reminderConfigurationService = ReminderConfigurationService()
    private let notificationAuthorizationService = NotificationAuthorizationService()

    var body: some View {
        WaterUpPage(title: "设置") {
            WaterUpSectionTitle("饮水计划")

            WaterUpCard {
                WaterUpSettingsRow(
                    title: "每日目标",
                    detail: targetDetail,
                    systemImage: "target"
                ) {
                    isShowingGoalSettings = true
                }
                .accessibilityIdentifier("waterup.settings.daily-goal")

                Divider()
                    .overlay(WaterUpTheme.Palette.divider.color)

                WaterUpSettingsRow(
                    title: "饮品管理",
                    detail: drinkDetail,
                    systemImage: "cup.and.saucer.fill"
                ) {
                    isShowingDrinkManagement = true
                }
                .accessibilityIdentifier("waterup.settings.drink-management")

                Divider()
                    .overlay(WaterUpTheme.Palette.divider.color)

                WaterUpSettingsRow(
                    title: "饮水提醒",
                    detail: reminderDetail,
                    systemImage: "bell.fill"
                ) {
                    isShowingReminderSettings = true
                }
                .accessibilityIdentifier("waterup.settings.reminder")

                Divider()
                    .overlay(WaterUpTheme.Palette.divider.color)

                WaterUpSettingsRow(
                    title: "单位说明",
                    detail: "mL",
                    systemImage: "ruler"
                ) {
                    isShowingUnitExplanation = true
                }
                .accessibilityIdentifier("waterup.settings.unit-explanation")
            }

            WaterUpSectionTitle("关于")

            WaterUpCard {
                WaterUpSettingsRow(
                    title: "数据与隐私",
                    detail: "",
                    systemImage: "checkmark.shield.fill"
                ) {
                    isShowingPrivacy = true
                }
                .accessibilityIdentifier("waterup.settings.privacy")

                Divider()
                    .overlay(WaterUpTheme.Palette.divider.color)

                WaterUpSettingsStaticRow(
                    title: "版本信息",
                    detail: AppVersion.currentDisplay,
                    systemImage: "info.circle"
                )
                .accessibilityIdentifier("waterup.settings.version")
            }

            WaterUpStatusMessage(
                kind: .info,
                title: "全部数据仅保存在本机",
                message: "无需账号，离线也能完整使用。"
            )

            if isShowingReadError {
                WaterUpStatusMessage(
                    kind: .error,
                    title: "目标暂时无法读取",
                    message: "请稍后重试。"
                )
            }
        }
        .task {
            await loadSettingsSummary()
        }
        .onReceive(NotificationCenter.default.publisher(for: .waterUpGoalDidChange)) { _ in
            loadCurrentGoal()
        }
        .onReceive(NotificationCenter.default.publisher(for: .waterUpDrinkCatalogDidChange)) { _ in
            loadDrinkSummary()
        }
        .onReceive(NotificationCenter.default.publisher(for: .waterUpReminderConfigurationDidChange)) { _ in
            Task {
                await loadReminderSummary()
            }
        }
        .sheet(isPresented: $isShowingGoalSettings) {
            NavigationStack {
                GoalSettingsView()
            }
        }
        .navigationDestination(isPresented: $isShowingDrinkManagement) {
            DrinkManagementView()
        }
        .navigationDestination(isPresented: $isShowingReminderSettings) {
            ReminderSettingsView()
        }
        .navigationDestination(isPresented: $isShowingUnitExplanation) {
            UnitExplanationView()
        }
        .navigationDestination(isPresented: $isShowingPrivacy) {
            DataPrivacyView()
        }
    }

    private func loadSettingsSummary() async {
        loadCurrentGoal()
        loadDrinkSummary()
        await loadReminderSummary()
    }

    private func loadCurrentGoal() {
        do {
            let goal = try goalService.goal(for: .now, in: modelContext)
            targetDetail = "\(goal.targetML) mL"
            isShowingReadError = false
        } catch {
            targetDetail = "无法读取"
            isShowingReadError = true
        }
    }

    private func loadDrinkSummary() {
        do {
            let catalog = try drinkCatalogService.activeCatalog(in: modelContext)
            let customCount = catalog.custom.count

            if customCount == 0 {
                drinkDetail = "\(catalog.builtIn.count) 种内置"
            } else {
                drinkDetail = "\(catalog.builtIn.count) 种内置 · \(customCount) 种自定义"
            }
        } catch {
            drinkDetail = "无法读取"
        }
    }

    private func loadReminderSummary() async {
        do {
            let configuration = try reminderConfigurationService.configuration(in: modelContext)
            let authorizationStatus = await notificationAuthorizationService.currentStatus()

            if configuration.isEnabled, authorizationStatus.canScheduleReminders {
                reminderDetail = "已开启"
            } else if configuration.isEnabled {
                reminderDetail = "权限未开启"
            } else {
                reminderDetail = "已关闭"
            }
        } catch {
            reminderDetail = "无法读取"
        }
    }
}

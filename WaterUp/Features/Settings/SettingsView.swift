import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var targetDetail = "读取中"
    @State private var isShowingReadError = false
    @State private var isShowingGoalSettings = false

    private let goalService = GoalService()

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
            }

            if isShowingReadError {
                WaterUpStatusMessage(
                    kind: .error,
                    title: "目标暂时无法读取",
                    message: "请稍后重试。"
                )
            }
        }
        .task {
            loadCurrentGoal()
        }
        .onReceive(NotificationCenter.default.publisher(for: .waterUpGoalDidChange)) { _ in
            loadCurrentGoal()
        }
        .sheet(isPresented: $isShowingGoalSettings) {
            NavigationStack {
                GoalSettingsView()
            }
        }
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
}

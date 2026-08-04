import SwiftData
import SwiftUI

struct GoalSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var draft: GoalDraft?
    @State private var targetText = ""
    @State private var initialTargetML: Int?
    @State private var isLoading = true
    @State private var isShowingReadError = false
    @State private var saveErrorMessage: String?
    @State private var isSaved = false
    @FocusState private var isTargetInputFocused: Bool

    private let goalService = GoalService()

    var body: some View {
        WaterUpPage(title: "每日目标") {
            if isLoading {
                ProgressView("正在读取目标…")
                    .frame(maxWidth: .infinity, minHeight: 180)
            } else if isShowingReadError {
                WaterUpStatusMessage(
                    kind: .error,
                    title: "目标暂时无法读取",
                    message: "请稍后重试。"
                )

                WaterUpSecondaryButton(title: "重新读取", systemImage: "arrow.clockwise") {
                    loadDraft()
                }
            } else if let draft {
                goalEditor(draft)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("关闭") {
                    dismiss()
                }
            }
        }
        .task {
            loadDraft()
        }
    }

    @ViewBuilder
    private func goalEditor(_ draft: GoalDraft) -> some View {
        WaterUpCard {
            VStack(spacing: WaterUpTheme.Spacing.x4) {
                HStack {
                    Text("今日目标")
                        .font(WaterUpTheme.Typography.headline)
                        .foregroundStyle(WaterUpTheme.Palette.textPrimary.color)

                    Spacer()

                    Text("每次调整 100 mL")
                        .font(WaterUpTheme.Typography.callout)
                        .foregroundStyle(WaterUpTheme.Palette.textMuted.color)
                }

                HStack(spacing: WaterUpTheme.Spacing.x4) {
                    goalAdjustButton(
                        systemImage: "minus",
                        accessibilityLabel: "减少 100 mL",
                        isEnabled: isTargetInputValid && draft.canDecrease
                    ) {
                        adjustGoal(isIncreasing: false)
                    }

                    VStack(spacing: WaterUpTheme.Spacing.x1) {
                        TextField("每日目标", text: targetTextBinding)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .font(.system(size: 46, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(
                                isTargetInputValid
                                    ? WaterUpTheme.Palette.textPrimary.color
                                    : WaterUpTheme.Palette.statusError.color
                            )
                            .focused($isTargetInputFocused)
                            .accessibilityLabel("每日目标，单位毫升")
                            .accessibilityIdentifier("waterup.goal.target-input")

                        Text("mL / 天")
                            .font(WaterUpTheme.Typography.callout)
                            .foregroundStyle(WaterUpTheme.Palette.textMuted.color)
                    }
                    .frame(maxWidth: .infinity)

                    goalAdjustButton(
                        systemImage: "plus",
                        accessibilityLabel: "增加 100 mL",
                        isEnabled: isTargetInputValid && draft.canIncrease
                    ) {
                        adjustGoal(isIncreasing: true)
                    }
                }

                Divider()

                HStack(spacing: WaterUpTheme.Spacing.x2) {
                    ForEach([1_500, 2_000, 2_500], id: \.self) { targetML in
                        quickTargetButton(targetML)
                    }
                }

                if !isTargetInputValid {
                    Text("请输入 500–5000 mL 之间且为 100 mL 步长的目标")
                        .font(WaterUpTheme.Typography.caption)
                        .foregroundStyle(WaterUpTheme.Palette.statusError.color)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }

        WaterUpStatusMessage(
            kind: .info,
            title: "从今天开始生效",
            message: "新目标从今天开始生效，不会改变过去日期的目标。"
        )

        if let saveErrorMessage {
            WaterUpStatusMessage(
                kind: .error,
                title: "目标未保存",
                message: saveErrorMessage
            )
        }

        if isSaved {
            WaterUpStatusMessage(
                kind: .success,
                title: "目标已保存",
                message: "今日进度已按新目标更新。"
            )
        }

        WaterUpPrimaryButton(title: "保存目标", systemImage: "checkmark") {
            saveDraft()
        }
        .disabled(!isSaveEnabled)
        .opacity(isSaveEnabled ? 1 : 0.55)
        .accessibilityIdentifier("waterup.goal.save")
    }

    private var targetTextBinding: Binding<String> {
        Binding(
            get: { targetText },
            set: { updateTargetText($0) }
        )
    }

    private var targetML: Int? {
        guard let value = Int(targetText) else {
            return nil
        }

        do {
            try GoalValidator.validate(targetML: value)
            return value
        } catch {
            return nil
        }
    }

    private var isTargetInputValid: Bool {
        targetML != nil
    }

    private var isSaveEnabled: Bool {
        guard let targetML else {
            return false
        }

        return targetML != initialTargetML
    }

    private func quickTargetButton(_ targetML: Int) -> some View {
        let isSelected = self.targetML == targetML

        return Button("\(targetML)") {
            selectTarget(targetML)
        }
        .font(WaterUpTheme.Typography.headline)
        .foregroundStyle(
            isSelected
                ? WaterUpTheme.Palette.actionPressed.color
                : WaterUpTheme.Palette.textSecondary.color
        )
        .frame(maxWidth: .infinity, minHeight: WaterUpTheme.Layout.minimumTapTarget)
        .background(
            isSelected
                ? WaterUpTheme.Palette.backgroundTint.color
                : WaterUpTheme.Palette.surfaceSecondary.color,
            in: Capsule()
        )
        .overlay {
            Capsule()
                .stroke(
                    isSelected
                        ? WaterUpTheme.Palette.actionPrimary.color
                        : WaterUpTheme.Palette.divider.color,
                    lineWidth: isSelected ? 2 : 1
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("快捷设置 \(targetML) mL")
        .accessibilityIdentifier("waterup.goal.quick-\(targetML)")
    }

    private func goalAdjustButton(
        systemImage: String,
        accessibilityLabel: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title2.weight(.semibold))
                .frame(
                    width: WaterUpTheme.Layout.minimumTapTarget,
                    height: WaterUpTheme.Layout.minimumTapTarget
                )
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .disabled(!isEnabled)
        .accessibilityLabel(accessibilityLabel)
    }

    private func loadDraft() {
        isLoading = true
        isShowingReadError = false

        do {
            let goal = try goalService.goal(for: .now, in: modelContext)
            draft = try GoalDraft(targetML: goal.targetML)
            targetText = "\(goal.targetML)"
            initialTargetML = goal.targetML
            saveErrorMessage = nil
            isSaved = false
        } catch {
            draft = nil
            initialTargetML = nil
            isShowingReadError = true
        }

        isLoading = false
    }

    private func adjustGoal(isIncreasing: Bool) {
        guard var draft else {
            return
        }

        if isIncreasing {
            draft.increase()
        } else {
            draft.decrease()
        }

        self.draft = draft
        targetText = "\(draft.targetML)"
        isSaved = false
        saveErrorMessage = nil
    }

    private func updateTargetText(_ text: String) {
        targetText = text
        isSaved = false
        saveErrorMessage = nil

        guard let targetML else {
            return
        }

        draft = try? GoalDraft(targetML: targetML)
    }

    private func selectTarget(_ targetML: Int) {
        guard let draft = try? GoalDraft(targetML: targetML) else {
            return
        }

        self.draft = draft
        targetText = "\(targetML)"
        isSaved = false
        saveErrorMessage = nil
        isTargetInputFocused = false
    }

    private func saveDraft() {
        guard let targetML else {
            return
        }

        do {
            try GoalValidator.validate(targetML: targetML)
            // Reminder rescheduling is intentionally deferred to F10, where ReminderScheduler is introduced.
            try goalService.upsertToday(targetML: targetML, now: .now, in: modelContext)
            try PersistenceService.saveChanges(in: modelContext)

            initialTargetML = targetML
            saveErrorMessage = nil
            isSaved = true
            NotificationCenter.default.post(name: .waterUpGoalDidChange, object: nil)
        } catch {
            // The draft is retained so the person can retry after a transient persistence failure.
            saveErrorMessage = "请稍后重试，当前设置未改变。"
            isSaved = false
        }
    }
}

import SwiftData
import SwiftUI
import UIKit

struct ReminderSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @State private var isLoading = true
    @State private var isShowingReadError = false
    @State private var isReminderEnabled = false
    @State private var startTime = Date.now
    @State private var endTime = Date.now
    @State private var intervalMinutes = 120
    @State private var authorizationStatus: ReminderAuthorizationStatus = .notDetermined
    @State private var nextReminderDate: Date?
    @State private var validationError: ReminderDraftValidationError?
    @State private var saveErrorMessage: String?
    @State private var saveErrorTitle = "提醒未保存"
    @State private var saveConfirmation: String?
    @State private var isSaving = false

    private let configurationService = ReminderConfigurationService()
    private let authorizationService = NotificationAuthorizationService()
    private let schedulingService = ReminderSchedulingService()

    var body: some View {
        WaterUpPage(title: "饮水提醒") {
            Text("仅使用本地通知")
                .font(WaterUpTheme.Typography.callout)
                .foregroundStyle(WaterUpTheme.Palette.textMuted.color)

            if isLoading {
                ProgressView("正在读取提醒设置…")
                    .frame(maxWidth: .infinity, minHeight: 180)
            } else if isShowingReadError {
                WaterUpStatusMessage(
                    kind: .error,
                    title: "提醒设置暂时无法读取",
                    message: "本地提醒配置暂时不可用，请重新读取后再修改。"
                )

                WaterUpSecondaryButton(title: "重新读取", systemImage: "arrow.clockwise") {
                    Task {
                        await loadConfiguration()
                    }
                }
            } else {
                reminderContent
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
            await loadConfiguration()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    await refreshAuthorizationStatus()
                }
            }
        }
    }

    @ViewBuilder
    private var reminderContent: some View {
        WaterUpCard {
            Toggle(isOn: reminderEnabledBinding) {
                Label("开启提醒", systemImage: "bell.fill")
                    .font(WaterUpTheme.Typography.title2)
                    .foregroundStyle(WaterUpTheme.Palette.textPrimary.color)
            }
            .tint(WaterUpTheme.Palette.actionPrimary.color)
            .disabled(isSaving)
            .accessibilityIdentifier("waterup.reminder.enabled")
        }

        nextReminderCard

        WaterUpSectionTitle("提醒时段")
        WaterUpCard {
            VStack(spacing: 0) {
                reminderTimePicker(
                    title: "起始时间",
                    systemImage: "calendar",
                    selection: $startTime
                )

                Divider()
                    .overlay(WaterUpTheme.Palette.divider.color)

                reminderTimePicker(
                    title: "结束时间",
                    systemImage: "calendar",
                    selection: $endTime
                )

                Divider()
                    .overlay(WaterUpTheme.Palette.divider.color)

                intervalPicker

                Divider()
                    .overlay(WaterUpTheme.Palette.divider.color)

                HStack(spacing: WaterUpTheme.Spacing.x3) {
                    Text("达标后停止")
                        .font(WaterUpTheme.Typography.headline)
                        .foregroundStyle(WaterUpTheme.Palette.textPrimary.color)

                    Spacer()

                    Label("固定开启", systemImage: "checkmark.circle.fill")
                        .font(WaterUpTheme.Typography.callout)
                        .foregroundStyle(WaterUpTheme.Palette.statusSuccess.color)
                }
                .frame(minHeight: WaterUpTheme.Layout.minimumTapTarget)
                .accessibilityLabel("达到目标后停止，固定开启")
            }
            .disabled(!isReminderEnabled)
            .opacity(isReminderEnabled ? 1 : 0.58)
        }

        if let validationError {
            WaterUpStatusMessage(
                kind: .error,
                title: "提醒时段无效",
                message: validationError.message
            )
        }

        if authorizationStatus == .denied {
            WaterUpStatusMessage(
                kind: .error,
                title: "通知权限未开启",
                message: "请在系统设置中允许 WaterUp 发送通知后再开启提醒。"
            )

            WaterUpSecondaryButton(title: "前往系统设置", systemImage: "gear") {
                openSystemSettings()
            }
        }

        if let saveErrorMessage {
            WaterUpStatusMessage(kind: .error, title: saveErrorTitle, message: saveErrorMessage)
        }

        if let saveConfirmation {
            WaterUpStatusMessage(kind: .success, title: "提醒已保存", message: saveConfirmation)
        }

        WaterUpStatusMessage(
            kind: .info,
            title: "通知时间可能略有延迟",
            message: "系统会根据设备状态投递通知，WaterUp 不承诺秒级准时。"
        )

        WaterUpPrimaryButton(title: "保存提醒", systemImage: "checkmark") {
            Task {
                await saveConfiguration()
            }
        }
        .disabled(!canSave || isSaving)
        .opacity(canSave && !isSaving ? 1 : 0.55)
        .accessibilityIdentifier("waterup.reminder.save")
    }

    private var reminderEnabledBinding: Binding<Bool> {
        Binding(
            get: { isReminderEnabled },
            set: { newValue in
                Task {
                    await updateReminderEnabled(newValue)
                }
            }
        )
    }

    private var nextReminderCard: some View {
        WaterUpStatusMessage(
            kind: isReminderEnabled ? .success : .info,
            title: nextReminderTitle,
            message: isReminderEnabled ? "达到目标后当天自动停止" : "开启后会按设定时间在本机提醒。"
        )
    }

    private var nextReminderTitle: String {
        guard isReminderEnabled else {
            return "提醒尚未开启"
        }

        guard let nextReminderDate else {
            return "今日没有后续提醒"
        }

        if Calendar.autoupdatingCurrent.isDateInToday(nextReminderDate) {
            return "下一次提醒 \(Self.timeFormatter.string(from: nextReminderDate))"
        }

        return "下一次提醒 明日 \(Self.timeFormatter.string(from: nextReminderDate))"
    }

    private var intervalPicker: some View {
        HStack(spacing: WaterUpTheme.Spacing.x3) {
            Image(systemName: "bell.fill")
                .foregroundStyle(WaterUpTheme.Palette.actionPrimary.color)
                .frame(width: WaterUpTheme.Layout.minimumTapTarget, height: WaterUpTheme.Layout.minimumTapTarget)

            VStack(alignment: .leading, spacing: WaterUpTheme.Spacing.x1) {
                Text("提醒间隔")
                    .font(WaterUpTheme.Typography.caption)
                    .foregroundStyle(WaterUpTheme.Palette.textMuted.color)

                Picker("提醒间隔", selection: $intervalMinutes) {
                    ForEach(ReminderScheduleConfiguration.allowedIntervals, id: \.self) { interval in
                        Text("\(interval) 分钟").tag(interval)
                    }
                }
                .font(WaterUpTheme.Typography.title2)
                .tint(WaterUpTheme.Palette.textPrimary.color)
                .labelsHidden()
                .pickerStyle(.menu)
                .accessibilityIdentifier("waterup.reminder.interval")
            }

            Spacer()
        }
        .frame(minHeight: 72)
    }

    private func reminderTimePicker(
        title: String,
        systemImage: String,
        selection: Binding<Date>
    ) -> some View {
        HStack(spacing: WaterUpTheme.Spacing.x3) {
            Image(systemName: systemImage)
                .foregroundStyle(WaterUpTheme.Palette.actionPrimary.color)
                .frame(width: WaterUpTheme.Layout.minimumTapTarget, height: WaterUpTheme.Layout.minimumTapTarget)

            VStack(alignment: .leading, spacing: WaterUpTheme.Spacing.x1) {
                Text(title)
                    .font(WaterUpTheme.Typography.caption)
                    .foregroundStyle(WaterUpTheme.Palette.textMuted.color)

                DatePicker(title, selection: selection, displayedComponents: .hourAndMinute)
                    .font(WaterUpTheme.Typography.title2)
                    .labelsHidden()
                    .accessibilityLabel(title)
            }

            Spacer()
        }
        .frame(minHeight: 72)
        .onChange(of: selection.wrappedValue) { _, _ in
            validationError = nil
            saveConfirmation = nil
            saveErrorMessage = nil
        }
    }

    private var canSave: Bool {
        guard !isLoading else {
            return false
        }

        return isReminderEnabled ? authorizationStatus.canScheduleReminders : true
    }

    private func loadConfiguration() async {
        isLoading = true
        isShowingReadError = false
        saveErrorMessage = nil

        do {
            let configuration = try configurationService.configuration(in: modelContext)
            let draft = try ReminderScheduleConfiguration(configuration: configuration)
            isReminderEnabled = draft.isEnabled
            startTime = date(for: draft.startMinuteOfDay)
            endTime = date(for: draft.endMinuteOfDay)
            intervalMinutes = draft.intervalMinutes
            authorizationStatus = await authorizationService.currentStatus()

            if draft.isEnabled, authorizationStatus.canScheduleReminders {
                let result = try await schedulingService.synchronize(in: modelContext)
                applySchedulingResult(result)
            } else if draft.isEnabled {
                isReminderEnabled = false
                nextReminderDate = nil
            }
        } catch {
            nextReminderDate = nil
            isShowingReadError = true
        }

        isLoading = false
    }

    private func updateReminderEnabled(_ newValue: Bool) async {
        guard newValue else {
            isReminderEnabled = false
            await saveConfiguration()
            return
        }

        let currentStatus = await authorizationService.currentStatus()
        let resolvedStatus: ReminderAuthorizationStatus

        if currentStatus == .notDetermined {
            resolvedStatus = await authorizationService.requestAuthorization()
        } else {
            resolvedStatus = currentStatus
        }

        authorizationStatus = resolvedStatus
        guard resolvedStatus.canScheduleReminders else {
            isReminderEnabled = false
            nextReminderDate = nil
            return
        }

        isReminderEnabled = true
        await saveConfiguration()
    }

    private func saveConfiguration() async {
        guard !isSaving else {
            return
        }

        isSaving = true
        defer { isSaving = false }

        saveErrorTitle = "提醒未保存"
        saveErrorMessage = nil
        saveConfirmation = nil

        let configuration: ReminderScheduleConfiguration
        do {
            configuration = try ReminderScheduleConfiguration(
                isEnabled: isReminderEnabled,
                startMinuteOfDay: minuteOfDay(for: startTime),
                endMinuteOfDay: minuteOfDay(for: endTime),
                intervalMinutes: intervalMinutes
            )
        } catch let error as ReminderDraftValidationError {
            validationError = error
            saveConfirmation = nil
            return
        } catch {
            saveErrorTitle = "提醒未保存"
            saveErrorMessage = "提醒设置暂时无法保存，请稍后重试。"
            saveConfirmation = nil
            return
        }

        do {
            try configurationService.save(configuration: configuration, in: modelContext)
        } catch {
            saveErrorTitle = "提醒未保存"
            saveErrorMessage = "提醒设置暂时无法保存，请稍后重试。"
            saveConfirmation = nil
            return
        }

        // Configuration persistence is independent from notification scheduling.
        // Publish after this attempt so other screens refresh from the saved source of truth.
        defer {
            NotificationCenter.default.post(name: .waterUpReminderConfigurationDidChange, object: nil)
        }

        do {
            let result = try await schedulingService.synchronize(in: modelContext)
            applySchedulingResult(result)
        } catch {
            nextReminderDate = nil
            saveErrorTitle = "提醒计划未更新"
            saveErrorMessage = "提醒设置已保存，但本地通知计划暂时无法更新。请重试保存提醒。"
            saveConfirmation = nil
        }
    }

    private func applySchedulingResult(_ result: ReminderSchedulingResult) {
        switch result {
        case .disabled:
            nextReminderDate = nil
            saveConfirmation = "提醒已关闭，WaterUp 的待处理通知已取消。"
        case .authorizationUnavailable:
            isReminderEnabled = false
            authorizationStatus = .denied
            nextReminderDate = nil
            saveConfirmation = nil
        case let .scheduled(nextReminderDate):
            self.nextReminderDate = nextReminderDate
            saveConfirmation = nextReminderDate == nil
                ? "当前没有可安排的提醒，达到目标后当天不会继续提醒。"
                : "已按当前时段生成本地提醒计划。"
        }

        validationError = nil
        saveErrorMessage = nil
    }

    private func refreshAuthorizationStatus() async {
        let currentStatus = await authorizationService.currentStatus()
        authorizationStatus = currentStatus

        if isReminderEnabled, !currentStatus.canScheduleReminders {
            isReminderEnabled = false
            nextReminderDate = nil
        }
    }

    private func minuteOfDay(for date: Date) -> Int {
        let components = Calendar.autoupdatingCurrent.dateComponents([.hour, .minute], from: date)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        return hour * 60 + minute
    }

    private func date(for minuteOfDay: Int) -> Date {
        let hour = minuteOfDay / 60
        let minute = minuteOfDay % 60
        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.startOfDay(for: .now)
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today) ?? today
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }

        UIApplication.shared.open(url)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

#Preview {
    NavigationStack {
        ReminderSettingsView()
    }
    .modelContainer(WaterUpPreviewData.makeModelContainer())
}

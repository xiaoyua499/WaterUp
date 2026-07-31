import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    let onShowAllRecords: () -> Void

    @State private var dashboard: TodayDashboard?
    @State private var isLoading = true
    @State private var isShowingReadError = false
    @State private var actionError: TodayActionError?
    @State private var undoState: QuickRecordUndoState?
    @State private var recordFormRoute: RecordFormRoute?

    private let dashboardService = TodayDashboardService()
    private let recordService = RecordService()
    private let hydrationExplanationService = HydrationExplanationService()

    init(onShowAllRecords: @escaping () -> Void) {
        self.onShowAllRecords = onShowAllRecords
    }

    var body: some View {
        WaterUpPage(title: "今日") {
            if isLoading {
                TodayLoadingView()
            } else if isShowingReadError {
                TodayReadErrorView(onRetry: reload)
            } else if let dashboard {
                loadedContent(for: dashboard)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let undoState {
                QuickRecordUndoBanner(
                    message: undoState.message,
                    onUndo: undoQuickRecord
                )
                .padding(.horizontal, WaterUpTheme.Spacing.x4)
                .padding(.bottom, WaterUpTheme.Spacing.x2)
                .transition(reduceMotion ? .identity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
        .task {
            reload()
        }
        .task(id: undoState?.recordID) {
            guard let undoState else {
                return
            }

            do {
                try await Task.sleep(for: .seconds(WaterUpTheme.Motion.undoTimeout))
            } catch {
                return
            }

            guard !Task.isCancelled, self.undoState?.recordID == undoState.recordID else {
                return
            }

            setUndoState(nil)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                reload()
            }
        }
        .sheet(item: $recordFormRoute) { route in
            NavigationStack {
                RecordFormView(route: route, onSaved: reload)
            }
        }
        .animation(
            reduceMotion ? nil : .easeInOut(duration: WaterUpTheme.Motion.confirmationDuration),
            value: undoState?.recordID
        )
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func loadedContent(for dashboard: TodayDashboard) -> some View {
        TodayDateHeader(date: dashboard.date)
        TodayProgressRing(summary: dashboard.summary)

        if dashboard.shouldShowHydrationExplanation {
            HydrationExplanationCard(onDismiss: markHydrationExplanationAsShown)
        }

        if let actionError {
            TodayActionErrorView(
                message: actionError.message,
                canRetry: actionError.drinkID != nil,
                onRetry: retryQuickRecord
            )
        }

        WaterUpSectionTitle("快速添加", detail: "默认杯量")
        FavoriteDrinkGrid(
            drinks: dashboard.favoriteDrinks,
            onOpenForm: openRecordForm,
            onQuickAdd: createQuickRecord
        )

        recentRecordsSection(for: dashboard)

        if let defaultWater = dashboard.defaultWater {
            WaterUpPrimaryButton(
                title: "记录饮品",
                systemImage: "plus"
            ) {
                openRecordForm(defaultWater.id)
            }
            .accessibilityIdentifier("waterup.today.record-drink")
        }
    }

    @ViewBuilder
    private func recentRecordsSection(for dashboard: TodayDashboard) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text("最近记录")
                .font(WaterUpTheme.Typography.title2)
                .foregroundStyle(WaterUpTheme.Palette.textPrimary.color)

            Spacer(minLength: WaterUpTheme.Spacing.x3)

            if dashboard.hasMoreRecords {
                Button("查看全部", action: onShowAllRecords)
                    .font(WaterUpTheme.Typography.callout)
                    .foregroundStyle(WaterUpTheme.Palette.actionPrimary.color)
                    .accessibilityHint("切换到历史页面查看全部记录")
            }
        }

        WaterUpCard {
            if dashboard.recentRecords.isEmpty {
                TodayRecordEmptyState()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(dashboard.recentRecords.enumerated()), id: \.element.id) { index, record in
                        NavigationLink {
                            RecordDetailView(recordID: record.id, onChanged: reload)
                        } label: {
                            TodayRecordRow(record: record)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            "\(record.drinkNameSnapshot)，\(TodayDateFormatter.time.string(from: record.consumedAt))记录，饮品容量 \(record.volumeML) mL，有效补水 \(record.effectiveHydrationML) mL"
                        )
                        .accessibilityHint("打开记录详情")
                        .accessibilityIdentifier("waterup.today.record-row")

                        if index < dashboard.recentRecords.count - 1 {
                            Divider()
                                .overlay(WaterUpTheme.Palette.divider.color)
                                .padding(.vertical, WaterUpTheme.Spacing.x3)
                        }
                    }
                }
            }
        }
    }

    private func reload() {
        isLoading = true
        isShowingReadError = false

        do {
            dashboard = try dashboardService.dashboard(in: modelContext)
        } catch {
            dashboard = nil
            isShowingReadError = true
        }

        isLoading = false
    }

    private func createQuickRecord(_ drinkID: UUID) {
        actionError = nil

        do {
            let result = try recordService.createQuickRecord(
                forDrinkID: drinkID,
                in: modelContext
            )
            reload()
            setUndoState(
                QuickRecordUndoState(
                    recordID: result.recordID,
                    message: "已记录 \(result.drinkName) \(result.volumeML) mL，有效补水 \(result.effectiveHydrationML) mL"
                )
            )
        } catch {
            actionError = TodayActionError(
                drinkID: drinkID,
                message: "记录未保存，请重试。"
            )
        }
    }

    private func openRecordForm(_ drinkID: UUID) {
        recordFormRoute = .create(drinkID: drinkID, consumedAt: .now)
    }

    private func retryQuickRecord() {
        guard let drinkID = actionError?.drinkID else {
            return
        }

        createQuickRecord(drinkID)
    }

    private func undoQuickRecord() {
        guard let undoState else {
            return
        }

        actionError = nil

        do {
            try recordService.deleteRecord(id: undoState.recordID, in: modelContext)
            reload()
            setUndoState(nil)
        } catch {
            actionError = TodayActionError(
                drinkID: nil,
                message: "撤销未完成，记录仍已保留。"
            )
        }
    }

    private func markHydrationExplanationAsShown() {
        do {
            try hydrationExplanationService.markAsShown(in: modelContext)
            reload()
        } catch {
            actionError = TodayActionError(
                drinkID: nil,
                message: "暂时无法保存说明状态，请稍后重试。"
            )
        }
    }

    private func setUndoState(_ newState: QuickRecordUndoState?) {
        if reduceMotion {
            undoState = newState
        } else {
            withAnimation(.easeInOut(duration: WaterUpTheme.Motion.confirmationDuration)) {
                undoState = newState
            }
        }
    }
}

private struct TodayActionError: Equatable {
    let drinkID: UUID?
    let message: String
}

private struct QuickRecordUndoState: Equatable {
    let recordID: UUID
    let message: String
}

private struct TodayDateHeader: View {
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: WaterUpTheme.Spacing.x1) {
            Text(TodayDateFormatter.header.string(from: date))
                .font(WaterUpTheme.Typography.title1)
                .foregroundStyle(WaterUpTheme.Palette.textPrimary.color)

            Text("今天")
                .font(WaterUpTheme.Typography.callout)
                .foregroundStyle(WaterUpTheme.Palette.textMuted.color)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct TodayProgressRing: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let summary: DailyHydrationSummary

    private var percentage: Int {
        Int((summary.progress * 100).rounded())
    }

    private var statusTitle: String {
        if summary.totalEffectiveHydrationML == 0 {
            return "等待第一杯"
        }

        if summary.progress > 1 {
            return "已超额 \(summary.totalEffectiveHydrationML - summary.targetML) mL"
        }

        if summary.progress == 1 {
            return "今日已达标"
        }

        return "有效补水"
    }

    var body: some View {
        VStack(spacing: WaterUpTheme.Spacing.x4) {
            GeometryReader { proxy in
                let sideLength = min(proxy.size.width, 296)

                ZStack {
                    Circle()
                        .stroke(
                            WaterUpTheme.Palette.divider.color.opacity(0.85),
                            style: StrokeStyle(lineWidth: 18, lineCap: .round)
                        )

                    if summary.ringProgress > 0 {
                        Circle()
                            .trim(from: 0, to: summary.ringProgress)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        WaterUpTheme.Palette.hydrationProgressStart.color,
                                        WaterUpTheme.Palette.hydrationProgressEnd.color
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 18, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                    }

                    VStack(spacing: WaterUpTheme.Spacing.x1) {
                        Image(systemName: "drop.fill")
                            .font(.title2)
                            .foregroundStyle(WaterUpTheme.Palette.actionPrimary.color)
                            .accessibilityHidden(true)

                        WaterUpDisplayText(value: "\(percentage)%")

                        Text(statusTitle)
                            .font(WaterUpTheme.Typography.callout)
                            .foregroundStyle(WaterUpTheme.Palette.textSecondary.color)
                            .multilineTextAlignment(.center)

                        HStack(alignment: .lastTextBaseline, spacing: WaterUpTheme.Spacing.x1) {
                            Text("\(summary.totalEffectiveHydrationML)")
                                .font(.system(.title2, design: .rounded).weight(.bold).monospacedDigit())
                                .foregroundStyle(WaterUpTheme.Palette.textPrimary.color)

                            Text("mL")
                                .font(WaterUpTheme.Typography.callout)
                                .foregroundStyle(WaterUpTheme.Palette.textSecondary.color)
                        }
                    }
                    .padding(WaterUpTheme.Spacing.x6)
                }
                .frame(width: sideLength, height: sideLength)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: 296)

            HStack(spacing: WaterUpTheme.Spacing.x3) {
                TodayMetric(
                    title: "目标",
                    value: "\(summary.targetML) mL",
                    systemImage: "target"
                )

                TodayMetric(
                    title: "剩余",
                    value: "\(summary.remainingML) mL",
                    systemImage: summary.remainingML == 0 ? "checkmark.circle.fill" : "drop"
                )
            }
        }
        .padding(.vertical, WaterUpTheme.Spacing.x2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "今日补水进度 \(percentage)%，有效补水 \(summary.totalEffectiveHydrationML) mL，目标 \(summary.targetML) mL，剩余 \(summary.remainingML) mL，\(statusTitle)"
        )
        .animation(
            reduceMotion ? nil : .easeInOut(duration: WaterUpTheme.Motion.progressDuration),
            value: summary.ringProgress
        )
    }
}

private struct TodayMetric: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: WaterUpTheme.Spacing.x2) {
            Image(systemName: systemImage)
                .foregroundStyle(WaterUpTheme.Palette.actionPrimary.color)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(WaterUpTheme.Typography.caption)
                    .foregroundStyle(WaterUpTheme.Palette.textMuted.color)

                Text(value)
                    .font(WaterUpTheme.Typography.headline)
                    .foregroundStyle(WaterUpTheme.Palette.textPrimary.color)
                    .monospacedDigit()
            }
        }
        .padding(WaterUpTheme.Spacing.x3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            WaterUpTheme.Palette.surfaceSecondary.color,
            in: RoundedRectangle(cornerRadius: WaterUpTheme.Radius.medium, style: .continuous)
        )
    }
}

private struct FavoriteDrinkGrid: View {
    let drinks: [DrinkDefinition]
    let onOpenForm: (UUID) -> Void
    let onQuickAdd: (UUID) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 76, maximum: 104), spacing: WaterUpTheme.Spacing.x3)
    ]

    var body: some View {
        if drinks.isEmpty {
            WaterUpCard {
                WaterUpEmptyState(
                    systemImage: "cup.and.saucer",
                    title: "还没有常用饮品",
                    message: "可在饮品管理中加入常用饮品。"
                )
            }
        } else {
            LazyVGrid(columns: columns, spacing: WaterUpTheme.Spacing.x3) {
                ForEach(drinks, id: \.id) { drink in
                    FavoriteDrinkButton(
                        drink: drink,
                        onOpenForm: { onOpenForm(drink.id) },
                        onQuickAdd: { onQuickAdd(drink.id) }
                    )
                }
            }
        }
    }
}

private struct FavoriteDrinkButton: View {
    let drink: DrinkDefinition
    let onOpenForm: () -> Void
    let onQuickAdd: () -> Void

    private var quickAddIdentifier: String {
        if let seedKey = drink.seedKey {
            return "waterup.today.quick-add.\(seedKey)"
        }

        return "waterup.today.quick-add.\(drink.id.uuidString)"
    }

    var body: some View {
        VStack(spacing: WaterUpTheme.Spacing.x2) {
            Button(action: onOpenForm) {
                VStack(spacing: WaterUpTheme.Spacing.x2) {
                    Image(drink.iconKey)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                        .accessibilityHidden(true)

                    Text(drink.name)
                        .font(WaterUpTheme.Typography.headline)
                        .foregroundStyle(WaterUpTheme.Palette.textPrimary.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Text("\(drink.defaultVolumeML) mL")
                        .font(WaterUpTheme.Typography.caption)
                        .foregroundStyle(WaterUpTheme.Palette.textMuted.color)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("编辑 \(drink.name) 记录")
            .accessibilityHint("可调整容量、时间和备注后保存")

            Button(action: onQuickAdd) {
                Label("快速记录", systemImage: "plus.circle.fill")
                    .font(WaterUpTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(WaterUpTheme.Palette.actionPrimary.color)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .frame(minHeight: WaterUpTheme.Layout.minimumTapTarget)
            .accessibilityLabel("快速添加 \(drink.name)，默认 \(drink.defaultVolumeML) mL")
            .accessibilityHint("立即创建一条饮水记录")
            .accessibilityIdentifier(quickAddIdentifier)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 166)
        .padding(.horizontal, WaterUpTheme.Spacing.x2)
        .padding(.vertical, WaterUpTheme.Spacing.x3)
        .background(
            WaterUpTheme.Palette.surfacePrimary.color,
            in: RoundedRectangle(cornerRadius: WaterUpTheme.Radius.medium, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: WaterUpTheme.Radius.medium, style: .continuous)
                .stroke(WaterUpTheme.Palette.divider.color, lineWidth: 1)
        }
    }
}

private struct TodayRecordRow: View {
    let record: HydrationRecord

    var body: some View {
        HStack(spacing: WaterUpTheme.Spacing.x3) {
            Image(record.iconKeySnapshot)
                .resizable()
                .scaledToFit()
                .frame(width: 42, height: 42)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: WaterUpTheme.Spacing.x1) {
                Text(record.drinkNameSnapshot)
                    .font(WaterUpTheme.Typography.headline)
                    .foregroundStyle(WaterUpTheme.Palette.textPrimary.color)

                Text(TodayDateFormatter.time.string(from: record.consumedAt))
                    .font(WaterUpTheme.Typography.caption)
                    .foregroundStyle(WaterUpTheme.Palette.textMuted.color)
            }

            Spacer(minLength: WaterUpTheme.Spacing.x3)

            VStack(alignment: .trailing, spacing: WaterUpTheme.Spacing.x1) {
                Text("饮品容量 \(record.volumeML) mL")
                    .font(WaterUpTheme.Typography.callout)
                    .foregroundStyle(WaterUpTheme.Palette.textSecondary.color)

                Text("有效补水 \(record.effectiveHydrationML) mL")
                    .font(WaterUpTheme.Typography.caption)
                    .foregroundStyle(WaterUpTheme.Palette.actionPrimary.color)
            }
            .monospacedDigit()
        }
    }
}

private struct TodayRecordEmptyState: View {
    var body: some View {
        HStack(spacing: WaterUpTheme.Spacing.x3) {
            Image(systemName: "drop.circle")
                .font(.title2)
                .foregroundStyle(WaterUpTheme.Palette.actionPrimary.color)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: WaterUpTheme.Spacing.x1) {
                Text("还没有饮水记录")
                    .font(WaterUpTheme.Typography.headline)
                    .foregroundStyle(WaterUpTheme.Palette.textPrimary.color)

                Text("从上方常用饮品开始记录")
                    .font(WaterUpTheme.Typography.body)
                    .foregroundStyle(WaterUpTheme.Palette.textSecondary.color)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct HydrationExplanationCard: View {
    let onDismiss: () -> Void

    var body: some View {
        WaterUpCard {
            VStack(alignment: .leading, spacing: WaterUpTheme.Spacing.x3) {
                WaterUpStatusMessage(
                    kind: .info,
                    title: "有效补水量是估算值",
                    message: "饮品容量会按含水比例折算为有效补水量，用于个人记录和习惯管理。"
                )

                Button("知道了", action: onDismiss)
                    .font(WaterUpTheme.Typography.callout)
                    .foregroundStyle(WaterUpTheme.Palette.actionPrimary.color)
                    .frame(minHeight: WaterUpTheme.Layout.minimumTapTarget)
            }
        }
    }
}

private struct TodayActionErrorView: View {
    let message: String
    let canRetry: Bool
    let onRetry: () -> Void

    var body: some View {
        WaterUpCard {
            VStack(alignment: .leading, spacing: WaterUpTheme.Spacing.x3) {
                WaterUpStatusMessage(
                    kind: .error,
                    title: "操作未完成",
                    message: message
                )

                if canRetry {
                    WaterUpSecondaryButton(
                        title: "重试",
                        systemImage: "arrow.clockwise",
                        action: onRetry
                    )
                }
            }
        }
    }
}

private struct TodayReadErrorView: View {
    let onRetry: () -> Void

    var body: some View {
        WaterUpCard {
            VStack(spacing: WaterUpTheme.Spacing.x4) {
                WaterUpEmptyState(
                    systemImage: "exclamationmark.triangle.fill",
                    title: "数据暂时无法读取",
                    message: "未显示 0 mL，以免将读取错误误认为今日无记录。"
                )

                WaterUpPrimaryButton(
                    title: "重新读取",
                    systemImage: "arrow.clockwise",
                    action: onRetry
                )
            }
        }
    }
}

private struct TodayLoadingView: View {
    var body: some View {
        WaterUpCard {
            HStack(spacing: WaterUpTheme.Spacing.x3) {
                ProgressView()
                    .tint(WaterUpTheme.Palette.actionPrimary.color)

                Text("正在读取今日记录…")
                    .font(WaterUpTheme.Typography.body)
                    .foregroundStyle(WaterUpTheme.Palette.textSecondary.color)
            }
            .frame(minHeight: 140)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct QuickRecordUndoBanner: View {
    let message: String
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: WaterUpTheme.Spacing.x3) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(WaterUpTheme.Palette.statusSuccess.color)
                .accessibilityHidden(true)

            Text(message)
                .font(WaterUpTheme.Typography.callout)
                .foregroundStyle(WaterUpTheme.Palette.textPrimary.color)
                .lineLimit(2)

            Spacer(minLength: WaterUpTheme.Spacing.x2)

            Button("撤销", action: onUndo)
                .font(WaterUpTheme.Typography.headline)
                .foregroundStyle(WaterUpTheme.Palette.actionPrimary.color)
                .frame(minHeight: WaterUpTheme.Layout.minimumTapTarget)
        }
        .padding(.horizontal, WaterUpTheme.Spacing.x4)
        .padding(.vertical, WaterUpTheme.Spacing.x2)
        .background(.regularMaterial, in: Capsule())
        .overlay {
            Capsule()
                .stroke(WaterUpTheme.Palette.divider.color, lineWidth: 1)
        }
        .shadow(color: WaterUpTheme.Palette.textPrimary.color.opacity(0.12), radius: 12, y: 4)
        .accessibilityElement(children: .combine)
    }
}

private enum TodayDateFormatter {
    static let header: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter
    }()

    static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

#Preview {
    TodayView(onShowAllRecords: {})
        .modelContainer(WaterUpPreviewData.makeModelContainer())
}

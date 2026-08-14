import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var displayedMonth = Date()
    @State private var selectedDate: Date? = .now
    @State private var selectedPeriod: HistoryPeriod = .calendar
    @State private var historyMonth: HistoryMonth?
    @State private var trendDashboard: TrendDashboard?
    @State private var selectedDayRecords = [HydrationRecord]()
    @State private var selectedDayTargetML: Int?
    @State private var isLoading = true
    @State private var isShowingReadError = false

    private let historyService = HistoryService()

    var body: some View {
        WaterUpPage(title: selectedPeriod.navigationTitle) {
            Text(selectedPeriod.subtitle)
                .font(WaterUpTheme.Typography.callout)
                .foregroundStyle(WaterUpTheme.Palette.textMuted.color)

            HistoryPeriodSegment(selectedPeriod: $selectedPeriod)

            if isLoading {
                WaterUpCard {
                    ProgressView("正在读取历史记录…")
                        .frame(maxWidth: .infinity, minHeight: 260)
                }
            } else if isShowingReadError {
                WaterUpCard {
                    VStack(spacing: WaterUpTheme.Spacing.x4) {
                        WaterUpEmptyState(
                            systemImage: "exclamationmark.triangle.fill",
                            title: "历史记录暂时无法读取",
                            message: "本地数据或历史目标暂时不可用，请稍后重试。"
                        )

                        WaterUpPrimaryButton(
                            title: "重新读取",
                            systemImage: "arrow.clockwise",
                            action: reload
                        )
                    }
                }
            } else if selectedPeriod == .calendar, let historyMonth {
                monthContent(historyMonth)
            } else if let trendDashboard {
                TrendView(dashboard: trendDashboard)
            }
        }
        .navigationBarTitleDisplayMode(.large)
        .task {
            reload()
        }
        .onChange(of: selectedPeriod) { _, _ in
            reload()
        }
    }

    @ViewBuilder
    private func monthContent(_ month: HistoryMonth) -> some View {
        monthPicker(for: month.monthStart)
        calendarGrid(month)
        historyLegend

        if let selectedDate {
            selectedDaySection(for: selectedDate)
        } else {
            WaterUpCard {
                WaterUpEmptyState(
                    systemImage: "calendar",
                    title: "请选择一个日期",
                    message: "未来日期不能查看或补记记录。"
                )
            }
        }
    }

    private func monthPicker(for monthStart: Date) -> some View {
        HStack {
            Text(HistoryDateFormatter.month.string(from: monthStart))
                .font(WaterUpTheme.Typography.title1)
                .foregroundStyle(WaterUpTheme.Palette.textPrimary.color)

            Spacer()

            Button {
                changeMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.bold))
                    .frame(width: WaterUpTheme.Layout.minimumTapTarget, height: WaterUpTheme.Layout.minimumTapTarget)
            }
            .buttonStyle(.plain)
            .foregroundStyle(WaterUpTheme.Palette.textSecondary.color)
            .accessibilityLabel("上一个月")
            .accessibilityIdentifier("waterup.history.previous-month")

            Button {
                changeMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3.weight(.bold))
                    .frame(width: WaterUpTheme.Layout.minimumTapTarget, height: WaterUpTheme.Layout.minimumTapTarget)
            }
            .buttonStyle(.plain)
            .foregroundStyle(WaterUpTheme.Palette.textSecondary.color)
            .accessibilityLabel("下一个月")
            .accessibilityIdentifier("waterup.history.next-month")
        }
    }

    private func calendarGrid(_ month: HistoryMonth) -> some View {
        VStack(spacing: WaterUpTheme.Spacing.x3) {
            HStack(spacing: 0) {
                ForEach(HistoryDateFormatter.weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(WaterUpTheme.Typography.callout)
                        .foregroundStyle(WaterUpTheme.Palette.textMuted.color)
                        .frame(maxWidth: .infinity)
                }
            }

            let rows = month.days.chunked(into: 7)
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 0) {
                    ForEach(row) { day in
                        HistoryCalendarDayButton(
                            day: day,
                            isSelected: isSelected(day.date)
                        ) {
                            select(day)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(.vertical, WaterUpTheme.Spacing.x4)
        .background(
            WaterUpTheme.Palette.surfacePrimary.color,
            in: RoundedRectangle(cornerRadius: WaterUpTheme.Radius.large, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: WaterUpTheme.Radius.large, style: .continuous)
                .stroke(WaterUpTheme.Palette.divider.color, lineWidth: 1)
        }
    }

    private var historyLegend: some View {
        HStack {
            Text("状态说明")
                .font(WaterUpTheme.Typography.callout)
                .foregroundStyle(WaterUpTheme.Palette.textMuted.color)

            Spacer(minLength: WaterUpTheme.Spacing.x2)

            HistoryLegendItem(title: "已达标", state: .reachedTarget)
            HistoryLegendItem(title: "未达标", state: .belowTarget)
            HistoryLegendItem(title: "无记录", state: .noData)
        }
        .padding(WaterUpTheme.Spacing.x4)
        .background(
            WaterUpTheme.Palette.surfacePrimary.color,
            in: RoundedRectangle(cornerRadius: WaterUpTheme.Radius.large, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: WaterUpTheme.Radius.large, style: .continuous)
                .stroke(WaterUpTheme.Palette.divider.color, lineWidth: 1)
        }
    }

    @ViewBuilder
    private func selectedDaySection(for date: Date) -> some View {
        WaterUpSectionTitle(HistoryDateFormatter.dayHeader.string(from: date))

        if selectedDayRecords.isEmpty {
            WaterUpCard {
                WaterUpEmptyState(
                    systemImage: "drop",
                    title: "当天没有记录",
                    message: "可以进入单日明细补记当天饮品。"
                )
            }
        } else {
            WaterUpCard {
                VStack(spacing: 0) {
                    ForEach(Array(selectedDayRecords.enumerated()), id: \.element.id) { index, record in
                        NavigationLink {
                            RecordDetailView(recordID: record.id, onChanged: reload)
                        } label: {
                            HistoryRecordRow(
                                record: record,
                                targetML: selectedDayTargetML
                            )
                        }
                        .buttonStyle(.plain)

                        if index < selectedDayRecords.count - 1 {
                            Divider()
                                .overlay(WaterUpTheme.Palette.divider.color)
                                .padding(.vertical, WaterUpTheme.Spacing.x3)
                        }
                    }
                }
            }
        }

        NavigationLink {
            HistoryDayDetailView(date: date, onChanged: reload)
        } label: {
            Label("查看单日明细", systemImage: "list.bullet")
                .font(WaterUpTheme.Typography.headline)
                .frame(maxWidth: .infinity)
                .frame(minHeight: WaterUpTheme.Layout.minimumTapTarget)
        }
        .buttonStyle(.bordered)
        .tint(WaterUpTheme.Palette.actionPrimary.color)
        .accessibilityIdentifier("waterup.history.day-detail")
    }

    private func reload() {
        isLoading = true
        isShowingReadError = false

        do {
            switch selectedPeriod {
            case .calendar:
                let month = try historyService.month(for: displayedMonth, in: modelContext)
                historyMonth = month
                selectedDayRecords = try selectedRecords()
                selectedDayTargetML = try selectedTargetML()
                trendDashboard = nil
            case .sevenDays, .thirtyDays:
                trendDashboard = try TrendService().dashboard(
                    for: selectedPeriod.trendRange,
                    in: modelContext
                )
                historyMonth = nil
                selectedDayRecords = []
                selectedDayTargetML = nil
            }
        } catch {
            historyMonth = nil
            trendDashboard = nil
            selectedDayRecords = []
            selectedDayTargetML = nil
            isShowingReadError = true
        }

        isLoading = false
    }

    private func selectedRecords() throws -> [HydrationRecord] {
        guard let selectedDate else {
            return []
        }

        return try HydrationRecordQueryService().records(on: selectedDate, in: modelContext)
    }

    private func selectedTargetML() throws -> Int? {
        guard let selectedDate else {
            return nil
        }

        return try GoalService().goal(for: selectedDate, in: modelContext).targetML
    }

    private func select(_ day: HistoryCalendarDay) {
        guard let date = day.date, !day.isFuture else {
            return
        }

        selectedDate = date
        reload()
    }

    private func changeMonth(by value: Int) {
        guard let nextMonth = Calendar.autoupdatingCurrent.date(byAdding: .month, value: value, to: displayedMonth) else {
            return
        }

        displayedMonth = nextMonth
        selectedDate = preferredSelection(for: nextMonth)
        reload()
    }

    private func preferredSelection(for month: Date) -> Date? {
        let calendar = Calendar.autoupdatingCurrent
        guard let monthRange = calendar.dateInterval(of: .month, for: month) else {
            return nil
        }

        let now = Date()
        if monthRange.contains(now) {
            return now
        }

        if monthRange.end <= now {
            return monthRange.start
        }

        return nil
    }

    private func isSelected(_ date: Date?) -> Bool {
        guard let date, let selectedDate else {
            return false
        }

        return Calendar.autoupdatingCurrent.isDate(date, inSameDayAs: selectedDate)
    }
}

private enum HistoryPeriod: Hashable {
    case calendar
    case sevenDays
    case thirtyDays

    var navigationTitle: String {
        switch self {
        case .calendar:
            return "历史"
        case .sevenDays, .thirtyDays:
            return "趋势"
        }
    }

    var subtitle: String {
        switch self {
        case .calendar:
            return "按日期查看有效补水"
        case .sevenDays:
            return TrendRange.sevenDays.subtitle
        case .thirtyDays:
            return TrendRange.thirtyDays.subtitle
        }
    }

    var trendRange: TrendRange {
        switch self {
        case .calendar:
            return .sevenDays
        case .sevenDays:
            return .sevenDays
        case .thirtyDays:
            return .thirtyDays
        }
    }
}

private struct HistoryPeriodSegment: View {
    @Binding var selectedPeriod: HistoryPeriod

    var body: some View {
        HStack(spacing: 0) {
            periodButton(title: "日历", period: .calendar)
            periodButton(title: "7 日", period: .sevenDays)
            periodButton(title: "30 日", period: .thirtyDays)
        }
        .padding(4)
        .background(WaterUpTheme.Palette.divider.color.opacity(0.8), in: Capsule())
    }

    private func periodButton(title: String, period: HistoryPeriod) -> some View {
        Button {
            selectedPeriod = period
        } label: {
            Text(title)
                .font(WaterUpTheme.Typography.headline)
                .foregroundStyle(
                    selectedPeriod == period
                        ? WaterUpTheme.Palette.textPrimary.color
                        : WaterUpTheme.Palette.textMuted.color
                )
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background {
                    if selectedPeriod == period {
                        Color.white.clipShape(Capsule())
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selectedPeriod == period ? .isSelected : [])
    }
}

private struct HistoryCalendarDayButton: View {
    let day: HistoryCalendarDay
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                if let dayNumber = day.dayNumber {
                    Text("\(dayNumber)")
                        .font(.system(size: 17, weight: .semibold).monospacedDigit())
                        .foregroundStyle(dayNumberColor)
                        .frame(width: 38, height: 38)
                        .background {
                            if isSelected {
                                Circle().fill(WaterUpTheme.Palette.actionPrimary.color)
                            }
                        }
                } else {
                    Color.clear.frame(width: 38, height: 38)
                }

                HistoryStateMarker(state: day.state, usesRelativeWidth: true)
                    .frame(height: 8)
            }
            .frame(minHeight: 58)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(day.date == nil || day.isFuture)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(day.isFuture ? "未来日期不能选择" : "查看当天记录")
    }

    private var dayNumberColor: Color {
        if isSelected {
            return .white
        }

        if day.isFuture {
            return WaterUpTheme.Palette.divider.color
        }

        return WaterUpTheme.Palette.textSecondary.color
    }

    private var accessibilityLabel: String {
        guard let date = day.date else {
            return "空白日期"
        }

        let dateTitle = HistoryDateFormatter.day.string(from: date)
        guard let state = day.state else {
            return "\(dateTitle)，未来日期"
        }

        return "\(dateTitle)，\(state.displayName)"
    }
}

private struct HistoryLegendItem: View {
    let title: String
    let state: HistoryDayState

    var body: some View {
        HStack(spacing: 6) {
            HistoryStateMarker(state: state)
                .frame(width: 18, height: 10)

            Text(title)
                .font(WaterUpTheme.Typography.caption)
                .foregroundStyle(WaterUpTheme.Palette.textSecondary.color)
        }
    }
}

struct HistoryStateMarker: View {
    let state: HistoryDayState?
    var usesRelativeWidth = false

    var body: some View {
        switch state {
        case .reachedTarget:
            Circle().fill(WaterUpTheme.Palette.statusSuccess.color)
        case .belowTarget:
            if usesRelativeWidth {
                GeometryReader { proxy in
                    Capsule()
                        .fill(Color(red: 251 / 255, green: 132 / 255, blue: 104 / 255))
                        .frame(width: proxy.size.width * 0.24, height: 4)
                        .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                }
            } else {
                Capsule().fill(Color(red: 251 / 255, green: 132 / 255, blue: 104 / 255))
            }
        case .noData:
            Circle().fill(WaterUpTheme.Palette.divider.color)
        case nil:
            Color.clear
        }
    }
}

struct HistoryRecordRow: View {
    let record: HydrationRecord
    let targetML: Int?

    var body: some View {
        HStack(spacing: WaterUpTheme.Spacing.x3) {
            Image(record.iconKeySnapshot)
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: WaterUpTheme.Spacing.x1) {
                Text(record.drinkNameSnapshot)
                    .font(WaterUpTheme.Typography.headline)
                    .foregroundStyle(WaterUpTheme.Palette.textPrimary.color)

                Text(HistoryDateFormatter.time.string(from: record.consumedAt))
                    .font(WaterUpTheme.Typography.callout)
                    .foregroundStyle(WaterUpTheme.Palette.textMuted.color)
            }

            Spacer(minLength: WaterUpTheme.Spacing.x2)

            VStack(alignment: .trailing, spacing: WaterUpTheme.Spacing.x1) {
                Text(primaryMetricTitle)
                    .font(WaterUpTheme.Typography.caption)
                    .foregroundStyle(WaterUpTheme.Palette.textMuted.color)

                Text(primaryMetricValue)
                    .font(WaterUpTheme.Typography.headline)
                    .foregroundStyle(WaterUpTheme.Palette.textPrimary.color)
                    .monospacedDigit()
            }

            Divider()
                .frame(height: 46)

            VStack(alignment: .trailing, spacing: WaterUpTheme.Spacing.x1) {
                Text("有效补水")
                    .font(WaterUpTheme.Typography.caption)
                    .foregroundStyle(WaterUpTheme.Palette.textMuted.color)

                Text("\(record.effectiveHydrationML) mL")
                    .font(WaterUpTheme.Typography.headline)
                    .foregroundStyle(WaterUpTheme.Palette.hydrationProgressStart.color)
                    .monospacedDigit()
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(WaterUpTheme.Palette.textMuted.color)
        }
        .accessibilityElement(children: .combine)
    }

    private var primaryMetricTitle: String {
        targetML == nil ? "饮品容量" : "目标饮水"
    }

    private var primaryMetricValue: String {
        if let targetML {
            return "\(targetML) mL"
        }

        return "\(record.volumeML) mL"
    }
}

private extension HistoryDayState {
    var displayName: String {
        switch self {
        case .noData:
            return "无记录"
        case .belowTarget:
            return "未达标"
        case .reachedTarget:
            return "已达标"
        }
    }
}

private enum HistoryDateFormatter {
    static let month: DateFormatter = formatter("yyyy年M月")
    static let day: DateFormatter = formatter("M月d日")
    static let dayHeader: DateFormatter = formatter("M月d日 EEEE")
    static let time: DateFormatter = formatter("HH:mm")
    static let weekdaySymbols = ["一", "二", "三", "四", "五", "六", "日"]

    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = format
        return formatter
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else {
            return []
        }

        var result = [[Element]]()
        var index = startIndex

        while index < endIndex {
            let end = self.index(index, offsetBy: size, limitedBy: endIndex) ?? endIndex
            result.append(Array(self[index..<end]))
            index = end
        }

        return result
    }
}

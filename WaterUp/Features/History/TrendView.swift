import Charts
import SwiftUI

struct TrendView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let dashboard: TrendDashboard

    private var period: TrendPeriod {
        dashboard.period
    }

    var body: some View {
        VStack(spacing: WaterUpTheme.Spacing.x5) {
            WaterUpCard {
                VStack(alignment: .leading, spacing: WaterUpTheme.Spacing.x3) {
                    Text("平均每天")
                        .font(WaterUpTheme.Typography.headline)
                        .foregroundStyle(WaterUpTheme.Palette.textMuted.color)

                    Text("\(period.summary.averageEffectiveHydrationML) mL")
                        .font(.system(size: 38, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(WaterUpTheme.Palette.textPrimary.color)
                        .minimumScaleFactor(0.7)

                    if period.range == .sevenDays {
                        sevenDayChart
                    } else {
                        thirtyDayChart
                    }
                }
            }

            summaryCards

            if period.range == .sevenDays {
                comparisonCard
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilitySummary)
    }

    private var sevenDayChart: some View {
        VStack(spacing: WaterUpTheme.Spacing.x2) {
            Chart(period.points) { point in
                BarMark(
                    x: .value("日期", point.date, unit: .day),
                    y: .value("有效补水", point.effectiveHydrationML)
                )
                .foregroundStyle(barColor(for: point))
                .clipShape(Capsule())
                .opacity(point.isStatisticalDay ? 1 : 0.18)

                if let targetML = point.targetML {
                    LineMark(
                        x: .value("日期", point.date, unit: .day),
                        y: .value("每日目标", targetML)
                    )
                    .foregroundStyle(WaterUpTheme.Palette.actionPrimary.color.opacity(0.52))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartPlotStyle { plotArea in
                plotArea
                    .accessibilityLabel("柱状图，显示每日有效补水量与对应目标")
            }
            .frame(height: 175)

            HStack(spacing: 0) {
                ForEach(period.points) { point in
                    Text(dayLabel(for: point.date))
                        .font(WaterUpTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(point.dayKey == todayDayKey ? WaterUpTheme.Palette.actionPrimary.color : WaterUpTheme.Palette.textMuted.color)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var thirtyDayChart: some View {
        VStack(alignment: .leading, spacing: WaterUpTheme.Spacing.x2) {
            Chart(period.points) { point in
                if point.isStatisticalDay {
                    AreaMark(
                        x: .value("日期", point.date, unit: .day),
                        y: .value("有效补水", point.effectiveHydrationML)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                WaterUpTheme.Palette.hydrationProgressStart.color.opacity(0.25),
                                WaterUpTheme.Palette.hydrationProgressEnd.color.opacity(0.03)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("日期", point.date, unit: .day),
                        y: .value("有效补水", point.effectiveHydrationML)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                WaterUpTheme.Palette.hydrationProgressStart.color,
                                WaterUpTheme.Palette.hydrationProgressEnd.color
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .lineStyle(StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                }

                if let targetML = point.targetML {
                    LineMark(
                        x: .value("日期", point.date, unit: .day),
                        y: .value("每日目标", targetML)
                    )
                    .foregroundStyle(WaterUpTheme.Palette.actionPrimary.color.opacity(0.52))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 190)

            HStack {
                Text(dateLabel(for: period.points.first?.date))
                Spacer()
                Text(dateLabel(for: period.points.last?.date))
            }
            .font(WaterUpTheme.Typography.callout)
            .foregroundStyle(WaterUpTheme.Palette.textMuted.color)
        }
    }

    @ViewBuilder
    private var summaryCards: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: WaterUpTheme.Spacing.x3) {
                metricCards
            }
        } else {
            HStack(spacing: WaterUpTheme.Spacing.x3) {
                metricCards
            }
        }
    }

    @ViewBuilder
    private var metricCards: some View {
        TrendMetricCard(
            title: period.range == .sevenDays ? "7 日总计" : "总有效补水",
            value: amountText(period.summary.totalEffectiveHydrationML),
            systemImage: "drop.fill",
            color: WaterUpTheme.Palette.actionPrimary.color
        )

        TrendMetricCard(
            title: "达到目标",
            value: "\(period.summary.reachedTargetDayCount) 天",
            systemImage: "checkmark",
            color: WaterUpTheme.Palette.statusSuccess.color
        )

        if period.range == .thirtyDays {
            TrendMetricCard(
                title: "记录覆盖",
                value: "\(period.summary.recordCoveragePercent)%",
                systemImage: "calendar.badge.checkmark",
                color: WaterUpTheme.Palette.statusOverGoal.color
            )
        }
    }

    @ViewBuilder
    private var comparisonCard: some View {
        WaterUpCard {
            VStack(alignment: .leading, spacing: WaterUpTheme.Spacing.x2) {
                Text("与前 7 日相比")
                    .font(WaterUpTheme.Typography.headline)
                    .foregroundStyle(WaterUpTheme.Palette.textMuted.color)

                if let comparison = dashboard.comparisonWithPreviousPeriod {
                    HStack(alignment: .firstTextBaseline, spacing: WaterUpTheme.Spacing.x3) {
                        Text(percentageText(comparison.percentageChange))
                            .font(.system(size: 30, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(comparisonColor(for: comparison))

                        Text("平均每天\(differenceText(comparison.averageDifferenceML))")
                            .font(WaterUpTheme.Typography.headline)
                            .foregroundStyle(WaterUpTheme.Palette.textSecondary.color)
                    }
                } else {
                    Text("暂无可比数据")
                        .font(WaterUpTheme.Typography.title2)
                        .foregroundStyle(WaterUpTheme.Palette.textSecondary.color)

                    Text("前 7 日没有可用于计算的日均值。")
                        .font(WaterUpTheme.Typography.callout)
                        .foregroundStyle(WaterUpTheme.Palette.textMuted.color)
                }
            }
        }
    }

    private var todayDayKey: String {
        DateBoundaryService().dayKey(for: .now)
    }

    private var accessibilitySummary: String {
        let summary = period.summary
        return "\(period.range.title)趋势，平均每天\(summary.averageEffectiveHydrationML)毫升，总有效补水\(summary.totalEffectiveHydrationML)毫升，达到目标\(summary.reachedTargetDayCount)天，统计\(summary.statisticalDayCount)天。"
    }

    private func barColor(for point: TrendPoint) -> Color {
        if point.hasReachedTarget {
            return WaterUpTheme.Palette.hydrationProgressEnd.color
        }

        return WaterUpTheme.Palette.actionPrimary.color.opacity(0.46)
    }

    private func comparisonColor(for comparison: TrendComparison) -> Color {
        if comparison.percentageChange > 0 {
            return WaterUpTheme.Palette.statusSuccess.color
        }

        if comparison.percentageChange < 0 {
            return WaterUpTheme.Palette.statusError.color
        }

        return WaterUpTheme.Palette.textSecondary.color
    }

    private func amountText(_ amountML: Int) -> String {
        if amountML >= 10_000 {
            return String(format: "%.1f L", Double(amountML) / 1_000)
        }

        return "\(amountML) mL"
    }

    private func percentageText(_ percentage: Int) -> String {
        if percentage > 0 {
            return "+\(percentage)%"
        }

        return "\(percentage)%"
    }

    private func differenceText(_ amountML: Int) -> String {
        if amountML > 0 {
            return "多补水 \(amountML) mL"
        }

        if amountML < 0 {
            return "少补水 \(abs(amountML)) mL"
        }

        return "持平"
    }

    private func dayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }

    private func dateLabel(for date: Date?) -> String {
        guard let date else {
            return ""
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }
}

private struct TrendMetricCard: View {
    let title: String
    let value: String
    let systemImage: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: WaterUpTheme.Spacing.x3) {
            Label(title, systemImage: systemImage)
                .font(WaterUpTheme.Typography.caption)
                .foregroundStyle(WaterUpTheme.Palette.textMuted.color)
                .labelStyle(.iconOnly)
                .accessibilityHidden(true)

            Text(value)
                .font(WaterUpTheme.Typography.title2)
                .foregroundStyle(WaterUpTheme.Palette.textPrimary.color)
                .monospacedDigit()
                .minimumScaleFactor(0.65)

            Text(title)
                .font(WaterUpTheme.Typography.callout)
                .foregroundStyle(WaterUpTheme.Palette.textMuted.color)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
        .padding(WaterUpTheme.Spacing.x4)
        .background(
            WaterUpTheme.Palette.surfacePrimary.color,
            in: RoundedRectangle(cornerRadius: WaterUpTheme.Radius.large, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: WaterUpTheme.Radius.large, style: .continuous)
                .stroke(WaterUpTheme.Palette.divider.color, lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title)，\(value)")
    }
}

import SwiftData
import SwiftUI

struct HistoryDayDetailView: View {
    @Environment(\.modelContext) private var modelContext

    let date: Date
    let onChanged: () -> Void

    @State private var detail: HistoryDayDetail?
    @State private var isLoading = true
    @State private var isShowingReadError = false
    @State private var recordFormRoute: RecordFormRoute?
    @State private var actionErrorMessage: String?

    private let historyService = HistoryService()
    private let catalogService = DrinkCatalogService()

    var body: some View {
        WaterUpPage(title: HistoryDateFormatter.detailTitle.string(from: date)) {
            Text("单日明细")
                .font(WaterUpTheme.Typography.callout)
                .foregroundStyle(WaterUpTheme.Palette.textMuted.color)

            if isLoading {
                WaterUpCard {
                    ProgressView("正在读取当天记录…")
                        .frame(maxWidth: .infinity, minHeight: 220)
                }
            } else if isShowingReadError {
                WaterUpCard {
                    VStack(spacing: WaterUpTheme.Spacing.x4) {
                        WaterUpEmptyState(
                            systemImage: "exclamationmark.triangle.fill",
                            title: "当天明细暂时无法读取",
                            message: "当天目标或本地记录暂时不可用，请稍后重试。"
                        )

                        WaterUpPrimaryButton(
                            title: "重新读取",
                            systemImage: "arrow.clockwise",
                            action: reload
                        )
                    }
                }
            } else if let detail {
                detailContent(detail)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $recordFormRoute) { route in
            NavigationStack {
                RecordFormView(route: route, onSaved: recordDidChange)
            }
        }
        .task {
            reload()
        }
    }

    @ViewBuilder
    private func detailContent(_ detail: HistoryDayDetail) -> some View {
        HistorySummaryCard(summary: detail.summary)

        WaterUpSectionTitle("饮水记录", detail: "\(detail.records.count) 条")

        if detail.records.isEmpty {
            WaterUpCard {
                WaterUpEmptyState(
                    systemImage: "drop",
                    title: "当天没有记录",
                    message: "补记一条饮品后，会按当天目标计算达标状态。"
                )
            }
        } else {
            WaterUpCard {
                VStack(spacing: 0) {
                    ForEach(Array(detail.records.enumerated()), id: \.element.id) { index, record in
                        NavigationLink {
                            RecordDetailView(recordID: record.id, onChanged: recordDidChange)
                        } label: {
                            HistoryRecordRow(record: record, targetML: nil)
                        }
                        .buttonStyle(.plain)

                        if index < detail.records.count - 1 {
                            Divider()
                                .overlay(WaterUpTheme.Palette.divider.color)
                                .padding(.vertical, WaterUpTheme.Spacing.x3)
                        }
                    }
                }
            }
        }

        calculationExplanation(for: detail.records)

        if let actionErrorMessage {
            WaterUpStatusMessage(
                kind: .error,
                title: "无法补记",
                message: actionErrorMessage
            )
        }

        WaterUpSecondaryButton(
            title: "补记当天记录",
            systemImage: "plus"
        ) {
            openRecordForm()
        }
        .accessibilityIdentifier("waterup.history.add-record")
    }

    private func calculationExplanation(for records: [HydrationRecord]) -> some View {
        WaterUpCard {
            VStack(alignment: .leading, spacing: WaterUpTheme.Spacing.x2) {
                Text("计算说明")
                    .font(WaterUpTheme.Typography.headline)
                    .foregroundStyle(WaterUpTheme.Palette.textPrimary.color)

                if records.isEmpty {
                    Text("当天暂无记录，补记后会按饮品快照比例计算有效补水。")
                        .font(WaterUpTheme.Typography.body)
                        .foregroundStyle(WaterUpTheme.Palette.textMuted.color)
                } else {
                    ForEach(records, id: \.id) { record in
                        Text("\(record.drinkNameSnapshot) \(record.volumeML) × \(record.waterRatioPercentSnapshot)% = \(record.effectiveHydrationML) mL")
                            .font(WaterUpTheme.Typography.callout)
                            .foregroundStyle(WaterUpTheme.Palette.textMuted.color)
                            .monospacedDigit()
                    }

                    Text("记录按饮品快照比例计算")
                        .font(WaterUpTheme.Typography.caption)
                        .foregroundStyle(WaterUpTheme.Palette.textMuted.color)
                }
            }
        }
    }

    private func reload() {
        isLoading = true
        isShowingReadError = false
        actionErrorMessage = nil

        do {
            detail = try historyService.detail(for: date, in: modelContext)
        } catch {
            detail = nil
            isShowingReadError = true
        }

        isLoading = false
    }

    private func openRecordForm() {
        actionErrorMessage = nil

        do {
            let water = try catalogService.defaultWater(in: modelContext)
            recordFormRoute = .create(drinkID: water.id, consumedAt: defaultRecordTime())
        } catch {
            actionErrorMessage = "默认饮用水暂时不可用，请稍后重试。"
        }
    }

    private func defaultRecordTime() -> Date {
        let calendar = Calendar.autoupdatingCurrent
        let now = Date()

        if calendar.isDate(date, inSameDayAs: now) {
            return now
        }

        return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date
    }

    private func recordDidChange() {
        reload()
        onChanged()
    }
}

private struct HistorySummaryCard: View {
    let summary: DailyHydrationSummary

    var body: some View {
        WaterUpCard {
            VStack(alignment: .leading, spacing: WaterUpTheme.Spacing.x4) {
                HStack(alignment: .top) {
                    Text("有效补水")
                        .font(WaterUpTheme.Typography.callout)
                        .foregroundStyle(WaterUpTheme.Palette.textMuted.color)

                    Spacer()

                    HistoryProgressBadge(summary: summary)
                }

                HStack(alignment: .lastTextBaseline, spacing: WaterUpTheme.Spacing.x2) {
                    WaterUpDisplayText(value: "\(summary.totalEffectiveHydrationML)")
                    Text("mL")
                        .font(WaterUpTheme.Typography.title2)
                        .foregroundStyle(WaterUpTheme.Palette.textSecondary.color)
                }

                Divider()
                    .overlay(WaterUpTheme.Palette.divider.color)

                HStack {
                    Text("饮品总容量 \(summary.totalVolumeML) mL")
                    Spacer()
                    Text("目标 \(summary.targetML) mL")
                }
                .font(WaterUpTheme.Typography.callout)
                .foregroundStyle(WaterUpTheme.Palette.textSecondary.color)
                .monospacedDigit()
            }
        }
    }
}

private struct HistoryProgressBadge: View {
    let summary: DailyHydrationSummary

    private var hasReachedTarget: Bool {
        summary.totalEffectiveHydrationML >= summary.targetML
    }

    private var percentage: Int {
        Int((summary.progress * 100).rounded())
    }

    var body: some View {
        Label(
            "\(percentage)% \(hasReachedTarget ? "已达标" : "未达标")",
            systemImage: hasReachedTarget ? "checkmark.circle.fill" : "drop.fill"
        )
        .font(WaterUpTheme.Typography.callout)
        .foregroundStyle(hasReachedTarget ? WaterUpTheme.Palette.statusSuccess.color : Color(red: 251 / 255, green: 132 / 255, blue: 104 / 255))
        .padding(.horizontal, WaterUpTheme.Spacing.x3)
        .padding(.vertical, WaterUpTheme.Spacing.x2)
        .background(
            (hasReachedTarget ? WaterUpTheme.Palette.statusSuccess.color : Color(red: 251 / 255, green: 132 / 255, blue: 104 / 255)).opacity(0.12),
            in: Capsule()
        )
    }
}

private enum HistoryDateFormatter {
    static let detailTitle: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter
    }()
}

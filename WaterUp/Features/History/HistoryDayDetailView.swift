import SwiftData
import SwiftUI

struct HistoryDayDetailView: View {
    @Environment(\.dismiss) private var dismiss
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
        ScrollView {
            VStack(alignment: .leading, spacing: WaterUpTheme.Spacing.x5) {
                HistoryDayDetailHeader(
                    title: HistoryDateFormatter.detailTitle.string(from: date),
                    onBack: { dismiss() }
                )
                .padding(.horizontal, WaterUpTheme.Spacing.x4)

                VStack(alignment: .leading, spacing: WaterUpTheme.Spacing.x5) {
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, WaterUpTheme.Spacing.pageHorizontal)
            }
        }
        .scrollIndicators(.hidden)
        .background {
            Image(WaterUpAsset.Background.light)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden()
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
                                .toolbar(.visible, for: .navigationBar)
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

        Button("补记当天记录") {
            openRecordForm()
        }
        .font(WaterUpTheme.Typography.headline)
        .foregroundStyle(WaterUpTheme.Palette.actionPrimary.color)
        .frame(minWidth: 166, minHeight: WaterUpTheme.Layout.minimumTapTarget)
        .background(WaterUpTheme.Palette.surfacePrimary.color, in: Capsule())
        .overlay {
            Capsule()
                .stroke(WaterUpTheme.Palette.actionPrimary.color, lineWidth: 1.5)
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(.plain)
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
                        Text(verbatim: calculationText(for: record))
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

    private func calculationText(for record: HydrationRecord) -> String {
        "\(record.drinkNameSnapshot) \(record.volumeML) × \(record.waterRatioPercentSnapshot)% = \(record.effectiveHydrationML) mL"
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
                    WaterUpDisplayText(value: String(summary.totalEffectiveHydrationML))
                    Text("mL")
                        .font(WaterUpTheme.Typography.title2)
                        .foregroundStyle(WaterUpTheme.Palette.textSecondary.color)
                }

                Divider()
                    .overlay(WaterUpTheme.Palette.divider.color)

                HStack {
                    Text(verbatim: "饮品总容量 \(summary.totalVolumeML) mL")
                    Spacer()
                    Text(verbatim: "目标 \(summary.targetML) mL")
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
        summary.roundedProgressPercentage
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
        formatter.dateFormat = "M月d日 EEE"
        return formatter
    }()
}

private struct HistoryDayDetailHeader: View {
    let title: String
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: WaterUpTheme.Spacing.x2) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(WaterUpTheme.Palette.textSecondary.color)
                    .frame(
                        width: WaterUpTheme.Layout.minimumTapTarget,
                        height: WaterUpTheme.Layout.minimumTapTarget
                    )
                    .background(WaterUpTheme.Palette.surfacePrimary.color, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("返回")

            VStack(alignment: .leading, spacing: WaterUpTheme.Spacing.x1) {
                Text(title)
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .foregroundStyle(WaterUpTheme.Palette.textPrimary.color)
                    .lineLimit(1)

                Text("单日明细")
                    .font(WaterUpTheme.Typography.callout)
                    .foregroundStyle(WaterUpTheme.Palette.textMuted.color)
            }

            Spacer(minLength: WaterUpTheme.Spacing.x2)
        }
        .padding(.top, WaterUpTheme.Spacing.x2 + WaterUpTheme.Spacing.x1)
    }
}

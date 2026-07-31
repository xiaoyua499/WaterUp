import SwiftData
import SwiftUI

struct RecordDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let recordID: UUID
    let onChanged: () -> Void

    @State private var detail: RecordDetailData?
    @State private var isLoading = true
    @State private var isShowingReadError = false
    @State private var isShowingEditForm = false
    @State private var isShowingDeleteConfirmation = false
    @State private var deleteErrorMessage: String?

    private let recordService = RecordService()

    var body: some View {
        WaterUpPage(title: "记录详情") {
            if isLoading {
                WaterUpCard {
                    ProgressView("正在读取记录…")
                        .frame(maxWidth: .infinity, minHeight: 160)
                }
            } else if isShowingReadError {
                RecordDetailReadErrorView(onRetry: loadDetail)
            } else if let detail {
                detailContent(detail)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if detail != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingEditForm = true
                    } label: {
                        Label("编辑", systemImage: "pencil")
                    }
                    .accessibilityIdentifier("waterup.record.detail-edit")
                }
            }
        }
        .sheet(isPresented: $isShowingEditForm) {
            NavigationStack {
                RecordFormView(route: .edit(recordID: recordID)) {
                    loadDetail()
                    onChanged()
                }
            }
        }
        .alert(deleteTitle, isPresented: $isShowingDeleteConfirmation) {
            Button("取消", role: .cancel) {}
            Button("确认删除", role: .destructive) {
                deleteRecord()
            }
        } message: {
            Text("删除后相关日期的补水进度会同步回退，此操作无法撤销。")
        }
        .task {
            loadDetail()
        }
    }

    @ViewBuilder
    private func detailContent(_ detail: RecordDetailData) -> some View {
        Text(RecordDetailDateFormatter.header.string(from: detail.consumedAt))
            .font(WaterUpTheme.Typography.callout)
            .foregroundStyle(WaterUpTheme.Palette.textMuted.color)

        WaterUpCard {
            HStack(spacing: WaterUpTheme.Spacing.x5) {
                Image(detail.iconKey)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: WaterUpTheme.Spacing.x2) {
                    Text(detail.drinkName)
                        .font(WaterUpTheme.Typography.title1)
                        .foregroundStyle(WaterUpTheme.Palette.textPrimary.color)

                    Text("饮品容量 \(detail.volumeML) mL")
                        .font(WaterUpTheme.Typography.body)
                        .foregroundStyle(WaterUpTheme.Palette.textSecondary.color)
                        .monospacedDigit()

                    Text("有效补水 \(detail.effectiveHydrationML) mL")
                        .font(WaterUpTheme.Typography.headline)
                        .foregroundStyle(WaterUpTheme.Palette.hydrationProgressStart.color)
                        .monospacedDigit()
                }
            }
            .accessibilityElement(children: .combine)
        }

        WaterUpSectionTitle("记录信息")

        WaterUpCard {
            VStack(spacing: WaterUpTheme.Spacing.x4) {
                RecordDetailInfoRow(
                    title: "记录时间",
                    value: RecordDetailDateFormatter.full.string(from: detail.consumedAt),
                    systemImage: "calendar"
                )

                Divider()
                    .overlay(WaterUpTheme.Palette.divider.color)

                RecordDetailInfoRow(
                    title: "备注",
                    value: detail.note,
                    systemImage: "note.text"
                )
            }
        }

        if let deleteErrorMessage {
            WaterUpStatusMessage(
                kind: .error,
                title: "删除未完成",
                message: deleteErrorMessage
            )
        }

        WaterUpDestructiveButton(
            title: "删除这条记录",
            systemImage: "trash"
        ) {
            isShowingDeleteConfirmation = true
        }
        .accessibilityIdentifier("waterup.record.detail-delete")
    }

    private var deleteTitle: String {
        guard let detail else {
            return "删除这条记录？"
        }

        return "删除“\(detail.drinkName) \(detail.volumeML) mL”？"
    }

    private func loadDetail() {
        isLoading = true
        isShowingReadError = false
        deleteErrorMessage = nil

        do {
            let record = try recordService.record(id: recordID, in: modelContext)
            detail = RecordDetailData(record: record)
        } catch {
            detail = nil
            isShowingReadError = true
        }

        isLoading = false
    }

    private func deleteRecord() {
        deleteErrorMessage = nil

        do {
            try recordService.deleteRecord(id: recordID, in: modelContext)
            onChanged()
            dismiss()
        } catch {
            deleteErrorMessage = "本地删除失败，原记录仍已保留，请重试。"
        }
    }
}

private struct RecordDetailData {
    let drinkName: String
    let iconKey: String
    let volumeML: Int
    let effectiveHydrationML: Int
    let consumedAt: Date
    let note: String

    init(record: HydrationRecord) {
        drinkName = record.drinkNameSnapshot
        iconKey = record.iconKeySnapshot
        volumeML = record.volumeML
        effectiveHydrationML = record.effectiveHydrationML
        consumedAt = record.consumedAt

        if let recordNote = record.note, !recordNote.isEmpty {
            note = recordNote
        } else {
            note = "未填写"
        }
    }
}

private struct RecordDetailInfoRow: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: WaterUpTheme.Spacing.x3) {
            Image(systemName: systemImage)
                .foregroundStyle(WaterUpTheme.Palette.actionPrimary.color)
                .frame(width: WaterUpTheme.Layout.minimumTapTarget)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: WaterUpTheme.Spacing.x1) {
                Text(title)
                    .font(WaterUpTheme.Typography.caption)
                    .foregroundStyle(WaterUpTheme.Palette.textMuted.color)

                Text(value)
                    .font(WaterUpTheme.Typography.body)
                    .foregroundStyle(WaterUpTheme.Palette.textPrimary.color)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct RecordDetailReadErrorView: View {
    let onRetry: () -> Void

    var body: some View {
        WaterUpCard {
            VStack(spacing: WaterUpTheme.Spacing.x4) {
                WaterUpEmptyState(
                    systemImage: "exclamationmark.triangle.fill",
                    title: "记录暂时无法读取",
                    message: "这条记录可能已被删除，或本地数据暂时不可用。"
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

private enum RecordDetailDateFormatter {
    static let header: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 · HH:mm"
        return formatter
    }()

    static let full: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日 HH:mm"
        return formatter
    }()
}

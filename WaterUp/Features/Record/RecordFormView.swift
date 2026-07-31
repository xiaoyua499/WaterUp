import SwiftData
import SwiftUI

enum RecordFormRoute: Identifiable, Equatable {
    case create(drinkID: UUID, consumedAt: Date)
    case edit(recordID: UUID)

    var id: String {
        switch self {
        case let .create(drinkID, consumedAt):
            return "create-\(drinkID.uuidString)-\(consumedAt.timeIntervalSinceReferenceDate)"
        case let .edit(recordID):
            return "edit-\(recordID.uuidString)"
        }
    }

    var title: String {
        switch self {
        case .create:
            return "记录饮品"
        case .edit:
            return "编辑记录"
        }
    }
}

struct RecordFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let route: RecordFormRoute
    let onSaved: () -> Void

    @State private var draft: RecordDraft?
    @State private var isLoading = true
    @State private var isShowingReadError = false
    @State private var isShowingDrinkPicker = false
    @State private var saveErrorMessage: String?
    @FocusState private var focusedField: Field?

    private let catalogService = DrinkCatalogService()
    private let recordService = RecordService()

    var body: some View {
        WaterUpPage(title: route.title) {
            if isLoading {
                RecordFormLoadingView()
            } else if isShowingReadError {
                RecordFormReadErrorView(onRetry: loadDraft)
            } else if let loadedDraft = draft {
                formContent(binding(for: loadedDraft))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("取消") {
                    dismiss()
                }
            }

            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") {
                    focusedField = nil
                }
            }
        }
        .sheet(isPresented: $isShowingDrinkPicker) {
            if let draft {
                DrinkPickerView(selectedDrinkID: draft.drinkID) { drink in
                    select(drink)
                }
            }
        }
        .task {
            loadDraft()
        }
    }

    @ViewBuilder
    private func formContent(_ draft: Binding<RecordDraft>) -> some View {
        let validationErrors = draft.wrappedValue.validationErrors(at: .now)

        VStack(alignment: .leading, spacing: WaterUpTheme.Spacing.x3) {
            Text("容量会按含水比例折算")
                .font(WaterUpTheme.Typography.callout)
                .foregroundStyle(WaterUpTheme.Palette.textMuted.color)

            selectedDrinkCard(draft.wrappedValue)
        }

        WaterUpSectionTitle("饮品容量")
        volumeEditor(draft, validationErrors: validationErrors)
        effectiveHydrationPreview(draft.wrappedValue)
        recordTimeEditor(draft, validationErrors: validationErrors)
        noteEditor(draft, validationErrors: validationErrors)

        if let saveErrorMessage {
            WaterUpStatusMessage(
                kind: .error,
                title: "记录未保存",
                message: saveErrorMessage
            )
        }

        WaterUpPrimaryButton(
            title: "保存记录",
            systemImage: "checkmark"
        ) {
            saveDraft()
        }
        .disabled(!validationErrors.isEmpty)
        .opacity(validationErrors.isEmpty ? 1 : 0.55)
        .accessibilityIdentifier("waterup.record.save")
    }

    private func selectedDrinkCard(_ draft: RecordDraft) -> some View {
        Button {
            isShowingDrinkPicker = true
        } label: {
            HStack(spacing: WaterUpTheme.Spacing.x4) {
                Image(draft.iconKey)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: WaterUpTheme.Spacing.x1) {
                    Text(draft.drinkName)
                        .font(WaterUpTheme.Typography.title2)
                        .foregroundStyle(WaterUpTheme.Palette.textPrimary.color)

                    Text("估算含水比例 \(draft.waterRatioPercent)%")
                        .font(WaterUpTheme.Typography.callout)
                        .foregroundStyle(WaterUpTheme.Palette.textMuted.color)
                }

                Spacer(minLength: WaterUpTheme.Spacing.x2)

                Text("更换")
                    .font(WaterUpTheme.Typography.headline)
                    .foregroundStyle(WaterUpTheme.Palette.actionPrimary.color)
            }
            .padding(WaterUpTheme.Spacing.x4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                WaterUpTheme.Palette.surfacePrimary.color,
                in: RoundedRectangle(cornerRadius: WaterUpTheme.Radius.large, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: WaterUpTheme.Radius.large, style: .continuous)
                    .stroke(WaterUpTheme.Palette.divider.color, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "当前饮品 \(draft.drinkName)，估算含水比例 \(draft.waterRatioPercent)%，更换饮品"
        )
        .accessibilityIdentifier("waterup.record.change-drink")
    }

    private func volumeEditor(
        _ draft: Binding<RecordDraft>,
        validationErrors: Set<RecordDraftValidationError>
    ) -> some View {
        VStack(alignment: .leading, spacing: WaterUpTheme.Spacing.x2) {
            HStack(spacing: WaterUpTheme.Spacing.x4) {
                Button {
                    adjustVolume(by: -50)
                } label: {
                    Image(systemName: "minus")
                        .font(.title2.weight(.semibold))
                        .frame(
                            width: WaterUpTheme.Layout.minimumTapTarget,
                            height: WaterUpTheme.Layout.minimumTapTarget
                        )
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .accessibilityLabel("减少 50 mL")

                VStack(spacing: WaterUpTheme.Spacing.x1) {
                    TextField("容量", text: draft.volumeText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 46, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(
                            validationErrors.contains(.invalidVolume)
                                ? WaterUpTheme.Palette.statusError.color
                                : WaterUpTheme.Palette.textPrimary.color
                        )
                        .focused($focusedField, equals: .volume)
                        .accessibilityIdentifier("waterup.record.volume")

                    Text("mL")
                        .font(WaterUpTheme.Typography.callout)
                        .foregroundStyle(WaterUpTheme.Palette.textMuted.color)
                }
                .frame(maxWidth: .infinity)

                Button {
                    adjustVolume(by: 50)
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                        .frame(
                            width: WaterUpTheme.Layout.minimumTapTarget,
                            height: WaterUpTheme.Layout.minimumTapTarget
                        )
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .accessibilityLabel("增加 50 mL")
                .accessibilityIdentifier("waterup.record.volume-increase")
            }
            .padding(WaterUpTheme.Spacing.x5)
            .background(
                WaterUpTheme.Palette.surfacePrimary.color,
                in: RoundedRectangle(cornerRadius: WaterUpTheme.Radius.large, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: WaterUpTheme.Radius.large, style: .continuous)
                    .stroke(
                        validationErrors.contains(.invalidVolume)
                            ? WaterUpTheme.Palette.statusError.color
                            : WaterUpTheme.Palette.divider.color,
                        lineWidth: validationErrors.contains(.invalidVolume) ? 2 : 1
                    )
            }

            if validationErrors.contains(.invalidVolume) {
                Text(RecordDraftValidationError.invalidVolume.message)
                    .font(WaterUpTheme.Typography.caption)
                    .foregroundStyle(WaterUpTheme.Palette.statusError.color)
            }
        }
    }

    private func effectiveHydrationPreview(_ draft: RecordDraft) -> some View {
        HStack(spacing: WaterUpTheme.Spacing.x3) {
            Image(systemName: "drop.fill")
                .foregroundStyle(WaterUpTheme.Palette.hydrationProgressStart.color)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: WaterUpTheme.Spacing.x1) {
                Text("有效补水")
                    .font(WaterUpTheme.Typography.caption)
                    .foregroundStyle(WaterUpTheme.Palette.textMuted.color)

                if let preview = draft.effectiveHydrationPreviewML {
                    Text("\(preview) mL")
                        .font(WaterUpTheme.Typography.title2)
                        .foregroundStyle(WaterUpTheme.Palette.hydrationProgressStart.color)
                        .monospacedDigit()
                } else {
                    Text("— mL")
                        .font(WaterUpTheme.Typography.title2)
                        .foregroundStyle(WaterUpTheme.Palette.textMuted.color)
                }
            }

            Spacer(minLength: WaterUpTheme.Spacing.x3)

            if let volumeML = draft.volumeML {
                Text("\(volumeML) × \(draft.waterRatioPercent)%")
                    .font(WaterUpTheme.Typography.caption)
                    .foregroundStyle(WaterUpTheme.Palette.textMuted.color)
                    .monospacedDigit()
            }
        }
        .padding(WaterUpTheme.Spacing.x4)
        .background(
            WaterUpTheme.Palette.hydrationProgressStart.color.opacity(0.1),
            in: RoundedRectangle(cornerRadius: WaterUpTheme.Radius.medium, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }

    private func recordTimeEditor(
        _ draft: Binding<RecordDraft>,
        validationErrors: Set<RecordDraftValidationError>
    ) -> some View {
        VStack(alignment: .leading, spacing: WaterUpTheme.Spacing.x2) {
            DatePicker(
                "记录时间",
                selection: draft.consumedAt,
                in: ...Date(),
                displayedComponents: [.date, .hourAndMinute]
            )
            .font(WaterUpTheme.Typography.body)
            .padding(WaterUpTheme.Spacing.x4)
            .background(
                WaterUpTheme.Palette.surfacePrimary.color,
                in: RoundedRectangle(cornerRadius: WaterUpTheme.Radius.medium, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: WaterUpTheme.Radius.medium, style: .continuous)
                    .stroke(WaterUpTheme.Palette.divider.color, lineWidth: 1)
            }
            .accessibilityIdentifier("waterup.record.time")

            if validationErrors.contains(.futureConsumedAt) {
                Text(RecordDraftValidationError.futureConsumedAt.message)
                    .font(WaterUpTheme.Typography.caption)
                    .foregroundStyle(WaterUpTheme.Palette.statusError.color)
            }
        }
    }

    private func noteEditor(
        _ draft: Binding<RecordDraft>,
        validationErrors: Set<RecordDraftValidationError>
    ) -> some View {
        VStack(alignment: .leading, spacing: WaterUpTheme.Spacing.x2) {
            HStack {
                Text("备注（可选）")
                    .font(WaterUpTheme.Typography.callout)
                    .foregroundStyle(WaterUpTheme.Palette.textSecondary.color)

                Spacer()

                Text("\(draft.wrappedValue.note.count)/100")
                    .font(WaterUpTheme.Typography.caption)
                    .foregroundStyle(
                        validationErrors.contains(.noteTooLong)
                            ? WaterUpTheme.Palette.statusError.color
                            : WaterUpTheme.Palette.textMuted.color
                    )
            }

            TextEditor(text: draft.note)
                .frame(minHeight: 88)
                .padding(WaterUpTheme.Spacing.x3)
                .scrollContentBackground(.hidden)
                .background(
                    WaterUpTheme.Palette.surfacePrimary.color,
                    in: RoundedRectangle(cornerRadius: WaterUpTheme.Radius.medium, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: WaterUpTheme.Radius.medium, style: .continuous)
                        .stroke(
                            validationErrors.contains(.noteTooLong)
                                ? WaterUpTheme.Palette.statusError.color
                                : WaterUpTheme.Palette.divider.color,
                            lineWidth: validationErrors.contains(.noteTooLong) ? 2 : 1
                        )
                }
                .focused($focusedField, equals: .note)
                .accessibilityIdentifier("waterup.record.note")

            if validationErrors.contains(.noteTooLong) {
                Text(RecordDraftValidationError.noteTooLong.message)
                    .font(WaterUpTheme.Typography.caption)
                    .foregroundStyle(WaterUpTheme.Palette.statusError.color)
            }
        }
    }

    private func binding(for loadedDraft: RecordDraft) -> Binding<RecordDraft> {
        Binding {
            guard let draft else {
                return loadedDraft
            }

            return draft
        } set: { newValue in
            draft = newValue
            saveErrorMessage = nil
        }
    }

    private func select(_ drink: DrinkDefinition) {
        guard var draft else {
            return
        }

        draft.select(drink)
        self.draft = draft
        saveErrorMessage = nil
    }

    private func adjustVolume(by delta: Int) {
        guard var draft, let currentVolume = draft.volumeML else {
            return
        }

        let adjustedVolume = min(max(currentVolume + delta, 1), 5_000)
        draft.volumeText = String(adjustedVolume)
        self.draft = draft
        saveErrorMessage = nil
    }

    private func loadDraft() {
        isLoading = true
        isShowingReadError = false

        do {
            switch route {
            case let .create(drinkID, consumedAt):
                let drink = try catalogService.activeDrink(id: drinkID, in: modelContext)
                draft = RecordDraft.newRecord(from: drink, consumedAt: consumedAt)
            case let .edit(recordID):
                let record = try recordService.record(id: recordID, in: modelContext)
                draft = RecordDraft.editing(record)
            }
        } catch {
            draft = nil
            isShowingReadError = true
        }

        isLoading = false
    }

    private func saveDraft() {
        guard let draft else {
            return
        }

        focusedField = nil
        saveErrorMessage = nil

        do {
            _ = try recordService.save(draft: draft, in: modelContext)
            onSaved()
            dismiss()
        } catch let RecordServiceError.invalidDraft(error) {
            saveErrorMessage = error.message
        } catch RecordServiceError.drinkIsNotAvailable {
            saveErrorMessage = "所选饮品已不可用，请重新选择。"
        } catch {
            saveErrorMessage = "本地保存失败，输入内容已保留，请重试。"
        }
    }
}

private extension RecordFormView {
    enum Field {
        case volume
        case note
    }
}

private struct RecordFormLoadingView: View {
    var body: some View {
        WaterUpCard {
            ProgressView("正在准备记录…")
                .frame(maxWidth: .infinity, minHeight: 160)
        }
    }
}

private struct RecordFormReadErrorView: View {
    let onRetry: () -> Void

    var body: some View {
        WaterUpCard {
            VStack(spacing: WaterUpTheme.Spacing.x4) {
                WaterUpEmptyState(
                    systemImage: "exclamationmark.triangle.fill",
                    title: "记录暂时无法读取",
                    message: "请重新读取后再继续编辑。"
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

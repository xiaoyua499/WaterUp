import SwiftData
import SwiftUI

struct DrinkEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var draft = DrinkDraft.newDrink()
    @State private var editingSource: DrinkSource?
    @State private var isShowingAppearancePicker = false
    @State private var saveErrorMessage: String?
    @State private var isSaving = false
    @FocusState private var focusedField: Field?

    let drinkID: UUID?
    let onSaved: () -> Void

    private let drinkService = DrinkService()

    init(drinkID: UUID? = nil, onSaved: @escaping () -> Void) {
        self.drinkID = drinkID
        self.onSaved = onSaved
    }

    private var isEditingBuiltIn: Bool {
        drinkID != nil && editingSource == .builtIn
    }

    private var pageTitle: String {
        if isEditingBuiltIn {
            return "编辑饮品"
        }

        return "自定义饮品"
    }

    var body: some View {
        let validationErrors = draft.validationErrors

        ZStack {
            DrinkScreenBackground()

            ScrollView {
                VStack(spacing: 0) {
                    DrinkScreenHeader(
                        title: pageTitle,
                        subtitle: isEditingBuiltIn ? nil : "创建后可加入常用",
                        onBack: { dismiss() }
                    )

                    Image(draft.iconKey)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 88, height: 88)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 18)
                        .accessibilityHidden(true)

                    editorFieldRow(label: "名称") {
                        TextField("饮品名称", text: $draft.name)
                            .textInputAutocapitalization(.never)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(WaterUpTheme.Palette.textPrimary.color)
                            .textFieldStyle(.plain)
                            .focused($focusedField, equals: .name)
                            .disabled(isEditingBuiltIn)
                            .accessibilityIdentifier("waterup.drink-editor.name")
                    }
                    .padding(.top, 18)
                    validationMessage(for: .emptyName, errors: validationErrors)
                    validationMessage(for: .nameTooLong, errors: validationErrors)

                    categoryRow
                        .padding(.top, 14)

                    editorFieldRow(label: "估算含水比例") {
                        numericField(
                            unit: "%",
                            placeholder: "0–100",
                            text: $draft.waterRatioText,
                            field: .waterRatio,
                            identifier: "waterup.drink-editor.water-ratio"
                        )
                        .disabled(isEditingBuiltIn)
                    }
                    .padding(.top, 14)
                    validationMessage(for: .invalidWaterRatio, errors: validationErrors)

                    editorFieldRow(label: "默认杯量") {
                        numericField(
                            unit: "mL",
                            placeholder: "1–2000",
                            text: $draft.defaultVolumeText,
                            field: .defaultVolume,
                            identifier: "waterup.drink-editor.default-volume"
                        )
                    }
                    .padding(.top, 14)
                    validationMessage(for: .invalidDefaultVolume, errors: validationErrors)

                    favoriteRow
                        .padding(.top, 20)

                    appearanceRow
                        .padding(.top, 16)

                    if let saveErrorMessage {
                        WaterUpStatusMessage(
                            kind: .error,
                            title: "饮品未保存",
                            message: saveErrorMessage
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                    }

                    drinkPrimaryButton {
                        save()
                    }
                    .disabled(!validationErrors.isEmpty || isSaving)
                    .opacity(validationErrors.isEmpty && !isSaving ? 1 : 0.55)
                    .padding(.top, 24)
                }
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isShowingAppearancePicker) {
            DrinkAppearancePicker(
                iconKey: $draft.iconKey
            )
        }
        .task {
            loadDraft()
        }
    }

    private var categoryRow: some View {
        Menu {
            ForEach(DrinkCategory.allCases, id: \.rawValue) { category in
                Button(category.displayName) {
                    draft.categoryRawValue = category.rawValue
                }
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("分类")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(WaterUpTheme.Palette.textMuted.color)

                    Text(currentCategoryTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(WaterUpTheme.Palette.textPrimary.color)
                }

                Spacer(minLength: 8)

                Text("选择")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(WaterUpTheme.Palette.textMuted.color)
            }
            .padding(.horizontal, 16)
            .frame(height: 58)
            .background(editorSurface)
        }
        .buttonStyle(.plain)
        .disabled(isEditingBuiltIn)
        .accessibilityIdentifier("waterup.drink-editor.category")
        .padding(.horizontal, 20)
    }

    private var favoriteRow: some View {
        Toggle("加入常用饮品", isOn: $draft.isFavorite)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(WaterUpTheme.Palette.textPrimary.color)
            .tint(WaterUpTheme.Palette.actionPrimary.color)
            .padding(.horizontal, 18)
            .frame(height: 62)
            .background(editorSurface)
            .accessibilityIdentifier("waterup.drink-editor.favorite")
            .padding(.horizontal, 20)
    }

    private var appearanceRow: some View {
        Button {
            isShowingAppearancePicker = true
        } label: {
            HStack {
                Text("图标")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(WaterUpTheme.Palette.textPrimary.color)

                Spacer(minLength: 8)

                Image(draft.iconKey)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(red: 170 / 255, green: 185 / 255, blue: 201 / 255))
                    .frame(width: 16)
            }
            .padding(.horizontal, 18)
            .frame(height: 60)
            .background(editorSurface)
        }
        .buttonStyle(.plain)
        .disabled(isEditingBuiltIn)
        .accessibilityLabel("图标，当前为\(selectedIconTitle)")
        .accessibilityIdentifier("waterup.drink-editor.appearance")
        .padding(.horizontal, 20)
    }

    private var selectedIconTitle: String {
        DrinkIconOption.all.first { $0.key == draft.iconKey }?.title ?? "饮品图标"
    }

    private var currentCategoryTitle: String {
        DrinkCategory(rawValue: draft.categoryRawValue)?.displayName ?? "其他"
    }

    private var editorSurface: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(WaterUpTheme.Palette.surfacePrimary.color)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(WaterUpTheme.Palette.divider.color, lineWidth: 1)
            }
    }

    private func editorFieldRow<Content: View>(
        label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(WaterUpTheme.Palette.textMuted.color)

            content()
        }
        .padding(.horizontal, 16)
        .frame(height: 58, alignment: .leading)
        .background(editorSurface)
        .padding(.horizontal, 20)
    }

    private func drinkPrimaryButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Text("保存饮品")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .offset(x: 10)

                HStack {
                    Image(systemName: "checkmark")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(WaterUpTheme.Palette.actionPrimary.color)
                        .frame(width: 34, height: 34)
                        .background(Color.white.opacity(0.95), in: Circle())

                    Spacer()
                }
                .padding(.leading, 88)
            }
            .frame(width: 326, height: 54)
            .background(
                LinearGradient(
                    colors: [
                        WaterUpTheme.Palette.actionPrimary.color,
                        WaterUpTheme.Palette.actionPressed.color
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("waterup.drink-editor.save")
    }

    private func numericField(
        unit: String,
        placeholder: String,
        text: Binding<String>,
        field: Field,
        identifier: String
    ) -> some View {
        HStack(spacing: WaterUpTheme.Spacing.x2) {
            TextField(placeholder, text: text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.leading)
                .monospacedDigit()
                .focused($focusedField, equals: field)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(WaterUpTheme.Palette.textPrimary.color)
                .textFieldStyle(.plain)
                .accessibilityIdentifier(identifier)

            Spacer(minLength: WaterUpTheme.Spacing.x2)

            Text(unit)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(WaterUpTheme.Palette.textMuted.color)
        }
    }

    @ViewBuilder
    private func validationMessage(
        for error: DrinkDraftValidationError,
        errors: Set<DrinkDraftValidationError>
    ) -> some View {
        if errors.contains(error) {
            Text(error.message)
                .font(WaterUpTheme.Typography.caption)
                .foregroundStyle(WaterUpTheme.Palette.statusError.color)
        }
    }

    private func save() {
        guard !isSaving else {
            return
        }

        isSaving = true
        defer { isSaving = false }
        saveErrorMessage = nil

        do {
            if drinkID == nil {
                try drinkService.create(draft: draft, in: modelContext)
            } else {
                try drinkService.update(draft: draft, in: modelContext)
            }
            onSaved()
            dismiss()
        } catch let error as DrinkServiceError {
            switch error {
            case let .invalidDraft(errors):
                saveErrorMessage = errors.map(\.message).joined(separator: "；")
            case .drinkNotFound, .drinkIsNotAvailable, .builtInDrinkCannotBeEdited:
                saveErrorMessage = "饮品状态已变化，请重新打开编辑页面。"
            }
        } catch {
            saveErrorMessage = "保存失败，请稍后重试。"
        }
    }

    private func loadDraft() {
        guard let drinkID else {
            editingSource = nil
            return
        }

        do {
            let drink = try DrinkCatalogService().activeDrink(id: drinkID, in: modelContext)
            draft = DrinkDraft(drink: drink)
            editingSource = drink.source
        } catch {
            saveErrorMessage = "饮品暂时无法读取，请关闭后重试。"
        }
    }

    private enum Field: Hashable {
        case name
        case waterRatio
        case defaultVolume
    }
}

struct DrinkScreenBackground: View {
    var body: some View {
        GeometryReader { _ in
            ZStack(alignment: .topLeading) {
                LinearGradient(
                    colors: [
                        WaterUpTheme.Palette.backgroundBase.color,
                        Color(red: 248 / 255, green: 251 / 255, blue: 1),
                        WaterUpTheme.Palette.backgroundTint.color
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 429, height: 429)
                    .position(x: 58.5, y: 42.2)

                Circle()
                    .fill(Color(red: 205 / 255, green: 239 / 255, blue: 1).opacity(0.14))
                    .frame(width: 374.4, height: 374.4)
                    .position(x: 351, y: 236.32)
            }
        }
        .ignoresSafeArea()
    }
}

struct DrinkScreenHeader: View {
    let title: String
    let subtitle: String?
    let trailingSystemImage: String?
    let onBack: () -> Void
    let onTrailing: (() -> Void)?

    init(
        title: String,
        subtitle: String?,
        trailingSystemImage: String? = nil,
        onBack: @escaping () -> Void,
        onTrailing: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailingSystemImage = trailingSystemImage
        self.onBack = onBack
        self.onTrailing = onTrailing
    }

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(WaterUpTheme.Palette.textSecondary.color)
                    .frame(width: 44, height: 44)
                    .background(WaterUpTheme.Palette.surfacePrimary.color, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("返回")

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .foregroundStyle(WaterUpTheme.Palette.textPrimary.color)
                    .lineLimit(1)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(WaterUpTheme.Palette.textMuted.color)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            if let trailingSystemImage, let onTrailing {
                Button(action: onTrailing) {
                    Image(systemName: trailingSystemImage)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(WaterUpTheme.Palette.actionPrimary.color)
                        .frame(width: 44, height: 44)
                        .background(WaterUpTheme.Palette.surfacePrimary.color, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("新增自定义饮品")
                .accessibilityIdentifier("waterup.drink-management.add-custom-toolbar")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }
}

private struct DrinkAppearancePicker: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var iconKey: String

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: WaterUpTheme.Spacing.x5) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 84))], spacing: WaterUpTheme.Spacing.x3) {
                        ForEach(DrinkIconOption.all) { option in
                            iconButton(option)
                        }
                    }
                }
                .padding(.horizontal, WaterUpTheme.Spacing.pageHorizontal)
                .padding(.vertical, WaterUpTheme.Spacing.x5)
            }
            .navigationTitle("选择图标")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .accessibilityIdentifier("waterup.drink-editor.appearance.done")
                }
            }
        }
    }

    private func iconButton(_ option: DrinkIconOption) -> some View {
        Button {
            iconKey = option.key
        } label: {
            VStack(spacing: WaterUpTheme.Spacing.x1) {
                ZStack(alignment: .topTrailing) {
                    Image(option.key)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 52, height: 52)

                    if iconKey == option.key {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(WaterUpTheme.Palette.actionPrimary.color)
                            .background(.white, in: Circle())
                    }
                }

                Text(option.title)
                    .font(WaterUpTheme.Typography.caption)
                    .foregroundStyle(WaterUpTheme.Palette.textPrimary.color)
            }
            .frame(maxWidth: .infinity, minHeight: 80)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("图标\(option.title)\(iconKey == option.key ? "，已选择" : "")")
        .accessibilityIdentifier("waterup.drink-editor.icon.\(option.key)")
    }
}

private struct DrinkIconOption: Identifiable {
    let key: String
    let title: String

    var id: String { key }

    static let all = [
        DrinkIconOption(key: WaterUpAsset.Drink.water, title: "水"),
        DrinkIconOption(key: WaterUpAsset.Drink.tea, title: "茶"),
        DrinkIconOption(key: WaterUpAsset.Drink.coffee, title: "咖啡"),
        DrinkIconOption(key: WaterUpAsset.Drink.milk, title: "牛奶"),
        DrinkIconOption(key: WaterUpAsset.Drink.juice, title: "果汁"),
        DrinkIconOption(key: WaterUpAsset.Drink.soda, title: "汽水"),
        DrinkIconOption(key: WaterUpAsset.Drink.sport, title: "运动饮料"),
        DrinkIconOption(key: WaterUpAsset.Drink.custom, title: "自定义")
    ]
}

#Preview {
    DrinkEditorView(onSaved: {})
        .modelContainer(WaterUpPreviewData.makeModelContainer())
}

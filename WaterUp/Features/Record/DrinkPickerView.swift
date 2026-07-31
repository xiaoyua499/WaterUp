import SwiftData
import SwiftUI

struct DrinkPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let selectedDrinkID: UUID
    let onSelect: (DrinkDefinition) -> Void

    @State private var catalog = DrinkCatalog(builtIn: [], custom: [])
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var isShowingReadError = false

    private let catalogService = DrinkCatalogService()

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("正在读取饮品…")
                } else if isShowingReadError {
                    ContentUnavailableView {
                        Label("饮品暂时无法读取", systemImage: "exclamationmark.triangle.fill")
                    } actions: {
                        Button("重新读取", action: loadCatalog)
                    }
                } else if filteredBuiltIn.isEmpty, filteredCustom.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List {
                        if !filteredBuiltIn.isEmpty {
                            Section("内置饮品") {
                                ForEach(filteredBuiltIn, id: \.id) { drink in
                                    drinkRow(drink)
                                }
                            }
                        }

                        if !filteredCustom.isEmpty {
                            Section("自定义饮品") {
                                ForEach(filteredCustom, id: \.id) { drink in
                                    drinkRow(drink)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("选择饮品")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "搜索饮品")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            loadCatalog()
        }
    }

    private var filteredBuiltIn: [DrinkDefinition] {
        filtered(catalog.builtIn)
    }

    private var filteredCustom: [DrinkDefinition] {
        filtered(catalog.custom)
    }

    private func filtered(_ drinks: [DrinkDefinition]) -> [DrinkDefinition] {
        guard !searchText.isEmpty else {
            return drinks
        }

        return drinks.filter { drink in
            drink.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func drinkRow(_ drink: DrinkDefinition) -> some View {
        Button {
            onSelect(drink)
            dismiss()
        } label: {
            HStack(spacing: WaterUpTheme.Spacing.x3) {
                Image(drink.iconKey)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: WaterUpTheme.Spacing.x1) {
                    Text(drink.name)
                        .font(WaterUpTheme.Typography.headline)
                        .foregroundStyle(WaterUpTheme.Palette.textPrimary.color)

                    Text("估算含水比例 \(drink.waterRatioPercent)% · 默认 \(drink.defaultVolumeML) mL")
                        .font(WaterUpTheme.Typography.caption)
                        .foregroundStyle(WaterUpTheme.Palette.textMuted.color)
                }

                Spacer(minLength: WaterUpTheme.Spacing.x2)

                if drink.id == selectedDrinkID {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(WaterUpTheme.Palette.actionPrimary.color)
                        .accessibilityLabel("当前选择")
                }
            }
            .frame(minHeight: WaterUpTheme.Layout.minimumTapTarget)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "\(drink.name)，估算含水比例 \(drink.waterRatioPercent)%，默认杯量 \(drink.defaultVolumeML) mL"
        )
        .accessibilityIdentifier("waterup.record.drink.\(drink.id.uuidString)")
    }

    private func loadCatalog() {
        isLoading = true
        isShowingReadError = false

        do {
            catalog = try catalogService.activeCatalog(in: modelContext)
        } catch {
            catalog = DrinkCatalog(builtIn: [], custom: [])
            isShowingReadError = true
        }

        isLoading = false
    }
}

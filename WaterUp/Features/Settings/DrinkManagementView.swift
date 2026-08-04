import SwiftData
import SwiftUI

struct DrinkManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var catalog = DrinkCatalog(builtIn: [], custom: [])
    @State private var isLoading = true
    @State private var isShowingReadError = false
    @State private var isShowingDrinkEditor = false
    @State private var editingDrinkID: UUID?

    private let catalogService = DrinkCatalogService()

    private var favoriteCount: Int {
        catalog.builtIn.filter(\.isFavorite).count + catalog.custom.filter(\.isFavorite).count
    }

    private var drinks: [DrinkDefinition] {
        catalog.builtIn + catalog.custom
    }

    var body: some View {
        ZStack {
            DrinkScreenBackground()

            ScrollView {
                VStack(spacing: 0) {
                    DrinkScreenHeader(
                        title: "饮品管理",
                        subtitle: "内置比例为产品估算",
                        trailingSystemImage: "plus",
                        onBack: { dismiss() },
                        onTrailing: openNewDrinkEditor
                    )

                    favoriteSummary
                        .padding(.top, 20)

                    contentState
                        .padding(.top, 16)

                    if !isLoading && !isShowingReadError {
                        addCustomButton
                            .padding(.top, 34)
                    }
                }
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            loadCatalog()
        }
        .onReceive(NotificationCenter.default.publisher(for: .waterUpDrinkCatalogDidChange)) { _ in
            loadCatalog()
        }
        .navigationDestination(isPresented: $isShowingDrinkEditor) {
            DrinkEditorView(drinkID: editingDrinkID, onSaved: loadCatalog)
        }
    }

    @ViewBuilder
    private var contentState: some View {
        if isLoading {
            ProgressView("正在读取饮品…")
                .frame(maxWidth: .infinity, minHeight: 160)
        } else if isShowingReadError {
            VStack(spacing: WaterUpTheme.Spacing.x4) {
                WaterUpStatusMessage(
                    kind: .error,
                    title: "饮品暂时无法读取",
                    message: "请稍后重试。"
                )

                WaterUpSecondaryButton(
                    title: "重新读取",
                    systemImage: "arrow.clockwise",
                    action: loadCatalog
                )
            }
            .padding(.horizontal, 20)
        } else {
            drinkList
        }
    }

    private var favoriteSummary: some View {
        HStack(spacing: 12) {
            Image(systemName: "scope")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(WaterUpTheme.Palette.actionPrimary.color)

            Text("常用饮品 \(favoriteCount)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(WaterUpTheme.Palette.textSecondary.color)
                .lineLimit(1)
                .accessibilityIdentifier("waterup.drink-management.favorite-count")

            Spacer(minLength: 8)

            Text("不限数量")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(WaterUpTheme.Palette.textMuted.color)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .frame(height: 46)
        .background(WaterUpTheme.Palette.surfacePrimary.color, in: Capsule())
        .overlay {
            Capsule()
                .stroke(WaterUpTheme.Palette.divider.color, lineWidth: 1)
        }
        .padding(.horizontal, 20)
    }

    private var drinkList: some View {
        VStack(spacing: 0) {
            ForEach(Array(drinks.enumerated()), id: \.element.id) { index, drink in
                drinkRow(drink)

                if index < drinks.count - 1 {
                    Divider()
                        .overlay(WaterUpTheme.Palette.divider.color)
                        .padding(.leading, 78)
                        .padding(.trailing, 16)
                }
            }
        }
        .padding(.vertical, 8)
        .background(
            WaterUpTheme.Palette.surfacePrimary.color,
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(WaterUpTheme.Palette.divider.color, lineWidth: 1)
        }
        .padding(.horizontal, 20)
    }

    private func drinkRow(_ drink: DrinkDefinition) -> some View {
        Button {
            editingDrinkID = drink.id
            isShowingDrinkEditor = true
        } label: {
            HStack(spacing: 14) {
                Image(drink.iconKey)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56, height: 56)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(drink.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(WaterUpTheme.Palette.textPrimary.color)
                        .lineLimit(1)

                    Text("\(drink.waterRatioPercent)% · \(drink.defaultVolumeML) mL")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(WaterUpTheme.Palette.textMuted.color)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

                if drink.isFavorite {
                    Text("常用")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(WaterUpTheme.Palette.actionPrimary.color)
                        .lineLimit(1)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(red: 170 / 255, green: 185 / 255, blue: 201 / 255))
                    .frame(width: 16)
            }
            .padding(.horizontal, 8)
            .frame(minHeight: 76)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            drink.sourceRawValue == DrinkSource.builtIn.rawValue
                ? "编辑\(drink.name)默认杯量"
                : "编辑\(drink.name)"
        )
        .accessibilityIdentifier("waterup.drink-management.edit.\(drink.seedKey ?? drink.id.uuidString)")
    }

    private var addCustomButton: some View {
        Button {
            openNewDrinkEditor()
        } label: {
            Text("新增自定义饮品")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(WaterUpTheme.Palette.actionPrimary.color)
                .frame(width: 206, height: 44)
                .background(WaterUpTheme.Palette.surfacePrimary.color, in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(WaterUpTheme.Palette.actionPrimary.color, lineWidth: 1.5)
                }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("waterup.drink-management.add-custom")
    }

    private func openNewDrinkEditor() {
        editingDrinkID = nil
        isShowingDrinkEditor = true
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

#Preview {
    DrinkManagementView()
        .modelContainer(WaterUpPreviewData.makeModelContainer())
}

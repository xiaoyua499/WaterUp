import SwiftUI

struct WaterUpPage<Content: View>: View {
    let title: String
    let titleDisplayMode: NavigationBarItem.TitleDisplayMode
    private let content: Content

    init(
        title: String,
        titleDisplayMode: NavigationBarItem.TitleDisplayMode = .large,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.titleDisplayMode = titleDisplayMode
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WaterUpTheme.Spacing.x5) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, WaterUpTheme.Spacing.pageHorizontal)
            .padding(.top, WaterUpTheme.Spacing.x4)
            .padding(
                .bottom,
                WaterUpTheme.Spacing.x8 + WaterUpTheme.Spacing.x10 * 2
            )
        }
        .scrollIndicators(.hidden)
        .background {
            // 背景独立于内容布局，避免缩放后的图片撑大页面并遮挡顶部内容。
            Image(WaterUpAsset.Background.light)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(titleDisplayMode)
    }
}

struct WaterUpCard<Content: View>: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(WaterUpTheme.Spacing.x5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: WaterUpTheme.Radius.large, style: .continuous)
                    .fill(surfaceColor)
            }
            .overlay {
                RoundedRectangle(cornerRadius: WaterUpTheme.Radius.large, style: .continuous)
                    .stroke(WaterUpTheme.Palette.divider.color.opacity(0.65), lineWidth: 1)
            }
            .shadow(
                color: WaterUpTheme.Palette.textPrimary.color.opacity(0.05),
                radius: 12,
                y: 4
            )
    }

    private var surfaceColor: Color {
        if reduceTransparency {
            return Color(uiColor: .systemBackground)
        }

        return WaterUpTheme.Palette.surfacePrimary.color
    }
}

struct WaterUpDisplayText: View {
    let value: String

    @ScaledMetric(relativeTo: .largeTitle) private var fontSize = WaterUpTheme.Typography.displayPointSize

    var body: some View {
        Text(value)
            .font(.system(size: fontSize, weight: .bold, design: .rounded).monospacedDigit())
            .foregroundStyle(WaterUpTheme.Palette.textPrimary.color)
            .lineLimit(1)
            .minimumScaleFactor(0.65)
    }
}

struct WaterUpSectionTitle: View {
    let title: String
    let detail: String?

    init(_ title: String, detail: String? = nil) {
        self.title = title
        self.detail = detail
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(WaterUpTheme.Typography.title2)
                .foregroundStyle(WaterUpTheme.Palette.textPrimary.color)

            Spacer(minLength: WaterUpTheme.Spacing.x3)

            if let detail {
                Text(detail)
                    .font(WaterUpTheme.Typography.callout)
                    .foregroundStyle(WaterUpTheme.Palette.textMuted.color)
            }
        }
    }
}

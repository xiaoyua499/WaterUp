import SwiftUI

struct WaterUpPage<Content: View>: View {
    let title: String
    private let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    WaterUpTheme.Palette.backgroundBase.color,
                    WaterUpTheme.Palette.backgroundTint.color
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: WaterUpTheme.Spacing.x5) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, WaterUpTheme.Spacing.pageHorizontal)
                .padding(.top, WaterUpTheme.Spacing.x4)
                .padding(.bottom, WaterUpTheme.Spacing.x8)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
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

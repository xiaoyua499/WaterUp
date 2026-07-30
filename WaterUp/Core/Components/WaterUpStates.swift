import SwiftUI

enum WaterUpMessageKind {
    case info
    case success
    case warning
    case error

    var systemImage: String {
        switch self {
        case .info:
            return "info.circle.fill"
        case .success:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.octagon.fill"
        }
    }

    var color: Color {
        switch self {
        case .info:
            return WaterUpTheme.Palette.actionPrimary.color
        case .success:
            return WaterUpTheme.Palette.statusSuccess.color
        case .warning:
            return WaterUpTheme.Palette.statusWarning.color
        case .error:
            return WaterUpTheme.Palette.statusError.color
        }
    }
}

struct WaterUpStatusMessage: View {
    let kind: WaterUpMessageKind
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: WaterUpTheme.Spacing.x3) {
            Image(systemName: kind.systemImage)
                .font(.title3)
                .foregroundStyle(kind.color)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: WaterUpTheme.Spacing.x1) {
                Text(title)
                    .font(WaterUpTheme.Typography.headline)
                    .foregroundStyle(WaterUpTheme.Palette.textPrimary.color)

                Text(message)
                    .font(WaterUpTheme.Typography.body)
                    .foregroundStyle(WaterUpTheme.Palette.textSecondary.color)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(WaterUpTheme.Spacing.x4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(kind.color.opacity(0.11), in: RoundedRectangle(cornerRadius: WaterUpTheme.Radius.medium, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

struct WaterUpEmptyState: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: WaterUpTheme.Spacing.x3) {
            Image(systemName: systemImage)
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .foregroundStyle(WaterUpTheme.Palette.actionPrimary.color)
                .accessibilityHidden(true)

            Text(title)
                .font(WaterUpTheme.Typography.title2)
                .foregroundStyle(WaterUpTheme.Palette.textPrimary.color)

            Text(message)
                .font(WaterUpTheme.Typography.body)
                .foregroundStyle(WaterUpTheme.Palette.textSecondary.color)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(WaterUpTheme.Spacing.x6)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

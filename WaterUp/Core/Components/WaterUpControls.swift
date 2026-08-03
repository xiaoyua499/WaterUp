import SwiftUI

struct WaterUpPrimaryButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        if #available(iOS 26, *) {
            button
                .buttonStyle(.glassProminent)
                .tint(WaterUpTheme.Palette.actionPrimary.color)
        } else {
            button
                .buttonStyle(.borderedProminent)
                .tint(WaterUpTheme.Palette.actionPrimary.color)
        }
    }

    private var button: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(WaterUpTheme.Typography.headline)
                .frame(maxWidth: .infinity)
                .frame(minHeight: WaterUpTheme.Layout.minimumTapTarget)
        }
    }
}

struct WaterUpSecondaryButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        if #available(iOS 26, *) {
            button
                .buttonStyle(.glass)
                .tint(WaterUpTheme.Palette.actionPrimary.color)
        } else {
            button
                .buttonStyle(.bordered)
                .tint(WaterUpTheme.Palette.actionPrimary.color)
        }
    }

    private var button: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(WaterUpTheme.Typography.headline)
                .frame(maxWidth: .infinity)
                .frame(minHeight: WaterUpTheme.Layout.minimumTapTarget)
        }
    }
}

struct WaterUpDestructiveButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        if #available(iOS 26, *) {
            button
                .buttonStyle(.glassProminent)
                .tint(WaterUpTheme.Palette.statusError.color)
        } else {
            button
                .buttonStyle(.borderedProminent)
                .tint(WaterUpTheme.Palette.statusError.color)
        }
    }

    private var button: some View {
        Button(role: .destructive, action: action) {
            Label(title, systemImage: systemImage)
                .font(WaterUpTheme.Typography.headline)
                .frame(maxWidth: .infinity)
                .frame(minHeight: WaterUpTheme.Layout.minimumTapTarget)
        }
    }
}

struct WaterUpSettingsRow: View {
    let title: String
    let detail: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: WaterUpTheme.Spacing.x3) {
                Image(systemName: systemImage)
                    .foregroundStyle(WaterUpTheme.Palette.actionPrimary.color)
                    .frame(width: WaterUpTheme.Layout.minimumTapTarget, height: WaterUpTheme.Layout.minimumTapTarget)

                Text(title)
                    .font(WaterUpTheme.Typography.headline)
                    .foregroundStyle(WaterUpTheme.Palette.textPrimary.color)

                Spacer(minLength: WaterUpTheme.Spacing.x2)

                Text(detail)
                    .font(WaterUpTheme.Typography.callout)
                    .foregroundStyle(WaterUpTheme.Palette.textMuted.color)
                    .lineLimit(1)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WaterUpTheme.Palette.textMuted.color)
            }
            .frame(minHeight: WaterUpTheme.Layout.minimumTapTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

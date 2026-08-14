import Foundation
import SwiftUI

enum AppVersion {
    static var currentDisplay: String {
        guard let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              !shortVersion.isEmpty,
              let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
              !buildNumber.isEmpty else {
            return "版本不可用"
        }

        return "WaterUp \(shortVersion) (\(buildNumber))"
    }
}

struct UnitExplanationView: View {
    var body: some View {
        WaterUpPage(title: "单位说明") {
            Text("WaterUp v1.0 统一使用 mL")
                .font(WaterUpTheme.Typography.callout)
                .foregroundStyle(WaterUpTheme.Palette.textMuted.color)

            unitCard(
                title: "饮品容量",
                detail: "实际喝下的饮品体积。例如一杯茶 300 mL。",
                systemImage: "drop.fill",
                tint: WaterUpTheme.Palette.actionPrimary.color
            )

            unitCard(
                title: "有效补水量",
                detail: "计入每日目标的折算水量。\n饮品容量 × 估算含水比例",
                systemImage: "scope",
                tint: WaterUpTheme.Palette.hydrationProgressStart.color
            )

            WaterUpCard {
                Text("计算示例")
                    .font(WaterUpTheme.Typography.headline)
                    .foregroundStyle(WaterUpTheme.Palette.textPrimary.color)

                Text("300 mL × 90% = 270 mL")
                    .font(WaterUpTheme.Typography.title2)
                    .foregroundStyle(WaterUpTheme.Palette.hydrationProgressStart.color)

                Text("结果四舍五入为整数 mL")
                    .font(WaterUpTheme.Typography.callout)
                    .foregroundStyle(WaterUpTheme.Palette.textMuted.color)
            }
            .accessibilityIdentifier("waterup.unit-explanation.example")

            WaterUpStatusMessage(
                kind: .info,
                title: "含水比例属于产品估算值",
                message: "不同品牌与配方可能存在差异，不代表特定品牌的精确检测。"
            )
        }
    }

    private func unitCard(title: String, detail: String, systemImage: String, tint: Color) -> some View {
        WaterUpCard {
            HStack(alignment: .top, spacing: WaterUpTheme.Spacing.x4) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(tint)
                    .frame(width: WaterUpTheme.Layout.minimumTapTarget)

                VStack(alignment: .leading, spacing: WaterUpTheme.Spacing.x2) {
                    Text(title)
                        .font(WaterUpTheme.Typography.title2)
                        .foregroundStyle(WaterUpTheme.Palette.textPrimary.color)

                    Text(detail)
                        .font(WaterUpTheme.Typography.callout)
                        .foregroundStyle(WaterUpTheme.Palette.textMuted.color)
                }
            }
        }
    }
}

struct DataPrivacyView: View {
    var body: some View {
        WaterUpPage(title: "数据与隐私") {
            Text("无需账号 · 仅本机保存")
                .font(WaterUpTheme.Typography.callout)
                .foregroundStyle(WaterUpTheme.Palette.textMuted.color)

            WaterUpStatusMessage(
                kind: .info,
                title: "你的记录不会上传",
                message: "记录、目标、饮品和提醒配置仅保存在本机；飞行模式下仍可完整使用。"
            )

            WaterUpCard {
                privacyItem("不需要用户账号", systemImage: "checkmark.shield.fill", tint: WaterUpTheme.Palette.statusSuccess.color)
                Divider().overlay(WaterUpTheme.Palette.divider.color)
                privacyItem("卸载 App 会删除本地数据，v1.0 无法恢复", systemImage: "exclamationmark.triangle.fill", tint: WaterUpTheme.Palette.statusWarning.color)
                Divider().overlay(WaterUpTheme.Palette.divider.color)
                privacyItem("除通知权限外，不申请无关权限", systemImage: "bell.fill", tint: WaterUpTheme.Palette.actionPrimary.color)
                Divider().overlay(WaterUpTheme.Palette.divider.color)
                privacyItem("用户备注完整内容不会写入日志", systemImage: "doc.text.magnifyingglass", tint: WaterUpTheme.Palette.hydrationProgressStart.color)
            }

            WaterUpStatusMessage(
                kind: .info,
                title: "健康信息声明",
                message: "WaterUp 用于个人记录与习惯管理。含水比例和有效补水量均为估算值，不提供医疗诊断或治疗建议。"
            )
            .accessibilityIdentifier("waterup.privacy.health-disclaimer")
        }
    }

    private func privacyItem(_ title: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: WaterUpTheme.Spacing.x3) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .frame(width: WaterUpTheme.Layout.minimumTapTarget, height: WaterUpTheme.Layout.minimumTapTarget)

            Text(title)
                .font(WaterUpTheme.Typography.headline)
                .foregroundStyle(WaterUpTheme.Palette.textPrimary.color)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(minHeight: WaterUpTheme.Layout.minimumTapTarget, alignment: .leading)
    }
}

#Preview {
    NavigationStack {
        UnitExplanationView()
    }
}

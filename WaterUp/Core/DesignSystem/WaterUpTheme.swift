import SwiftUI

struct WaterUpColorToken: Equatable, Sendable {
    let red: UInt8
    let green: UInt8
    let blue: UInt8

    var color: Color {
        Color(
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255
        )
    }
}

enum WaterUpTheme {
    enum Palette {
        static let backgroundBase = WaterUpColorToken(red: 244, green: 248, blue: 255)
        static let backgroundTint = WaterUpColorToken(red: 236, green: 245, blue: 255)
        static let surfacePrimary = WaterUpColorToken(red: 255, green: 255, blue: 255)
        static let surfaceSecondary = WaterUpColorToken(red: 248, green: 251, blue: 255)
        static let textPrimary = WaterUpColorToken(red: 8, green: 35, blue: 66)
        static let textSecondary = WaterUpColorToken(red: 40, green: 70, blue: 100)
        static let textMuted = WaterUpColorToken(red: 117, green: 137, blue: 159)
        static let divider = WaterUpColorToken(red: 221, green: 232, blue: 243)
        static let actionPrimary = WaterUpColorToken(red: 62, green: 152, blue: 245)
        static let actionPressed = WaterUpColorToken(red: 46, green: 126, blue: 234)
        static let hydrationProgressStart = WaterUpColorToken(red: 67, green: 203, blue: 208)
        static let hydrationProgressEnd = WaterUpColorToken(red: 62, green: 152, blue: 245)
        static let statusSuccess = WaterUpColorToken(red: 72, green: 185, blue: 133)
        static let statusWarning = WaterUpColorToken(red: 240, green: 166, blue: 80)
        static let statusError = WaterUpColorToken(red: 232, green: 94, blue: 104)
        static let statusOverGoal = WaterUpColorToken(red: 139, green: 106, blue: 232)
    }

    enum Spacing {
        static let x1: CGFloat = 4
        static let x2: CGFloat = 8
        static let x3: CGFloat = 12
        static let x4: CGFloat = 16
        static let x5: CGFloat = 20
        static let x6: CGFloat = 24
        static let x8: CGFloat = 32
        static let x10: CGFloat = 40
        static let pageHorizontal = x5
    }

    enum Radius {
        static let small: CGFloat = 12
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let extraLarge: CGFloat = 32
        static let full: CGFloat = 999
    }

    enum Typography {
        static let displayPointSize: CGFloat = 64
        static let title1 = Font.system(.title, design: .rounded).weight(.bold)
        static let title2 = Font.system(.title2, design: .rounded).weight(.bold)
        static let headline = Font.headline.weight(.semibold)
        static let body = Font.body
        static let callout = Font.callout.weight(.medium)
        static let caption = Font.caption
    }

    enum Motion {
        static let progressDuration: TimeInterval = 0.5
        static let confirmationDuration: TimeInterval = 0.2
        static let undoTimeout: TimeInterval = 5
        static let reducedMotionDuration: TimeInterval = 0
    }

    enum Layout {
        static let minimumTapTarget: CGFloat = 44
    }
}

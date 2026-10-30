import SwiftUI
import UIKit

extension Color {
    // Interval colours as fills: the ring, bars and tinted backgrounds. They are too light to read
    // as text on a light background (green came out at 1.6:1), so text and icons use the readable
    // shades below instead.
    static let runOrange     = Color(red: 1.00, green: 0.42, blue: 0.21)  // #FF6B35
    static let walkBlue      = Color(red: 0.29, green: 0.56, blue: 0.85)  // #4A90D9
    static let warmCoolGreen = Color(red: 0.48, green: 0.78, blue: 0.49)  // #7BC67E

    // Text and icon shades, each at least 4.5:1 against the backgrounds they land on in that
    // appearance. Same values as the Android app's Color.kt.
    static let runOrangeText = adaptive(light: 0xA8380A, dark: 0xFFA07A)
    static let walkBlueText  = adaptive(light: 0x1A62A3, dark: 0x9CC4EE)
    static let greenText     = adaptive(light: 0x276C2B, dark: 0x94D597)

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(rgb: dark) : UIColor(rgb: light) })
    }
}

func intervalTextColor(_ type: IntervalType) -> Color {
    switch type {
    case .run:               return .runOrangeText
    case .walk:              return .walkBlueText
    case .warmup, .cooldown: return .greenText
    }
}

private extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(red: CGFloat((rgb >> 16) & 0xFF) / 255, green: CGFloat((rgb >> 8) & 0xFF) / 255,
                  blue: CGFloat(rgb & 0xFF) / 255, alpha: 1)
    }
}

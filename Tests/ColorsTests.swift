import SwiftUI
import UIKit
import XCTest
@testable import CtoK

// The interval text shades must stay readable (WCAG AA, 4.5:1) on every background they're drawn
// on: plain and grouped list backgrounds and cells, in both appearances.
final class ColorsTests: XCTestCase {

    private func luminance(_ color: UIColor) -> Double {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        func channel(_ c: CGFloat) -> Double {
            let c = Double(c)
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
    }

    private func contrast(_ a: UIColor, _ b: UIColor) -> Double {
        let (l1, l2) = (luminance(a), luminance(b))
        return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
    }

    func testIntervalTextShadesAreReadableInLightAndDarkMode() {
        let backgrounds: [UIColor] = [.systemBackground, .systemGroupedBackground,
                                      .secondarySystemGroupedBackground, .secondarySystemBackground]
        for style in [UIUserInterfaceStyle.light, .dark] {
            let traits = UITraitCollection(userInterfaceStyle: style)
            for type in [IntervalType.run, .walk, .warmup, .cooldown] {
                let text = UIColor(intervalTextColor(type)).resolvedColor(with: traits)
                for background in backgrounds {
                    let ratio = contrast(text, background.resolvedColor(with: traits))
                    XCTAssertGreaterThanOrEqual(ratio, 4.5, "\(type) text in \(style == .dark ? "dark" : "light") mode: \(ratio):1")
                }
            }
        }
    }
}

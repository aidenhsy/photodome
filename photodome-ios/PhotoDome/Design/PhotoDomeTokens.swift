import SwiftUI
import UIKit

/// PhotoDome Design System 1.0.
///
/// Black and white are permanent brand primitives. Product components consume
/// adaptive semantic roles so appearance changes remain centralized.
enum PhotoDomeTokens {
    enum Brand {
        static let ink = Color.black
        static let white = Color.white
    }

    enum Neutral {
        static let soft = Color(
            red: 245 / 255,
            green: 245 / 255,
            blue: 243 / 255
        )
        static let hairline = Color(
            red: 216 / 255,
            green: 216 / 255,
            blue: 212 / 255
        )
        static let graphite = Color(
            red: 102 / 255,
            green: 102 / 255,
            blue: 98 / 255
        )
        static let charcoal = Color(
            red: 23 / 255,
            green: 23 / 255,
            blue: 23 / 255
        )
        static let night = Color(
            red: 10 / 255,
            green: 10 / 255,
            blue: 10 / 255
        )
    }

    enum State {
        static let success = Color(
            red: 36 / 255,
            green: 138 / 255,
            blue: 61 / 255
        )
        static let warning = Color(
            red: 198 / 255,
            green: 95 / 255,
            blue: 0
        )
        static let danger = Color(
            red: 200 / 255,
            green: 30 / 255,
            blue: 30 / 255
        )
        static let information = Color(
            red: 23 / 255,
            green: 104 / 255,
            blue: 202 / 255
        )
    }

    enum Semantic {
        static let backgroundPrimary = adaptive(
            light: .white,
            dark: UIColor(
                red: 10 / 255,
                green: 10 / 255,
                blue: 10 / 255,
                alpha: 1
            )
        )
        static let backgroundRaised = adaptive(
            light: UIColor(
                red: 245 / 255,
                green: 245 / 255,
                blue: 243 / 255,
                alpha: 1
            ),
            dark: UIColor(
                red: 23 / 255,
                green: 23 / 255,
                blue: 23 / 255,
                alpha: 1
            )
        )
        static let textPrimary = adaptive(
            light: .black,
            dark: UIColor(
                red: 245 / 255,
                green: 245 / 255,
                blue: 243 / 255,
                alpha: 1
            )
        )
        static let textSecondary = adaptive(
            light: UIColor(
                red: 102 / 255,
                green: 102 / 255,
                blue: 98 / 255,
                alpha: 1
            ),
            dark: UIColor(
                red: 166 / 255,
                green: 166 / 255,
                blue: 161 / 255,
                alpha: 1
            )
        )
        static let borderSubtle = adaptive(
            light: UIColor(
                red: 216 / 255,
                green: 216 / 255,
                blue: 212 / 255,
                alpha: 1
            ),
            dark: UIColor(
                red: 48 / 255,
                green: 48 / 255,
                blue: 48 / 255,
                alpha: 1
            )
        )
        static let actionPrimaryBackground = textPrimary
        static let actionPrimaryLabel = backgroundPrimary

        private static func adaptive(
            light: UIColor,
            dark: UIColor
        ) -> Color {
            Color(
                uiColor: UIColor { traits in
                    traits.userInterfaceStyle == .dark ? dark : light
                }
            )
        }
    }

    enum Space {
        static let x1: CGFloat = 4
        static let x2: CGFloat = 8
        static let x3: CGFloat = 12
        static let x4: CGFloat = 16
        static let x6: CGFloat = 24
        static let x8: CGFloat = 32
        static let x10: CGFloat = 40
        static let x12: CGFloat = 48
        static let x16: CGFloat = 64
        static let x20: CGFloat = 80
    }

    enum Radius {
        static let compact: CGFloat = 8
        static let `default`: CGFloat = 12
        static let feature: CGFloat = 16
        static let sheet: CGFloat = 24
    }

    enum Size {
        static let minimumTouchTarget: CGFloat = 44
        static let smallIcon: CGFloat = 16
        static let icon: CGFloat = 20
        static let largeIcon: CGFloat = 24
    }

    enum TypeStyle {
        static let largeTitle = Font.system(
            .largeTitle,
            design: .rounded,
            weight: .bold
        )
        static let title = Font.system(
            .title2,
            design: .rounded,
            weight: .semibold
        )
        static let headline = Font.system(
            .headline,
            design: .rounded,
            weight: .semibold
        )
        static let body = Font.system(.body, design: .rounded)
        static let subheadline = Font.system(
            .subheadline,
            design: .rounded
        )
        static let caption = Font.system(.caption, design: .rounded)
        static let eyebrow = Font.system(
            .caption,
            design: .rounded,
            weight: .bold
        )
        static let numeric = Font.system(
            .body,
            design: .monospaced
        )
        .monospacedDigit()
    }

    enum Motion {
        static let feedback = 0.15
        static let stateChange = 0.22
        static let transition = 0.34
        static let directManipulation = 0.42
    }
}

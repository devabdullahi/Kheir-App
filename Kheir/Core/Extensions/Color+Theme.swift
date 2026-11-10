import SwiftUI

// MARK: - Sacred Garden Design System

extension Color {
    /// Initializes a `Color` from a CSS-style hex string such as `"#RRGGBB"` or `"RRGGBB"`.
    init(hex: String) {
        let sanitized = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >>  8) & 0xFF) / 255
        let b = Double( value        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    // MARK: - Dark Mode Palette (night construction paper under a lamp)
    static let darkBackground = Color(red: 0.118, green: 0.141, blue: 0.259)    // #1E2442 — Indigo sheet
    static let darkCardSurface = Color(red: 0.169, green: 0.208, blue: 0.376)   // #2B3560 — Navy card
    static let darkCardElevated = Color(red: 0.227, green: 0.278, blue: 0.471)  // #3A4778 — Raised card
    static let islamicGold = Color(red: 0.890, green: 0.714, blue: 0.353)       // #E3B65A — Mustard paper
    static let darkPrimary = Color(red: 0.373, green: 0.604, blue: 0.431)       // #5F9A6E — Sage paper
    static let darkBodyText = Color(red: 0.953, green: 0.914, blue: 0.824)      // #F3E9D2 — Cream
    static let darkSecondaryTextColor = Color(red: 0.953, green: 0.914, blue: 0.824).opacity(0.6)

    // MARK: - Light Mode Palette (daylight kraft and cardstock)
    static let lightBackground = Color(red: 0.894, green: 0.812, blue: 0.671)   // #E4CFAB — Kraft-cream sheet
    static let lightCardSurface = Color(red: 0.984, green: 0.961, blue: 0.910)  // #FBF5E8 — Cream cardstock
    static let lightCardElevated = Color(red: 0.953, green: 0.910, blue: 0.824) // #F3E8D2 — Raised card
    static let lightPrimary = Color(red: 0.243, green: 0.451, blue: 0.314)      // #3E7350 — Leaf paper
    static let lightGoldAccent = Color(red: 0.788, green: 0.561, blue: 0.133)   // #C98F22 — Mustard paper
    static let lightBodyText = Color(red: 0.169, green: 0.129, blue: 0.094)     // #2B2118 — Warm ink
    static let lightSecondaryTextColor = Color(red: 0.431, green: 0.369, blue: 0.290) // #6E5E4A

    // MARK: - Paper Accents
    static let paperTerracotta = Color(red: 0.824, green: 0.412, blue: 0.294)   // #D2694B
    static let paperRose = Color(red: 0.902, green: 0.627, blue: 0.549)         // #E6A08C
    static let paperSky = Color(red: 0.494, green: 0.706, blue: 0.808)          // #7EB4CE
    static let paperKraft = Color(red: 0.722, green: 0.545, blue: 0.369)        // #B88B5E

    // MARK: - Semantic Colors
    static let destructive = Color(red: 0.863, green: 0.149, blue: 0.149)       // #DC2626

    // MARK: - Adaptive Colors
    static func adaptiveBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .darkBackground : .lightBackground
    }

    static func adaptiveCardSurface(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .darkCardSurface : .lightCardSurface
    }

    static func adaptiveCardElevated(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .darkCardElevated : .lightCardElevated
    }

    static func adaptivePrimary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .darkPrimary : .lightPrimary
    }

    static func adaptiveGold(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .islamicGold : .lightGoldAccent
    }

    static func adaptiveText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .darkBodyText : .lightBodyText
    }

    static func adaptiveSecondaryText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .darkSecondaryTextColor : .lightSecondaryTextColor
    }

    static func adaptiveBorder(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .darkPrimary.opacity(0.2) : .lightPrimary.opacity(0.1)
    }

    static func adaptiveGoldBorder(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .islamicGold.opacity(0.15) : .lightGoldAccent.opacity(0.15)
    }
}

// MARK: - Design Tokens

enum DesignTokens {
    // MARK: Spacing (8pt grid)
    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 12
    static let spacingLG: CGFloat = 16
    static let spacingXL: CGFloat = 20
    static let spacingXXL: CGFloat = 24
    static let spacingSection: CGFloat = 32

    // MARK: Corner Radius
    static let radiusSM: CGFloat = 12
    static let radiusMD: CGFloat = 16
    static let radiusLG: CGFloat = 20
    static let radiusXL: CGFloat = 24
    static let radiusPill: CGFloat = 28

    // MARK: Card
    static let cardPadding: CGFloat = 20
    static let cardGap: CGFloat = 12
    static let cardRadius: CGFloat = 20
    static let cardBlur: CGFloat = 16
    static let cardShadowRadius: CGFloat = 8
    static let cardShadowY: CGFloat = 4

    // MARK: Animation
    static let springResponse: Double = 0.3
    static let springDamping: Double = 0.7
    static let springResponseSlow: Double = 0.5
    static let springDampingSlow: Double = 0.82
    static let microDuration: Double = 0.15
    static let shortDuration: Double = 0.25
    static let mediumDuration: Double = 0.35
    static let staggerDelay: Double = 0.03

    // MARK: Press Scale
    static let pressScaleCard: CGFloat = 0.97
    static let pressScaleButton: CGFloat = 0.96
    static let pressScaleTab: CGFloat = 0.9
    static let pressOpacity: Double = 0.7

    // MARK: Sky
    static let skyHeaderHeight: CGFloat = 220
    static let skyHeaderCollapsed: CGFloat = 100
    static let skyUpdateInterval: TimeInterval = 30
}

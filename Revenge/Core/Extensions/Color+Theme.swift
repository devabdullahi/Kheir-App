import SwiftUI

// MARK: - Sacred Garden Design System

extension Color {
    // MARK: - Dark Mode Palette (Primary)
    static let darkBackground = Color(red: 0.039, green: 0.059, blue: 0.118)    // #0A0F1E — Deep navy
    static let darkCardSurface = Color(red: 0.051, green: 0.122, blue: 0.102)   // #0D1F1A — Emerald surface
    static let darkCardElevated = Color(red: 0.086, green: 0.239, blue: 0.180)  // #163D2E — Elevated card
    static let islamicGold = Color(red: 0.831, green: 0.659, blue: 0.278)       // #D4A847 — Gold accent
    static let darkPrimary = Color(red: 0.133, green: 0.341, blue: 0.235)       // #22573C — Primary green
    static let darkBodyText = Color(red: 0.910, green: 0.863, blue: 0.784)      // #E8DCC8 — Warm cream
    static let darkSecondaryTextColor = Color(red: 0.910, green: 0.863, blue: 0.784).opacity(0.5)

    // MARK: - Light Mode Palette
    static let lightBackground = Color(red: 0.961, green: 0.941, blue: 0.910)   // #F5F0E8 — Warm parchment
    static let lightCardSurface = Color.white                                     // #FFFFFF
    static let lightCardElevated = Color(red: 0.973, green: 0.961, blue: 0.937) // #F8F5EF
    static let lightPrimary = Color(red: 0.102, green: 0.420, blue: 0.259)      // #1A6B42 — Forest green
    static let lightGoldAccent = Color(red: 0.722, green: 0.573, blue: 0.180)   // #B8922E — Light gold
    static let lightBodyText = Color(red: 0.102, green: 0.165, blue: 0.133)     // #1A2A22 — Dark green-black
    static let lightSecondaryTextColor = Color(red: 0.353, green: 0.420, blue: 0.384) // #5A6B62

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

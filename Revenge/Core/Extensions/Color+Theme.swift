import SwiftUI

extension Color {
    // MARK: - Dark Mode Palette
    static let darkBackground = Color(red: 0.08, green: 0.09, blue: 0.18)       // Deep navy
    static let darkCardSurface = Color(red: 0.08, green: 0.16, blue: 0.14)      // Deep forest green
    static let islamicGold = Color(red: 0.85, green: 0.68, blue: 0.32)          // Warm gold accent
    static let darkBodyText = Color(red: 0.93, green: 0.93, blue: 0.90)         // Off-white

    // MARK: - Light Mode Palette
    static let lightBackground = Color(red: 0.97, green: 0.95, blue: 0.90)      // Warm parchment
    static let lightPrimary = Color(red: 0.13, green: 0.37, blue: 0.27)         // Forest green
    static let lightBodyText = Color(red: 0.08, green: 0.09, blue: 0.18)        // Deep navy

    // MARK: - Adaptive Colors
    static func adaptiveBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .darkBackground : .lightBackground
    }

    static func adaptiveCardSurface(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .darkCardSurface : .white
    }

    static func adaptivePrimary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .islamicGold : .lightPrimary
    }

    static func adaptiveText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .darkBodyText : .lightBodyText
    }

    static func adaptiveSecondaryText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .darkBodyText.opacity(0.7) : .lightBodyText.opacity(0.6)
    }
}

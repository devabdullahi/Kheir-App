import SwiftUI
import UIKit

// MARK: - SkyState

/// Immutable snapshot of all visual properties needed to render the dynamic sky.
/// Create instances via the static presets and compose them with `interpolate(from:to:progress:)`.
struct SkyState {

    // MARK: Background

    /// 3–5 gradient color stops, applied top-to-bottom.
    let gradientColors: [Color]

    // MARK: Sun

    /// Normalized position within the canvas (x: 0=left, 1=right; y: 0=top, 1=bottom).
    let sunPosition: CGPoint
    let sunSize: CGFloat
    let sunGlowRadius: CGFloat
    let sunGlowColor: Color
    /// 0.0 = fully hidden, 1.0 = fully visible.
    let sunOpacity: Double

    // MARK: Moon

    /// Normalized position, same coordinate space as `sunPosition`.
    let moonPosition: CGPoint
    /// 0.0 = hidden, 1.0 = fully visible.
    let moonOpacity: Double

    // MARK: Stars

    /// Global opacity applied to all star circles. 0.0 = none, 1.0 = fully bright.
    let starOpacity: Double

    // MARK: Color Temperature

    /// 0.0 = cool (blue-white), 1.0 = warm (amber-orange). Used by renderers for tinting.
    let colorTemperature: Double
}

// MARK: - Static Presets

extension SkyState {

    /// Pre-dawn state: deep indigo sky with a barely-risen, warm amber sun near the horizon.
    static let fajr = SkyState(
        gradientColors: [
            Color(hex: "#0B1420"),
            Color(hex: "#1A2744"),
            Color(hex: "#3A5A7A"),
            Color(hex: "#D4926B"),
            Color(hex: "#E8B87A")
        ],
        sunPosition: CGPoint(x: 0.5, y: 0.85),
        sunSize: 22,
        sunGlowRadius: 36,
        sunGlowColor: Color(hex: "#E8B87A").opacity(0.55),
        sunOpacity: 0.85,
        moonPosition: CGPoint(x: 0.25, y: 0.2),
        moonOpacity: 0.25,
        starOpacity: 0.15,
        colorTemperature: 0.65
    )

    /// Sunrise state: soft blue-to-gold transition as the sun lifts off the horizon.
    static let sunrise = SkyState(
        gradientColors: [
            Color(hex: "#4A7FA5"),
            Color(hex: "#7AB5D4"),
            Color(hex: "#C4D8E0"),
            Color(hex: "#F5D5A0"),
            Color(hex: "#F0C070")
        ],
        sunPosition: CGPoint(x: 0.5, y: 0.65),
        sunSize: 32,
        sunGlowRadius: 56,
        sunGlowColor: Color(hex: "#F5D5A0").opacity(0.6),
        sunOpacity: 0.95,
        moonPosition: CGPoint(x: 0.2, y: 0.25),
        moonOpacity: 0.0,
        starOpacity: 0.0,
        colorTemperature: 0.78
    )

    /// Midday state: blazing white-hot sun at zenith against a vivid cyan sky.
    static let dhuhr = SkyState(
        gradientColors: [
            Color(hex: "#1976A8"),
            Color(hex: "#2E98C4"),
            Color(hex: "#5AB8D4"),
            Color(hex: "#8AD0E0"),
            Color(hex: "#B0E0EC")
        ],
        sunPosition: CGPoint(x: 0.5, y: 0.12),
        sunSize: 46,
        sunGlowRadius: 80,
        sunGlowColor: Color.white.opacity(0.45),
        sunOpacity: 1.0,
        moonPosition: CGPoint(x: 0.75, y: 0.15),
        moonOpacity: 0.0,
        starOpacity: 0.0,
        colorTemperature: 0.15
    )

    /// Afternoon state: warm golden-blue sky, sun past its peak and drifting southeast.
    static let asr = SkyState(
        gradientColors: [
            Color(hex: "#3A7A9A"),
            Color(hex: "#5A9AB4"),
            Color(hex: "#8ABAC4"),
            Color(hex: "#C4B88A"),
            Color(hex: "#D4A86B")
        ],
        sunPosition: CGPoint(x: 0.65, y: 0.35),
        sunSize: 38,
        sunGlowRadius: 62,
        sunGlowColor: Color(hex: "#D4A86B").opacity(0.5),
        sunOpacity: 1.0,
        moonPosition: CGPoint(x: 0.75, y: 0.15),
        moonOpacity: 0.0,
        starOpacity: 0.0,
        colorTemperature: 0.72
    )

    /// Sunset state: deep magenta-orange sky, sun on the western horizon and fading.
    static let maghrib = SkyState(
        gradientColors: [
            Color(hex: "#2A1A3A"),
            Color(hex: "#8B2E1A"),
            Color(hex: "#D4694A"),
            Color(hex: "#E8A87A"),
            Color(hex: "#F0C88A")
        ],
        sunPosition: CGPoint(x: 0.5, y: 0.82),
        sunSize: 30,
        sunGlowRadius: 64,
        sunGlowColor: Color(hex: "#D4694A").opacity(0.65),
        sunOpacity: 0.75,
        moonPosition: CGPoint(x: 0.7, y: 0.18),
        moonOpacity: 0.20,
        starOpacity: 0.05,
        colorTemperature: 0.88
    )

    /// Night state: deep navy sky, sun hidden, crescent moon and stars fully visible.
    static let isha = SkyState(
        gradientColors: [
            Color(hex: "#050A14"),
            Color(hex: "#0A1020"),
            Color(hex: "#0D1A2A"),
            Color(hex: "#1A2744")
        ],
        sunPosition: CGPoint(x: 0.5, y: 1.3),  // off-canvas — effectively hidden
        sunSize: 20,
        sunGlowRadius: 20,
        sunGlowColor: Color.clear,
        sunOpacity: 0.0,
        moonPosition: CGPoint(x: 0.75, y: 0.15),
        moonOpacity: 1.0,
        starOpacity: 1.0,
        colorTemperature: 0.0
    )
}

// MARK: - Interpolation

extension SkyState {

    /// Returns a new `SkyState` linearly interpolated between `from` and `to` by `progress` (0–1).
    ///
    /// Color stops are interpolated per-component in the sRGB color space.
    /// If the two states have different numbers of gradient stops, the shorter list is
    /// extended by repeating its last color so lengths always match.
    static func interpolate(from: SkyState, to: SkyState, progress: Double) -> SkyState {
        let t = max(0, min(1, progress))

        return SkyState(
            gradientColors: interpolateColors(from: from.gradientColors, to: to.gradientColors, t: t),
            sunPosition: interpolatePoint(from.sunPosition, to.sunPosition, t: t),
            sunSize: lerp(from.sunSize, to.sunSize, t: t),
            sunGlowRadius: lerp(from.sunGlowRadius, to.sunGlowRadius, t: t),
            sunGlowColor: interpolateColor(from.sunGlowColor, to.sunGlowColor, t: t),
            sunOpacity: lerp(from.sunOpacity, to.sunOpacity, t: t),
            moonPosition: interpolatePoint(from.moonPosition, to.moonPosition, t: t),
            moonOpacity: lerp(from.moonOpacity, to.moonOpacity, t: t),
            starOpacity: lerp(from.starOpacity, to.starOpacity, t: t),
            colorTemperature: lerp(from.colorTemperature, to.colorTemperature, t: t)
        )
    }

    // MARK: Private Helpers

    private static func lerp(_ a: Double, _ b: Double, t: Double) -> Double {
        a + (b - a) * t
    }

    private static func lerp(_ a: CGFloat, _ b: CGFloat, t: Double) -> CGFloat {
        a + (b - a) * CGFloat(t)
    }

    private static func interpolatePoint(_ a: CGPoint, _ b: CGPoint, t: Double) -> CGPoint {
        CGPoint(
            x: lerp(a.x, b.x, t: t),
            y: lerp(a.y, b.y, t: t)
        )
    }

    private static func interpolateColor(_ a: Color, _ b: Color, t: Double) -> Color {
        let rA = a.components
        let rB = b.components
        return Color(
            red:     lerp(rA.red,   rB.red,   t: t),
            green:   lerp(rA.green, rB.green, t: t),
            blue:    lerp(rA.blue,  rB.blue,  t: t),
            opacity: lerp(rA.alpha, rB.alpha, t: t)
        )
    }

    private static func interpolateColors(from: [Color], to: [Color], t: Double) -> [Color] {
        let maxCount = max(from.count, to.count)
        let paddedFrom = from.padded(to: maxCount)
        let paddedTo   = to.padded(to: maxCount)
        return zip(paddedFrom, paddedTo).map { interpolateColor($0, $1, t: t) }
    }
}

// MARK: - Color Helpers

private extension Array where Element == Color {
    /// Returns a copy extended to `count` elements by repeating the last element.
    func padded(to count: Int) -> [Color] {
        guard count > self.count, let last else { return self }
        return self + Array(repeating: last, count: count - self.count)
    }
}

private extension Color {
    /// RGBA components resolved in the sRGB color space.
    var components: (red: Double, green: Double, blue: Double, alpha: Double) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b), Double(a))
    }
}

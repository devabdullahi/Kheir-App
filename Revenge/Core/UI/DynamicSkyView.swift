import SwiftUI

// MARK: - DynamicSkyView

/// A GPU-accelerated sky backdrop that renders gradient, sun, moon, and stars
/// from a `SkyState` snapshot. This view is purely presentational — it owns no
/// engine and no timers; callers are responsible for feeding it updated state.
///
/// ```swift
/// DynamicSkyView(skyState: engine.currentState)
///     .frame(height: DesignTokens.skyHeaderHeight)
/// ```
struct DynamicSkyView: View {

    let skyState: SkyState

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Star seed positions generated once so they remain stable across redraws.
    private let starSeeds: [StarSeed] = Self.makeStarSeeds(count: 7)

    var body: some View {
        Canvas { context, size in
            drawBackground(context: context, size: size)
            drawSun(context: context, size: size)
            drawMoon(context: context, size: size)
            drawStars(context: context, size: size)
        }
        // Each time the engine publishes a new SkyState (every 30 s), SwiftUI will
        // cross-dissolve the rasterised canvas layer over 2 seconds.  When the user
        // has reduced motion enabled we snap instantly instead.
        .animation(reduceMotion ? .none : .easeInOut(duration: 2.0), value: skyState.sunPosition.y)
        .animation(reduceMotion ? .none : .easeInOut(duration: 2.0), value: skyState.sunOpacity)
        .animation(reduceMotion ? .none : .easeInOut(duration: 2.0), value: skyState.moonOpacity)
        .animation(reduceMotion ? .none : .easeInOut(duration: 2.0), value: skyState.starOpacity)
        .drawingGroup()         // rasterise the whole layer on the GPU
        .clipped()
        .accessibilityHidden(true)  // purely decorative — screen readers skip this
    }

    // MARK: - Background Gradient

    private func drawBackground(context: GraphicsContext, size: CGSize) {
        let stops = skyState.gradientColors.enumerated().map { index, color in
            Gradient.Stop(
                color: color,
                location: CGFloat(index) / CGFloat(max(skyState.gradientColors.count - 1, 1))
            )
        }
        let gradient = Gradient(stops: stops)
        let rect = CGRect(origin: .zero, size: size)

        context.fill(
            Path(rect),
            with: .linearGradient(
                gradient,
                startPoint: CGPoint(x: size.width / 2, y: 0),
                endPoint:   CGPoint(x: size.width / 2, y: size.height)
            )
        )
    }

    // MARK: - Sun

    private func drawSun(context: GraphicsContext, size: CGSize) {
        guard skyState.sunOpacity > 0.01 else { return }

        let center = CGPoint(
            x: skyState.sunPosition.x * size.width,
            y: skyState.sunPosition.y * size.height
        )

        var ctx = context
        ctx.opacity = skyState.sunOpacity

        // Outer glow — large, soft, colour-tinted radial gradient.
        let glowRadius = skyState.sunGlowRadius
        let glowRect   = CGRect(
            x: center.x - glowRadius,
            y: center.y - glowRadius,
            width:  glowRadius * 2,
            height: glowRadius * 2
        )
        let glowGradient = Gradient(colors: [
            skyState.sunGlowColor,
            skyState.sunGlowColor.opacity(0)
        ])
        ctx.fill(
            Path(ellipseIn: glowRect),
            with: .radialGradient(
                glowGradient,
                center: center,
                startRadius: 0,
                endRadius: glowRadius
            )
        )

        // Core disc — white-hot centre fading to the glow colour.
        let coreRadius = skyState.sunSize / 2
        let coreRect   = CGRect(
            x: center.x - coreRadius,
            y: center.y - coreRadius,
            width:  coreRadius * 2,
            height: coreRadius * 2
        )
        let coreGradient = Gradient(colors: [Color.white, skyState.sunGlowColor])
        ctx.fill(
            Path(ellipseIn: coreRect),
            with: .radialGradient(
                coreGradient,
                center: center,
                startRadius: 0,
                endRadius: coreRadius
            )
        )
    }

    // MARK: - Moon

    private func drawMoon(context: GraphicsContext, size: CGSize) {
        guard skyState.moonOpacity > 0.01 else { return }

        let center = CGPoint(
            x: skyState.moonPosition.x * size.width,
            y: skyState.moonPosition.y * size.height
        )
        let radius: CGFloat = 14

        var ctx = context
        ctx.opacity = skyState.moonOpacity

        // Silver glow halo.
        let haloRadius: CGFloat = radius * 2.2
        let haloRect = CGRect(
            x: center.x - haloRadius,
            y: center.y - haloRadius,
            width:  haloRadius * 2,
            height: haloRadius * 2
        )
        ctx.fill(
            Path(ellipseIn: haloRect),
            with: .radialGradient(
                Gradient(colors: [
                    Color(white: 0.85, opacity: 0.25),
                    Color(white: 0.85, opacity: 0)
                ]),
                center: center,
                startRadius: 0,
                endRadius: haloRadius
            )
        )

        // Crescent: full disc minus an offset cutout.
        let discRect = CGRect(
            x: center.x - radius, y: center.y - radius,
            width: radius * 2, height: radius * 2
        )
        let cutOffset: CGFloat = radius * 0.42
        let cutRect = CGRect(
            x: center.x - radius + cutOffset, y: center.y - radius,
            width: radius * 2, height: radius * 2
        )

        // Fill the full disc in silver, then punch out the shadow area.
        ctx.fill(
            Path(ellipseIn: discRect),
            with: .color(Color(white: 0.92))
        )

        // Punch out the crescent shadow using blend mode.
        var cutCtx = ctx
        cutCtx.blendMode = .destinationOut
        cutCtx.fill(
            Path(ellipseIn: cutRect),
            with: .color(Color(white: 1.0))
        )
    }

    // MARK: - Stars

    private func drawStars(context: GraphicsContext, size: CGSize) {
        guard skyState.starOpacity > 0.01 else { return }

        var ctx = context
        ctx.opacity = skyState.starOpacity

        for seed in starSeeds {
            let center = CGPoint(x: seed.normalizedX * size.width,
                                 y: seed.normalizedY * size.height)
            let r = seed.radius
            let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
            ctx.fill(
                Path(ellipseIn: rect),
                with: .color(Color(white: 0.95, opacity: seed.brightness))
            )
        }
    }

    // MARK: - Star Seed Generation

    private struct StarSeed {
        let normalizedX: CGFloat
        let normalizedY: CGFloat
        let radius: CGFloat
        let brightness: Double
    }

    /// Generates a stable, deterministic set of star positions using a seeded LCG.
    private static func makeStarSeeds(count: Int) -> [StarSeed] {
        // LCG parameters (Numerical Recipes)
        var state: UInt64 = 0xDEAD_BEEF_1234_5678
        func next() -> Double {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(state >> 33) / Double(UInt32.max)
        }

        return (0..<count).map { _ in
            StarSeed(
                normalizedX: CGFloat(next()),
                normalizedY: CGFloat(next() * 0.55),   // confine stars to upper 55% of canvas
                radius:      CGFloat(next() * 1.5 + 0.8),
                brightness:  next() * 0.5 + 0.5
            )
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Fajr") {
    DynamicSkyView(skyState: .fajr)
        .frame(height: DesignTokens.skyHeaderHeight)
}

#Preview("Dhuhr") {
    DynamicSkyView(skyState: .dhuhr)
        .frame(height: DesignTokens.skyHeaderHeight)
}

#Preview("Maghrib") {
    DynamicSkyView(skyState: .maghrib)
        .frame(height: DesignTokens.skyHeaderHeight)
}

#Preview("Isha") {
    DynamicSkyView(skyState: .isha)
        .frame(height: DesignTokens.skyHeaderHeight)
}

#Preview("Interpolated — Fajr → Sunrise 50%") {
    DynamicSkyView(
        skyState: SkyState.interpolate(from: .fajr, to: .sunrise, progress: 0.5)
    )
    .frame(height: DesignTokens.skyHeaderHeight)
}
#endif

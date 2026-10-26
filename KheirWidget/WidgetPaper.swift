import SwiftUI
import WidgetKit

// MARK: - Widget Paper Kit
//
// A small, self-contained copy of the app's paper cut-out look for the widget
// extension. The extension only compiles files inside `KheirWidget/`, so instead
// of sharing `PaperKit.swift` (which pulls in `Motion.swift`, `DesignTokens`, …)
// this file re-creates the pieces widgets need: palette, seeded noise, cut and
// torn shapes, a paper piece modifier, a torn tag and a handful of static paper
// icons. Everything is static: widgets and Live Activities cannot animate.

// MARK: Palette (mirrors Color+Theme.swift)

enum WPalette {
    static func hex(_ value: UInt32, _ alpha: Double = 1) -> Color {
        Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255,
            opacity: alpha
        )
    }

    // Light: kraft table, cream cardstock, warm ink
    static let kraftSheet = hex(0xE9D9BC)
    static let cream = hex(0xFBF5E8)
    static let raisedLight = hex(0xF3E8D2)
    static let ink = hex(0x2B2118)
    static let ink2 = hex(0x6E5E4A)
    static let leaf = hex(0x3E7350)
    static let mustardDeep = hex(0xC98F22)

    // Dark: indigo construction paper
    static let indigo = hex(0x1E2442)
    static let navy = hex(0x2B3560)
    static let raisedDark = hex(0x3A4778)
    static let creamInk = hex(0xF3E9D2)

    // Shared accents
    static let mustard = hex(0xE3B65A)
    static let terracotta = hex(0xD2694B)
    static let sage = hex(0x5F9A6E)
    static let kraft = hex(0xB88B5E)
    static let moon = hex(0xF6EBC8)

    static func sheet(_ dark: Bool) -> Color { dark ? indigo : kraftSheet }
    static func card(_ dark: Bool) -> Color { dark ? navy : cream }
    static func raised(_ dark: Bool) -> Color { dark ? raisedDark : raisedLight }
    static func text(_ dark: Bool) -> Color { dark ? creamInk : ink }
    static func text2(_ dark: Bool) -> Color { dark ? creamInk.opacity(0.62) : ink2 }
    static func gold(_ dark: Bool) -> Color { dark ? mustard : mustardDeep }
}

// MARK: Noise

/// Stable pseudo-random value in 0..<1 (same recipe as the app's `seeded`).
func wSeeded(_ i: Int, salt: Double = 0) -> Double {
    let x = sin(Double(i) * 12.9898 + salt * 78.233) * 43758.5453
    return x - floor(x)
}

// MARK: Cut shape

enum WEdge { case scissor, torn }

/// A rounded rectangle cut by hand: the outline wobbles (scissor) or rags (torn).
struct WCutShape: Shape {
    var cornerRadius: CGFloat = 18
    var edge: WEdge = .scissor
    var seed: Int = 0

    func path(in rect: CGRect) -> Path {
        let r = min(cornerRadius, min(rect.width, rect.height) / 2)
        let spacing: CGFloat = edge == .torn ? 3 : 6
        var samples: [(p: CGPoint, n: CGVector, s: CGFloat)] = []
        var s: CGFloat = 0

        func line(_ a: CGPoint, _ b: CGPoint, _ n: CGVector) {
            let len = hypot(b.x - a.x, b.y - a.y)
            let steps = max(1, Int(len / spacing))
            for k in 0..<steps {
                let f = CGFloat(k) / CGFloat(steps)
                samples.append((CGPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f), n, s + len * f))
            }
            s += len
        }
        func arc(_ c: CGPoint, from a0: CGFloat) {
            guard r > 0 else { return }
            let len = r * .pi / 2
            let steps = max(2, Int(len / spacing))
            for k in 0..<steps {
                let a = a0 + (.pi / 2) * CGFloat(k) / CGFloat(steps)
                let n = CGVector(dx: cos(a), dy: sin(a))
                samples.append((CGPoint(x: c.x + n.dx * r, y: c.y + n.dy * r), n, s + len * CGFloat(k) / CGFloat(steps)))
            }
            s += len
        }

        let (x0, y0, x1, y1) = (rect.minX, rect.minY, rect.maxX, rect.maxY)
        line(CGPoint(x: x0 + r, y: y0), CGPoint(x: x1 - r, y: y0), CGVector(dx: 0, dy: -1))
        arc(CGPoint(x: x1 - r, y: y0 + r), from: -.pi / 2)
        line(CGPoint(x: x1, y: y0 + r), CGPoint(x: x1, y: y1 - r), CGVector(dx: 1, dy: 0))
        arc(CGPoint(x: x1 - r, y: y1 - r), from: 0)
        line(CGPoint(x: x1 - r, y: y1), CGPoint(x: x0 + r, y: y1), CGVector(dx: 0, dy: 1))
        arc(CGPoint(x: x0 + r, y: y1 - r), from: .pi / 2)
        line(CGPoint(x: x0, y: y1 - r), CGPoint(x: x0, y: y0 + r), CGVector(dx: -1, dy: 0))
        arc(CGPoint(x: x0 + r, y: y0 + r), from: .pi)

        var path = Path()
        let phaseA = wSeeded(seed, salt: 1) * 6.28
        let phaseB = wSeeded(seed, salt: 2) * 6.28
        for (i, sample) in samples.enumerated() {
            let x = Double(sample.s)
            let slow = 0.55 * sin(x / 37 + phaseA) + 0.35 * sin(x / 13 + phaseB)
            let d: Double
            switch edge {
            case .scissor:
                d = slow * 0.9
            case .torn:
                let fine = (wSeeded(i, salt: Double(seed) * 0.37 + 3) - 0.5) * 2.2
                let coarse = (wSeeded(i / 3, salt: Double(seed) * 0.37 + 4) - 0.5) * 1.6
                d = slow * 1.4 + fine + coarse - 0.8
            }
            let p = CGPoint(x: sample.p.x + sample.n.dx * d, y: sample.p.y + sample.n.dy * d)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        return path
    }
}

/// A horizontal strip whose top and bottom edges are torn. Used for progress strips.
struct WTornStrip: Shape {
    var seed: Int = 0

    func path(in rect: CGRect) -> Path {
        let step: CGFloat = 4
        let amp = min(rect.height * 0.22, 2.2)
        let n = max(2, Int(rect.width / step))
        var path = Path()
        for k in 0...n {
            let x = rect.minX + rect.width * CGFloat(k) / CGFloat(n)
            let y = rect.minY + amp * CGFloat(wSeeded(k, salt: Double(seed) + 0.3))
            if k == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        for k in stride(from: n, through: 0, by: -1) {
            let x = rect.minX + rect.width * CGFloat(k) / CGFloat(n)
            let y = rect.maxY - amp * CGFloat(wSeeded(k, salt: Double(seed) + 0.7))
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.closeSubpath()
        return path
    }
}

/// A torn landscape layer: everything below a ragged, rolling line.
struct WTornHill: Shape {
    var baseline: CGFloat   // 0…1 of height
    var amplitude: CGFloat = 6
    var seed: Int = 0

    func path(in rect: CGRect) -> Path {
        let step: CGFloat = 4
        let n = max(2, Int(rect.width / step))
        let phaseA = wSeeded(seed, salt: 5) * 6.28
        let phaseB = wSeeded(seed, salt: 6) * 6.28
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        for k in 0...n {
            let x = rect.minX + rect.width * CGFloat(k) / CGFloat(n)
            let xd = Double(x)
            let roll = sin(xd / 61 + phaseA) * 0.6 + sin(xd / 23 + phaseB) * 0.4
            let rag = (wSeeded(k, salt: Double(seed) + 7) - 0.5) * 1.6
            let y = rect.minY + rect.height * baseline + CGFloat(roll) * amplitude + CGFloat(rag)
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: Rendering mode

extension WidgetRenderingMode {
    /// Accented (tinted) and vibrant (lock screen / clear) modes reduce every
    /// colour to one tone, so paper pieces become translucent sheets instead.
    var isMonochrome: Bool { self != .fullColor }
}

// MARK: Paper piece

struct WPaperPiece: ViewModifier {
    let color: Color
    var depth: CGFloat = 1
    var edge: WEdge = .scissor
    var radius: CGFloat = 14
    var seed: Int = 0
    @Environment(\.colorScheme) private var scheme
    @Environment(\.widgetRenderingMode) private var mode

    func body(content: Content) -> some View {
        let shape = WCutShape(cornerRadius: radius, edge: edge, seed: seed)
        content.background {
            if mode.isMonochrome {
                // One tone: keep the cut silhouette, drop colour and grain.
                shape.fill(Color.white.opacity(depth > 1.2 ? 0.28 : 0.14))
                    .overlay(shape.stroke(Color.white.opacity(0.35), lineWidth: 0.6))
            } else {
                ZStack {
                    shape.fill(color)
                    shape.stroke(
                        LinearGradient(
                            colors: [.white.opacity(scheme == .dark ? 0.16 : 0.55), .clear, .black.opacity(0.10)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                }
                .wPaperShadow(depth: depth)
            }
        }
    }
}

extension View {
    func wPaper(_ color: Color, depth: CGFloat = 1, edge: WEdge = .scissor, radius: CGFloat = 14, seed: Int = 0) -> some View {
        modifier(WPaperPiece(color: color, depth: depth, edge: edge, radius: radius, seed: seed))
    }

    /// Contact shadow plus a soft cast shadow, lamp at top-left.
    func wPaperShadow(depth: CGFloat = 1) -> some View {
        self
            .shadow(color: Color(red: 0.12, green: 0.07, blue: 0.02).opacity(0.24), radius: 0.6 + 0.4 * depth, x: 0.4 * depth, y: 0.8 * depth)
            .shadow(color: Color(red: 0.18, green: 0.10, blue: 0.03).opacity(0.16), radius: 2 + 2 * depth, x: 1.2 * depth, y: 2.4 * depth)
    }
}

// MARK: Sheet background

/// The widget's own sheet of cardstock, with a few paper fibres.
struct WPaperSheet: View {
    var color: Color? = nil
    var seed: Int = 0
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let dark = scheme == .dark
        ZStack {
            (color ?? WPalette.card(dark))
            Canvas { ctx, size in
                let ink = dark ? Color.white : Color(red: 0.25, green: 0.17, blue: 0.08)
                let count = Int(size.width * size.height / 900) + 10
                for i in 0..<count {
                    let x = wSeeded(i, salt: Double(seed)) * size.width
                    let y = wSeeded(i, salt: Double(seed) + 0.5) * size.height
                    let a = wSeeded(i, salt: Double(seed) + 1.3) * .pi * 2
                    let len = 2 + wSeeded(i, salt: Double(seed) + 1.7) * 4
                    var p = Path()
                    p.move(to: CGPoint(x: x, y: y))
                    p.addLine(to: CGPoint(x: x + cos(a) * len, y: y + sin(a) * len))
                    ctx.stroke(p, with: .color(ink), lineWidth: 0.5)
                }
            }
            .opacity(dark ? 0.07 : 0.06)
            // Lamp from the top-left.
            LinearGradient(
                colors: [.white.opacity(dark ? 0.06 : 0.22), .clear, .black.opacity(dark ? 0.14 : 0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: Tag

/// A small torn label, like a hand-cut price tag.
struct WPaperTag: View {
    let text: String
    var seed: Int = 0
    var color: Color = WPalette.mustard
    @Environment(\.widgetRenderingMode) private var mode

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .heavy, design: .rounded))
            .tracking(1)
            .textCase(.uppercase)
            .lineLimit(1)
            .foregroundStyle(mode.isMonochrome ? Color.white : WPalette.ink)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .wPaper(color, depth: 0.6, edge: .torn, radius: 3, seed: seed)
            .rotationEffect(.degrees((wSeeded(seed, salt: 9) - 0.5) * 4))
            .widgetAccentable()
    }
}

// MARK: Icons

/// Static paper icons drawn from flat cut shapes.
enum WIcon: String, Codable, Hashable, Sendable {
    case fajr, sunrise, dhuhr, asr, maghrib, isha, sun, moon, book, clock, compass

    init(prayer name: String) {
        switch name.lowercased() {
        case "fajr": self = .fajr
        case "sunrise", "shuruq": self = .sunrise
        case "dhuhr", "zuhr", "jumuah": self = .dhuhr
        case "asr": self = .asr
        case "maghrib": self = .maghrib
        default: self = .isha
        }
    }
}

struct WPaperIcon: View {
    let icon: WIcon
    var size: CGFloat = 22
    @Environment(\.widgetRenderingMode) private var mode

    init(_ icon: WIcon, size: CGFloat = 22) {
        self.icon = icon
        self.size = size
    }

    var body: some View {
        ZStack { art }
            .frame(width: size, height: size)
            .compositingGroup()
            .shadow(color: .black.opacity(mode.isMonochrome ? 0 : 0.30), radius: 0.6, x: 0.5, y: 1)
            .accessibilityHidden(true)
    }

    private func c(_ color: Color) -> Color { mode.isMonochrome ? .white : color }

    @ViewBuilder private var art: some View {
        let s = size
        switch icon {
        case .sun, .dhuhr:
            sunRays(count: 8, length: s * 0.16, radius: s * 0.38, color: c(WPalette.mustard))
            Circle().fill(c(WPalette.mustard)).frame(width: s * 0.54, height: s * 0.54)
            Circle().fill(c(WPalette.hex(0xF2CF7E))).frame(width: s * 0.30, height: s * 0.30)
                .offset(x: -s * 0.06, y: -s * 0.06)
        case .asr:
            sunRays(count: 6, length: s * 0.12, radius: s * 0.34, color: c(WPalette.hex(0xE09A4A)))
                .offset(y: -s * 0.06)
            Circle().fill(c(WPalette.hex(0xE09A4A))).frame(width: s * 0.48, height: s * 0.48)
                .offset(y: -s * 0.06)
            WTornHill(baseline: 0.72, amplitude: s * 0.03, seed: 3).fill(c(WPalette.sage))
        case .fajr, .sunrise:
            sunRays(count: 7, length: s * 0.12, radius: s * 0.34, color: c(WPalette.hex(0xF0C070)))
                .offset(y: s * 0.12)
                .mask(Rectangle().frame(height: s * 0.62).offset(y: -s * 0.19))
            Circle().fill(c(icon == .fajr ? WPalette.hex(0xE8A87A) : WPalette.mustard))
                .frame(width: s * 0.5, height: s * 0.5)
                .offset(y: s * 0.12)
            WTornHill(baseline: 0.64, amplitude: s * 0.025, seed: 5).fill(c(WPalette.hex(0x3A5A7A)))
        case .maghrib:
            Circle().fill(c(WPalette.terracotta)).frame(width: s * 0.58, height: s * 0.58)
                .offset(y: s * 0.10)
            WTornHill(baseline: 0.62, amplitude: s * 0.03, seed: 8).fill(c(WPalette.hex(0x8B2E1A)))
            WTornHill(baseline: 0.80, amplitude: s * 0.025, seed: 9).fill(c(WPalette.hex(0x2A1A3A)))
        case .isha, .moon:
            Crescent().fill(c(WPalette.moon)).frame(width: s * 0.72, height: s * 0.72)
                .offset(x: -s * 0.06)
            Star5().fill(c(WPalette.mustard)).frame(width: s * 0.28, height: s * 0.28)
                .offset(x: s * 0.28, y: -s * 0.26)
        case .book:
            RoundedRectangle(cornerRadius: s * 0.06).fill(c(WPalette.leaf))
                .frame(width: s * 0.78, height: s * 0.66)
            RoundedRectangle(cornerRadius: s * 0.04).fill(c(WPalette.cream))
                .frame(width: s * 0.62, height: s * 0.52)
                .offset(y: -s * 0.02)
            Rectangle().fill(c(WPalette.kraft)).frame(width: s * 0.04, height: s * 0.52)
                .offset(y: -s * 0.02)
            Rectangle().fill(c(WPalette.terracotta)).frame(width: s * 0.08, height: s * 0.28)
                .offset(x: s * 0.18, y: s * 0.26)
        case .clock:
            Circle().fill(c(WPalette.mustard)).frame(width: s * 0.84, height: s * 0.84)
            Circle().fill(c(WPalette.cream)).frame(width: s * 0.66, height: s * 0.66)
            Capsule().fill(c(WPalette.ink)).frame(width: s * 0.07, height: s * 0.26)
                .offset(y: -s * 0.11)
            Capsule().fill(c(WPalette.ink)).frame(width: s * 0.20, height: s * 0.07)
                .offset(x: s * 0.08)
        case .compass:
            Circle().fill(c(WPalette.leaf)).frame(width: s * 0.84, height: s * 0.84)
            Circle().fill(c(WPalette.cream)).frame(width: s * 0.66, height: s * 0.66)
            Needle().fill(c(WPalette.terracotta)).frame(width: s * 0.2, height: s * 0.56)
                .rotationEffect(.degrees(35))
        }
    }

    private func sunRays(count: Int, length: CGFloat, radius: CGFloat, color: Color) -> some View {
        ZStack {
            ForEach(0..<count, id: \.self) { k in
                Capsule()
                    .fill(color)
                    .frame(width: size * 0.07, height: length)
                    .offset(y: -radius)
                    .rotationEffect(.degrees(Double(k) * 360 / Double(count)))
            }
        }
    }
}

struct Crescent: Shape {
    func path(in rect: CGRect) -> Path {
        let outer = Path(ellipseIn: rect)
        let cut = Path(ellipseIn: rect.offsetBy(dx: rect.width * 0.30, dy: -rect.height * 0.12))
        return outer.subtracting(cut)
    }
}

struct Star5: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        var p = Path()
        for j in 0..<10 {
            let a = (Double(j) * 36 - 90) * .pi / 180
            let rr = j.isMultiple(of: 2) ? r : r * 0.45
            let pt = CGPoint(x: c.x + cos(a) * rr, y: c.y + sin(a) * rr)
            if j == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

struct Needle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        p.closeSubpath()
        return p
    }
}

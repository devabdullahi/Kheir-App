import SwiftUI
import QuartzCore

// MARK: - Book opening beats
//
// One clock, transforms and opacity only. `k` is ms along the opening (0 = closed,
// 1350 = the first page fills the screen); closing plays the same beats backwards.
//   lift   0–140    the cover rises off the pages
//   swing  100–1050 it swings open from the spine (ease-in-out), lining shows past 90°
//   settle 700–1050 the lift settles back as it lands
//   grow   820–1350 the first page, already visible inside the book, grows to fill the screen

struct BookBeats {
    let lift: Double
    let angle: Double
    let grow: Double
    /// 0 → 1 as the cover goes from closed to fully open.
    let open: Double
    let bookOpacity: Double

    init(k: Double) {
        lift = seg(k, 0, 140) * (1 - seg(k, 700, 1050))
        angle = -176 * seg(k, 100, 1050, easeOut: false)
        grow = seg(k, 820, 1350)
        open = -angle / 176
        bookOpacity = k > 1050 ? 1 - seg(k, 1050, 1250) : 1
    }

    /// Shadow the turning cover throws across the page.
    var pageShadowOpacity: Double { sin(.pi * min(1, open)) * 0.9 }
    var pageShadowScale: Double { 1 - open * 0.8 }
    /// The front darkens as it turns away from the lamp; the lining lightens as it turns towards it.
    var frontShade: Double { min(1, open * 1.8) * 0.9 }
    var backShade: Double { max(0, 1 - open) * 0.9 }
}

enum BookLayout {
    /// Where the closed book lies on the table, in screen coordinates.
    static func rect(screen: CGSize, insets: EdgeInsets) -> CGRect {
        let left: CGFloat = 30, right: CGFloat = 26
        let top = insets.top + 18
        let bottom = insets.bottom + 34
        return CGRect(x: left, y: top, width: max(10, screen.width - left - right), height: max(10, screen.height - top - bottom))
    }
}

// MARK: - Table

/// Green construction paper under the lamp: the table the book lies on.
struct CoverTable: View {
    var body: some View {
        ZStack {
            Color(hex: "#2E5E3A")
            PaperGrain(material: .kraft, seed: 77, dark: true)
            RadialGradient(
                colors: [Color(red: 1, green: 0.84, blue: 0.59).opacity(0.28), .clear],
                center: UnitPoint(x: 0.25, y: 0.1), startRadius: 0, endRadius: 520
            )
            RadialGradient(
                colors: [.clear, .black.opacity(0.22)],
                center: UnitPoint(x: 0.5, y: 0.45), startRadius: 260, endRadius: 720
            )
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// The page block seen past the cover's fore-edge.
struct BookPageBlock: View {
    var body: some View {
        Canvas { ctx, size in
            let r = Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadii: RectangleCornerRadii(topLeading: 0, bottomLeading: 0, bottomTrailing: 8, topTrailing: 8))
            ctx.fill(r, with: .color(Color(hex: "#FBF5E8")))
            var x: CGFloat = 2
            var c = ctx
            c.clip(to: r)
            while x < size.width {
                c.fill(Path(CGRect(x: x, y: 0, width: 1, height: size.height)), with: .color(Color(hex: "#E9DCC2")))
                x += 3
            }
        }
        .shadow(color: .black.opacity(0.35), radius: 4, x: 2, y: 4)
        .accessibilityHidden(true)
    }
}

/// The shadow of the turning cover sweeping across the first page.
struct BookPageShadow: View {
    let beats: BookBeats
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: Color(red: 0.08, green: 0.04, blue: 0).opacity(0.45), location: 0),
                .init(color: .clear, location: 0.7)
            ],
            startPoint: .leading, endPoint: .trailing
        )
        .scaleEffect(x: beats.pageShadowScale, y: 1, anchor: .leading)
        .opacity(beats.pageShadowOpacity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Cover

/// The cover as it turns: the kraft face until it passes 90°, then the patterned lining.
struct BookCover: View {
    let beats: BookBeats
    let size: CGSize
    let onOpen: () -> Void

    /// Swings the cover about its spine (the leading edge), seen in perspective from
    /// the middle of the book, lifted `lift` off the pages.
    static func hinge(angle: Double, lift: Double, size: CGSize) -> ProjectionTransform {
        let cy = size.height / 2, cx = size.width / 2
        var perspective = CATransform3DIdentity
        perspective.m34 = -1 / 1500
        var t = CATransform3DMakeTranslation(0, -cy, 0)
        t = CATransform3DConcat(t, CATransform3DMakeRotation(angle * .pi / 180, 0, 1, 0))
        t = CATransform3DConcat(t, CATransform3DMakeTranslation(0, cy, lift * 22))
        t = CATransform3DConcat(t, CATransform3DMakeTranslation(-cx, -cy, 0))
        t = CATransform3DConcat(t, perspective)
        t = CATransform3DConcat(t, CATransform3DMakeTranslation(cx, cy, 0))
        return ProjectionTransform(t)
    }

    var body: some View {
        let showsFace = beats.angle > -90
        ZStack {
            if showsFace {
                BookCoverFace(idle: beats.open == 0)
                    .overlay {
                        LinearGradient(colors: [.black.opacity(0.45), .black.opacity(0.05)], startPoint: .leading, endPoint: .trailing)
                            .opacity(beats.frontShade)
                            .allowsHitTesting(false)
                    }
            } else {
                BookLining()
                    .overlay {
                        LinearGradient(colors: [.black.opacity(0.4), .clear], startPoint: .trailing, endPoint: .leading)
                            .opacity(beats.backShade)
                    }
                    .scaleEffect(x: -1, y: 1)
            }
        }
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 2, bottomLeadingRadius: 2, bottomTrailingRadius: 8, topTrailingRadius: 8))
        .overlay(alignment: .bottomLeading) {
            GeometryReader { geo in
                BookRibbon(still: beats.open > 0)
                    .frame(width: 14, height: 46)
                    .position(x: geo.size.width * 0.62, y: geo.size.height + 6)
            }
        }
        .paperShadow(depth: 2.4 + beats.lift * 2)
        .projectionEffect(Self.hinge(angle: beats.angle, lift: beats.lift, size: size))
        .contentShape(Rectangle())
        .onTapGesture { onOpen() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Kheir, your spiritual companion. As-salāmu ʿalaykum. No ads, never sold, private.")
        .accessibilityHint("Opens the book to set up Kheir")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onOpen() }
    }
}

/// The front of the closed book.
struct BookCoverFace: View {
    var idle = true

    var body: some View {
        ZStack(alignment: .leading) {
            Color(hex: "#B88B5E")
            PaperGrain(material: .kraft, seed: 21)
            LinearGradient(colors: [.white.opacity(0.14), .clear, .black.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing)

            // Spine with its brass brads
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    Color(hex: "#8A6440")
                        .frame(width: 26)
                        .overlay(alignment: .trailing) {
                            LinearGradient(colors: [.clear, .black.opacity(0.25)], startPoint: .leading, endPoint: .trailing).frame(width: 5)
                        }
                    ForEach([0.1, 0.5, 0.9], id: \.self) { f in
                        BrassBrad(size: 9).position(x: 13, y: geo.size.height * f)
                    }
                    BrassBrad(size: 9).position(x: geo.size.width - 14, y: 14)
                    BrassBrad(size: 9).position(x: geo.size.width - 14, y: geo.size.height - 14)
                }
            }

            GeometryReader { geo in
                let fit = min(1, geo.size.height / 640, (geo.size.width - 26) / 330)
            VStack(spacing: 14) {
                Text("بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ")
                    .font(.custom("ScheherazadeNew-Regular", size: 22))
                    .foregroundStyle(OBInk.cream.opacity(0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                CrescentMedallion()
                    .frame(width: 124, height: 124)
                Text("KHEIR")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .tracking(10)
                    .foregroundStyle(OBInk.cream)
                    .padding(.leading, 10)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .paperPiece(OBInk.terracotta, material: .felt, depth: 1.4, radius: 10, seed: 9, padding: nil)
                    .rotationEffect(.degrees(-1.5))
                OBTag(text: "Spiritual companion", color: OBInk.cream, seed: 12, tilt: 2)
                Text("As-salāmu ʿalaykum")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(OBInk.cream)
                    .padding(.top, 6)
                HStack(spacing: 5) {
                    OBTag(text: "No ads", color: OBInk.leaf, seed: 601, tilt: -3)
                    OBTag(text: "Never sold", color: OBInk.mustard, seed: 602, tilt: 2)
                    OBTag(text: "Private", color: OBInk.rose, seed: 603, tilt: -1.5)
                }
                TapHint(still: !idle)
                    .padding(.top, 10)
            }
            .fixedSize()
            .scaleEffect(fit)
            .frame(width: geo.size.width - 26, height: geo.size.height)
            .offset(x: 26)
            }
        }
        .environment(\.colorScheme, .light)
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
    }
}

/// The patterned endpaper on the inside of the cover.
struct BookLining: View {
    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: "#E9D9BC")))
            let gold = Color(hex: "#C98F22"), green = Color(hex: "#3E7350")
            var y: CGFloat = 0
            while y <= size.height + 14 {
                var x: CGFloat = 0
                while x <= size.width + 14 {
                    ctx.fill(Path(ellipseIn: CGRect(x: x - 2, y: y - 2, width: 4, height: 4)), with: .color(green))
                    x += 14
                }
                y += 14
            }
            y = 14
            while y <= size.height {
                var x: CGFloat = 14
                while x <= size.width {
                    let star = Path { p in
                        for i in 0..<8 {
                            let a = Double(i) * .pi / 4
                            let r: CGFloat = i % 2 == 0 ? 4 : 1.8
                            let q = CGPoint(x: x + cos(a) * r, y: y + sin(a) * r)
                            if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
                        }
                        p.closeSubpath()
                    }
                    ctx.fill(star, with: .color(gold))
                    x += 28
                }
                y += 28
            }
        }
        .overlay { PaperGrain(material: .construction, seed: 33) }
        .accessibilityHidden(true)
    }
}

/// Gold eight-point star with a cream disc and a green crescent.
struct CrescentMedallion: View {
    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width, size.height) / 120
            var c = ctx
            c.translateBy(x: size.width / 2, y: size.height / 2)
            c.scaleBy(x: s, y: s)
            c.addFilter(.shadow(color: Color(red: 0.16, green: 0.08, blue: 0.02).opacity(0.4), radius: 2, x: 1.5, y: 3))
            c.drawLayer { l in
                for a in [0.0, 45.0] {
                    var sq = l
                    sq.rotate(by: .degrees(a))
                    sq.fill(Path(roundedRect: CGRect(x: -40, y: -40, width: 80, height: 80), cornerRadius: 4), with: .color(Color(hex: "#E3B65A")))
                }
                l.fill(Path(ellipseIn: CGRect(x: -30, y: -30, width: 60, height: 60)), with: .color(Color(hex: "#FBF5E8")))
                let outer = Path(ellipseIn: CGRect(x: 0.25 - 16, y: -16, width: 32, height: 32))
                let inner = Path(ellipseIn: CGRect(x: 8 - 14, y: -14, width: 28, height: 28))
                l.fill(outer.subtracting(inner), with: .color(Color(hex: "#3E7350")))
            }
        }
        .accessibilityHidden(true)
    }
}

/// The ribbon bookmark hanging out of the book, swaying from where it is glued.
struct BookRibbon: View {
    var still = false
    var body: some View {
        LoopClock(period: 7_600, paused: still) { t in
            RibbonShape()
                .fill(OBInk.terracotta)
                .shadow(color: .black.opacity(0.3), radius: 1, x: 1, y: 2)
                .rotationEffect(.degrees(0.5 + 4.5 * wave(t, period: 7_600)), anchor: .top)
        }
        .accessibilityHidden(true)
    }
}

struct RibbonShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.midX, y: r.minY + r.height * 0.82))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

/// "Tap to open", breathing gently while the book waits.
struct TapHint: View {
    var still = false
    var body: some View {
        LoopClock(period: 2_400, paused: still) { t in
            let p = bell(t / 2_400)
            Text("TAP TO OPEN ›")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(OBInk.cream)
                .opacity(0.6 + 0.4 * p)
                .offset(y: -3 * p)
        }
    }
}

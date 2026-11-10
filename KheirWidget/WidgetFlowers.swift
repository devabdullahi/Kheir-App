import SwiftUI
import WidgetKit

// MARK: - Flower of the day (widget copy)
//
// A static copy of the app's `DailyFlower` / `FlowerArt`
// (`Kheir/Core/UI/FlowerOfDay.swift`). The extension cannot import app files,
// so the species, palettes and drawing are repeated here. Keep the two in step:
// the same date must pick the same flower in the app and on the widget.

enum WFlowerSpecies: Int, CaseIterable, Sendable {
    case jasmine, daisy, sakura, tulip, rose, sunflower, lotus, poppy, lavender, hibiscus

    var name: String {
        switch self {
        case .jasmine: "Jasmine"
        case .daisy: "Daisy"
        case .sakura: "Sakura"
        case .tulip: "Tulip"
        case .rose: "Rose"
        case .sunflower: "Sunflower"
        case .lotus: "Lotus"
        case .poppy: "Poppy"
        case .lavender: "Lavender"
        case .hibiscus: "Hibiscus"
        }
    }

    /// Paper colour pairs (main, lighter layer) this species can be cut from.
    var palettes: [(UInt32, UInt32)] {
        switch self {
        case .jasmine: [(0xFBF5E8, 0xF3E8D2), (0xFFFFFF, 0xF6EBC8)]
        case .daisy: [(0xFBF5E8, 0xF6EBC8), (0xE6A08C, 0xF4C2B5)]
        case .sakura: [(0xF4B6C2, 0xF9D3DA), (0xE6A08C, 0xF4C2B5)]
        case .tulip: [(0xD2694B, 0xE98C6E), (0xE3B65A, 0xF2CF78), (0xB5476B, 0xD46A8C)]
        case .rose: [(0xC0392B, 0xD9574A), (0xE6A08C, 0xF2BFAF), (0xE3B65A, 0xF2CF78)]
        case .sunflower: [(0xE3B65A, 0xF2CF78)]
        case .lotus: [(0xE79AB0, 0xF6C6D3), (0xFBF5E8, 0xF4D6DE)]
        case .poppy: [(0xD2402B, 0xE5644C), (0xE58A3A, 0xF0A860)]
        case .lavender: [(0x8E7CC3, 0xB3A4DD)]
        case .hibiscus: [(0xD2694B, 0xE98C6E), (0xC2185B, 0xE04F80), (0xE3B65A, 0xF2CF78)]
        }
    }
}

struct WDailyFlower: Sendable {
    let species: WFlowerSpecies
    let petal: Color
    let petalLight: Color
    /// Resting tilt in degrees, so no two flowers stand the same way.
    let tilt: Double

    /// A stable day number for `date` in the user's calendar (same as the app).
    static func dayNumber(_ date: Date, calendar: Calendar = .current) -> Int {
        calendar.ordinality(of: .day, in: .era, for: date) ?? 0
    }

    static func forDay(_ day: Int) -> WDailyFlower {
        let species = WFlowerSpecies.allCases[((day % 10) + 10) % 10]
        let v = wSeeded(day, salt: 5)
        let pair = species.palettes[min(species.palettes.count - 1, Int(v * Double(species.palettes.count)))]
        return WDailyFlower(species: species, petal: WPalette.hex(pair.0), petalLight: WPalette.hex(pair.1), tilt: (v - 0.5) * 14)
    }

    static func forDate(_ date: Date) -> WDailyFlower { forDay(dayNumber(date)) }
}

// MARK: Drawing

enum WFlowerArt {
    static let green = WPalette.hex(0x3E7350)
    static let greenLight = WPalette.hex(0x5F9A6E)
    static let gold = WPalette.hex(0xE3B65A)

    /// Draws `flower` with the base of its stem at the context's origin, `size` pt wide.
    /// Art is authored in a 40 × 46 box whose stem base sits at (0, 22).
    static func draw(_ flower: WDailyFlower, in context: GraphicsContext, size: CGFloat) {
        var ctx = context
        let s = size / 40
        ctx.scaleBy(x: s, y: s)
        ctx.translateBy(x: 0, y: -22)
        if flower.species != .lavender { drawStem(&ctx) }
        drawHead(flower, &ctx)
    }

    private static func drawStem(_ ctx: inout GraphicsContext) {
        var stem = Path()
        stem.move(to: CGPoint(x: 0, y: 6))
        stem.addQuadCurve(to: CGPoint(x: 0, y: 22), control: CGPoint(x: 2, y: 14))
        ctx.stroke(stem, with: .color(green), lineWidth: 2.2)
        var leaf = Path()
        leaf.move(to: CGPoint(x: 1, y: 15))
        leaf.addCurve(to: CGPoint(x: 12, y: 14), control1: CGPoint(x: 6, y: 10), control2: CGPoint(x: 11, y: 12))
        leaf.addCurve(to: CGPoint(x: 1, y: 15), control1: CGPoint(x: 8, y: 16), control2: CGPoint(x: 4, y: 17))
        ctx.fill(leaf, with: .color(greenLight))
    }

    private static func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2))
    }

    /// `n` petals of length `len` radiating from the centre.
    private static func ring(_ ctx: inout GraphicsContext, n: Int, len: CGFloat, width: CGFloat, color: Color, offset: Double = 0) {
        for k in 0..<n {
            var c = ctx
            c.rotate(by: .degrees(offset + Double(k) * 360 / Double(n)))
            c.fill(ellipse(0, -len / 2, width, len / 2), with: .color(color))
        }
    }

    private static func petalShape(_ ctx: inout GraphicsContext, count: Int, color: (Int) -> Color, offset: Double = 0, _ build: (inout Path) -> Void) {
        for k in 0..<count {
            var c = ctx
            c.rotate(by: .degrees(offset + Double(k) * 360 / Double(count)))
            var p = Path()
            build(&p)
            c.fill(p, with: .color(color(k)))
        }
    }

    private static func drawHead(_ f: WDailyFlower, _ ctx: inout GraphicsContext) {
        let c1 = f.petal, c2 = f.petalLight
        switch f.species {
        case .jasmine:
            petalShape(&ctx, count: 5, color: { $0.isMultiple(of: 2) ? c1 : c2 }, offset: 15) { p in
                p.move(to: .zero)
                p.addCurve(to: CGPoint(x: 0, y: -16), control1: CGPoint(x: -6, y: -5), control2: CGPoint(x: -6, y: -14))
                p.addCurve(to: .zero, control1: CGPoint(x: 5, y: -15), control2: CGPoint(x: 7, y: -8))
            }
            ctx.fill(ellipse(0, 0, 2.6, 2.6), with: .color(gold))
        case .daisy:
            ring(&ctx, n: 14, len: 15, width: 2.4, color: c1)
            ring(&ctx, n: 14, len: 12, width: 2, color: c2, offset: 12.8)
            ctx.fill(ellipse(0, 0, 4.6, 4.6), with: .color(gold))
            ctx.fill(ellipse(-1, -1, 2.4, 2.4), with: .color(WPalette.hex(0xF2CF78)))
        case .sakura:
            petalShape(&ctx, count: 5, color: { $0.isMultiple(of: 2) ? c1 : c2 }) { p in
                p.move(to: .zero)
                p.addCurve(to: CGPoint(x: -2.5, y: -16), control1: CGPoint(x: -7, y: -4), control2: CGPoint(x: -8, y: -13))
                p.addLine(to: CGPoint(x: 0, y: -13.5))
                p.addLine(to: CGPoint(x: 2.5, y: -16))
                p.addCurve(to: .zero, control1: CGPoint(x: 8, y: -13), control2: CGPoint(x: 7, y: -4))
            }
            ctx.fill(ellipse(0, 0, 2.4, 2.4), with: .color(WPalette.hex(0xB5476B)))
        case .tulip:
            var cup = Path()
            cup.move(to: CGPoint(x: -9, y: -4))
            cup.addCurve(to: CGPoint(x: 0, y: -14), control1: CGPoint(x: -10, y: -14), control2: CGPoint(x: -5, y: -18))
            cup.addCurve(to: CGPoint(x: 9, y: -4), control1: CGPoint(x: 5, y: -18), control2: CGPoint(x: 10, y: -14))
            cup.addCurve(to: CGPoint(x: -9, y: -4), control1: CGPoint(x: 8, y: 4), control2: CGPoint(x: -8, y: 4))
            ctx.fill(cup, with: .color(c1))
            var front = Path()
            front.move(to: CGPoint(x: -4, y: -2))
            front.addCurve(to: CGPoint(x: 0, y: -16), control1: CGPoint(x: -6, y: -12), control2: CGPoint(x: -1, y: -17))
            front.addCurve(to: CGPoint(x: 2, y: 2), control1: CGPoint(x: 3, y: -13), control2: CGPoint(x: 4, y: -6))
            front.closeSubpath()
            ctx.fill(front, with: .color(c2))
        case .rose:
            ctx.fill(ellipse(0, 0, 14, 14), with: .color(c1))
            ctx.fill(ellipse(1, -1, 10.5, 10.5), with: .color(c2))
            ctx.fill(ellipse(-1, 0, 7, 7), with: .color(c1))
            var swirl = Path()
            swirl.addArc(center: CGPoint(x: -0.5, y: 0.5), radius: 3.5, startAngle: .degrees(200), endAngle: .degrees(520), clockwise: false)
            ctx.stroke(swirl, with: .color(c2), lineWidth: 2)
        case .sunflower:
            ring(&ctx, n: 16, len: 17, width: 2.6, color: c1)
            ring(&ctx, n: 16, len: 13, width: 2.2, color: c2, offset: 11)
            ctx.fill(ellipse(0, 0, 7.5, 7.5), with: .color(WPalette.hex(0x6B4423)))
            for k in 0..<9 {
                let a = Double(k) * 2.4, r = CGFloat(k) * 0.6
                ctx.fill(ellipse(CGFloat(cos(a)) * r, CGFloat(sin(a)) * r, 0.8, 0.8), with: .color(WPalette.hex(0x3A2412)))
            }
        case .lotus:
            for (k, a) in [-60.0, -30, 0, 30, 60].enumerated() {
                var c = ctx
                c.translateBy(x: 0, y: 6)
                c.rotate(by: .degrees(a))
                var p = Path()
                p.move(to: .zero)
                p.addCurve(to: CGPoint(x: 0, y: -22), control1: CGPoint(x: -6, y: -8), control2: CGPoint(x: -4, y: -18))
                p.addCurve(to: .zero, control1: CGPoint(x: 4, y: -18), control2: CGPoint(x: 6, y: -8))
                c.fill(p, with: .color(k.isMultiple(of: 2) ? c1 : c2))
            }
            var pad = Path()
            pad.move(to: CGPoint(x: -12, y: 7))
            pad.addQuadCurve(to: CGPoint(x: 12, y: 7), control: CGPoint(x: 0, y: 12))
            pad.addQuadCurve(to: CGPoint(x: -12, y: 7), control: CGPoint(x: 0, y: 9))
            ctx.fill(pad, with: .color(greenLight))
        case .poppy:
            for (k, a) in [20.0, 110, 200, 290].enumerated() {
                var c = ctx
                c.rotate(by: .degrees(a))
                c.fill(ellipse(0, -7, 8.5, 8.5), with: .color(k.isMultiple(of: 2) ? c1 : c2))
            }
            ctx.fill(ellipse(0, 0, 4, 4), with: .color(WPalette.hex(0x2B2118)))
        case .lavender:
            var stem = Path()
            stem.move(to: CGPoint(x: 0, y: 22))
            stem.addLine(to: CGPoint(x: 0, y: -14))
            ctx.stroke(stem, with: .color(green), lineWidth: 2)
            for k in 0..<7 {
                let side: CGFloat = k.isMultiple(of: 2) ? -2.6 : 2.6
                var c = ctx
                c.translateBy(x: side, y: -14 + CGFloat(k) * 3.6)
                c.rotate(by: .degrees(side < 0 ? -20 : 20))
                c.fill(ellipse(0, 0, 2.6, 3.4), with: .color(k.isMultiple(of: 2) ? c1 : c2))
            }
        case .hibiscus:
            petalShape(&ctx, count: 5, color: { $0.isMultiple(of: 2) ? c1 : c2 }) { p in
                p.move(to: .zero)
                p.addCurve(to: CGPoint(x: -3, y: -17), control1: CGPoint(x: -9, y: -3), control2: CGPoint(x: -11, y: -15))
                p.addCurve(to: .zero, control1: CGPoint(x: 2, y: -18), control2: CGPoint(x: 9, y: -14))
            }
            var stamen = Path()
            stamen.move(to: .zero)
            stamen.addLine(to: CGPoint(x: 7, y: -10))
            ctx.stroke(stamen, with: .color(gold), lineWidth: 1.6)
            ctx.fill(ellipse(7.5, -10.5, 1.6, 1.6), with: .color(gold))
        }
    }
}

// MARK: View

/// A still paper flower for `day`, standing on the bottom-centre of its frame.
/// The frame is `size × 1.2` wide and `size × 1.3` tall, like the app's view.
struct WFlowerView: View {
    let flower: WDailyFlower
    var size: CGFloat = 36
    /// Extra rotation on top of the flower's own tilt (pressed flowers).
    var extraTilt: Double = 0

    init(day: Int, size: CGFloat = 36, extraTilt: Double = 0) {
        self.flower = WDailyFlower.forDay(day)
        self.size = size
        self.extraTilt = extraTilt
    }

    init(date: Date, size: CGFloat = 36, extraTilt: Double = 0) {
        self.init(day: WDailyFlower.dayNumber(date), size: size, extraTilt: extraTilt)
    }

    var body: some View {
        Canvas { ctx, canvasSize in
            var c = ctx
            c.translateBy(x: canvasSize.width / 2, y: canvasSize.height * 0.95)
            c.rotate(by: .degrees(flower.tilt + extraTilt))
            c.addFilter(.shadow(color: Color(red: 0.16, green: 0.08, blue: 0.02).opacity(0.35), radius: 1.1, x: 0.6, y: 1.4))
            WFlowerArt.draw(flower, in: c, size: size)
        }
        .frame(width: size * 1.2, height: size * 1.3)
        .accessibilityLabel(flower.species.name)
    }
}

// MARK: - Verse of the day (widget copy)
//
// Mirrors `DailyVerse` in `Kheir/Features/Home/HomeLayout.swift`: the same list
// and the same rotation by day number, so the widget and Home agree.

enum WDailyVerse {
    struct Verse: Sendable { let meaning: String; let ref: String }

    static let all: [Verse] = [
        Verse(meaning: "Indeed, with hardship comes ease.", ref: "94:6"),
        Verse(meaning: "So remember Me; I will remember you.", ref: "2:152"),
        Verse(meaning: "Indeed, I am near.", ref: "2:186"),
        Verse(meaning: "In the remembrance of Allah do hearts find rest.", ref: "13:28"),
        Verse(meaning: "Allah does not burden a soul beyond its capacity.", ref: "2:286"),
        Verse(meaning: "Whoever relies upon Allah, He is sufficient for him.", ref: "65:3"),
        Verse(meaning: "Do not weaken and do not grieve.", ref: "3:139"),
        Verse(meaning: "He is with you wherever you are.", ref: "57:4"),
        Verse(meaning: "Do not despair of the mercy of Allah.", ref: "39:53"),
        Verse(meaning: "Indeed, Allah is with the patient.", ref: "2:153"),
        Verse(meaning: "Call upon Me; I will respond to you.", ref: "40:60"),
        Verse(meaning: "If you are grateful, I will surely increase you.", ref: "14:7"),
        Verse(meaning: "My Lord, increase me in knowledge.", ref: "20:114"),
        Verse(meaning: "Your Lord will give you, and you will be satisfied.", ref: "93:5"),
        Verse(meaning: "Your Lord has not taken leave of you.", ref: "93:3"),
        Verse(meaning: "We are closer to him than his jugular vein.", ref: "50:16"),
        Verse(meaning: "Those who strive for Us, We will guide to Our ways.", ref: "29:69"),
        Verse(meaning: "Allah loves those who rely upon Him.", ref: "3:159"),
        Verse(meaning: "Seek help through patience and prayer.", ref: "2:45"),
        Verse(meaning: "Do not grieve; indeed Allah is with us.", ref: "9:40"),
        Verse(meaning: "Say, He is Allah, the One.", ref: "112:1"),
        Verse(meaning: "Which of the favours of your Lord would you deny?", ref: "55:13"),
        Verse(meaning: "My success is only through Allah.", ref: "11:88"),
        Verse(meaning: "The mercy of Allah is near to the doers of good.", ref: "7:56"),
        Verse(meaning: "Perhaps you dislike a thing and it is good for you.", ref: "2:216"),
        Verse(meaning: "Whoever believes in Allah, He will guide his heart.", ref: "64:11"),
        Verse(meaning: "Remember Allah with much remembrance.", ref: "33:41"),
        Verse(meaning: "And to your Lord direct your longing.", ref: "94:8"),
        Verse(meaning: "Allah is the best of planners.", ref: "8:30"),
        Verse(meaning: "Indeed, my Lord is near and responsive.", ref: "11:61"),
    ]

    static func forDate(_ date: Date = .now) -> Verse {
        let day = WDailyFlower.dayNumber(date)
        return all[((day % all.count) + all.count) % all.count]
    }
}

// MARK: - Shared widget helpers

enum WidgetShared {
    static let appGroupID = "group.com.kheir.shared"
    static var defaults: UserDefaults? { UserDefaults(suiteName: appGroupID) }

    /// The next local midnight after `date`.
    static func nextMidnight(after date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: date) ?? date.addingTimeInterval(86_400))
    }
}

/// Reads the app's prayed log (`PrayerLog` in NotificationService.swift):
/// app group key `prayed_log_v1` = [dayKey "yyyy-MM-dd": [prayer names]].
enum WPrayerLog {
    private static let key = "prayed_log_v1"

    private static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func dayKey(_ date: Date) -> String { dayKeyFormatter.string(from: date) }

    static func prayed(on date: Date) -> Set<String> {
        let log = WidgetShared.defaults?.dictionary(forKey: key) as? [String: [String]]
        return Set(log?[dayKey(date)] ?? [])
    }
}

/// Always-light widgets: the paper is cream and kraft even in dark mode.
extension View {
    func wAlwaysLight() -> some View { environment(\.colorScheme, .light) }
}

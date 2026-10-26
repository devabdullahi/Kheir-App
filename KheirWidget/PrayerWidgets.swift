import WidgetKit
import SwiftUI

// MARK: - Prayer timeline (shared by "Prayer flower" and "Next prayer")
//
// Prayer times come from `widget_prayer_schedule_v1` (PrayerSchedule.swift);
// prayed prayers from `prayed_log_v1` (WPrayerLog). The app reloads all
// timelines when a prayer is marked or unmarked, so the log is read fresh for
// each timeline. Entries: now, every prayer time, and each midnight (the
// flower empties for the new day).

struct PrayerDayEntry: TimelineEntry {
    let date: Date
    /// The coming prayer, or nil when the app has not written a schedule yet.
    let next: WidgetPrayer?
    /// The prayer before `next` (may be yesterday's Isha before Fajr).
    let previous: WidgetPrayer?
    /// Prayers marked as prayed on the calendar day of `date`.
    let prayedToday: Set<String>
    /// Whether `previous` is in the prayed log for its own day.
    let previousPrayed: Bool

    var prayedCount: Int { prayedToday.intersection(WidgetPrayerSchedule.fivePrayers).count }
    /// The next prayer is on the same calendar day (not tomorrow's Fajr).
    var nextIsToday: Bool { next.map { Calendar.current.isDate($0.date, inSameDayAs: date) } ?? false }

    static func sample(at now: Date = Date(), prayed: Set<String> = ["Fajr", "Dhuhr"]) -> PrayerDayEntry {
        let cal = Calendar.current
        func at(_ h: Int, _ m: Int) -> Double {
            (cal.date(bySettingHour: h, minute: m, second: 0, of: now) ?? now).timeIntervalSince1970
        }
        let day = [
            WidgetPrayer(name: "Fajr", time: at(5, 58)),
            WidgetPrayer(name: "Dhuhr", time: at(12, 39)),
            WidgetPrayer(name: "Asr", time: at(15, 42)),
            WidgetPrayer(name: "Maghrib", time: at(18, 12)),
            WidgetPrayer(name: "Isha", time: at(19, 28))
        ]
        let schedule = WidgetPrayerSchedule(generatedAt: now.timeIntervalSince1970, prayers: day)
        return PrayerTimelineProvider.entry(at: now, schedule: schedule, prayed: { _ in prayed })
    }

    /// 2:17:50 PM today: Asr next in 1:24:10, Fajr and Dhuhr prayed.
    static var placeholder: PrayerDayEntry {
        let now = Date()
        let date = Calendar.current.date(bySettingHour: 14, minute: 17, second: 50, of: now) ?? now
        return sample(at: date)
    }

    static func empty(_ date: Date) -> PrayerDayEntry {
        PrayerDayEntry(date: date, next: nil, previous: nil, prayedToday: WPrayerLog.prayed(on: date), previousPrayed: false)
    }
}

struct PrayerTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> PrayerDayEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (PrayerDayEntry) -> Void) {
        let now = Date()
        guard let schedule = WidgetPrayerSchedule.load(), schedule.obligatory.contains(where: { $0.date > now }) else {
            completion(context.isPreview ? .placeholder : .empty(now))
            return
        }
        completion(Self.entry(at: now, schedule: schedule, prayed: WPrayerLog.prayed(on:)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerDayEntry>) -> Void) {
        let now = Date()
        guard let schedule = WidgetPrayerSchedule.load() else {
            completion(Timeline(entries: [.empty(now)], policy: .after(now.addingTimeInterval(3600))))
            return
        }
        let prayerTimes = schedule.obligatory.map(\.date).filter { $0 > now }
        let last = prayerTimes.last ?? now
        var midnights: [Date] = []
        var m = WidgetShared.nextMidnight(after: now)
        while m <= last {
            midnights.append(m)
            m = WidgetShared.nextMidnight(after: m)
        }
        let dates = Array(Set([now] + prayerTimes + midnights)).sorted()
        let entries = dates.map { Self.entry(at: $0, schedule: schedule, prayed: WPrayerLog.prayed(on:)) }
        // Past the last known prayer the app has to write a fresh schedule; check hourly.
        let refresh = prayerTimes.last ?? now.addingTimeInterval(3600)
        completion(Timeline(entries: entries, policy: .after(refresh)))
    }

    static func entry(at date: Date, schedule: WidgetPrayerSchedule, prayed: (Date) -> Set<String>) -> PrayerDayEntry {
        let all = schedule.obligatory
        let next = all.first { $0.date > date }
        let previous = all.last { $0.date <= date }
        let previousPrayed = previous.map { prayed($0.date).contains($0.name) } ?? false
        return PrayerDayEntry(date: date, next: next, previous: previous, prayedToday: prayed(date), previousPrayed: previousPrayed)
    }
}

// MARK: - Formatting

enum WPrayerFormat {
    /// "3:42" (or "15:42"): the clock time without AM/PM.
    static func time(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.defaultDigits(amPM: .omitted)).minute())
    }
}

/// A live countdown to `to` ("1:24:10"). `Text(timerInterval:)` is the form
/// WidgetKit keeps ticking reliably in every family.
func wShortCountdown(from: Date, to: Date) -> Text {
    Text(timerInterval: from...max(from, to), countsDown: true)
        .monospacedDigit()
}

// MARK: - Prayer flower

/// Five paper petals, one per prayer, clockwise from the top: prayed petals
/// take their prayer's colour, the rest stay cream, and the next prayer's petal
/// is outlined in gold and a little larger. The green centre can name the next prayer.
struct WPrayerFlower: View {
    static let names = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]
    static let colors: [UInt32] = [0xE6A08C, 0xE3B65A, 0xD2694B, 0xC2185B, 0x8E7CC3]

    let prayed: Set<String>
    let next: String?
    var centerName: String? = nil
    var centerTime: String? = nil
    var size: CGFloat = 104
    /// Tinted / Lock Screen: one tone, drawn in white with opacity.
    var monochrome: Bool = false

    var body: some View {
        Canvas { ctx, canvas in
            // Art is authored in a 100-unit box with 4 units of bleed (SVG viewBox -4 -4 108 108).
            let u = min(canvas.width, canvas.height) / 108
            var art = ctx
            art.translateBy(x: 4 * u, y: 4 * u)
            art.scaleBy(x: u, y: u)
            let shadow = GraphicsContext.Filter.shadow(color: Color(red: 0.16, green: 0.08, blue: 0.02).opacity(0.35), radius: 1.2, x: 0.8, y: 2)

            for (i, name) in Self.names.enumerated() {
                let done = prayed.contains(name)
                let isNext = name == next
                let fill: Color = monochrome
                    ? .white.opacity(done ? 0.95 : 0.28)
                    : (done ? WPalette.hex(Self.colors[i]) : WPalette.hex(0xF3E8D2))
                var c = art
                c.translateBy(x: 50, y: 50)
                c.rotate(by: .degrees(Double(i) * 72))
                if isNext { c.scaleBy(x: 1.1, y: 1.1) }
                c.translateBy(x: -50, y: -50)
                var petal = Path()
                petal.move(to: CGPoint(x: 50, y: 50))
                petal.addCurve(to: CGPoint(x: 50, y: 4), control1: CGPoint(x: 30, y: 34), control2: CGPoint(x: 33, y: 8))
                petal.addCurve(to: CGPoint(x: 50, y: 50), control1: CGPoint(x: 67, y: 8), control2: CGPoint(x: 70, y: 34))
                petal.closeSubpath()
                if !monochrome { c.addFilter(shadow) }
                c.fill(petal, with: .color(fill))
                if isNext {
                    c.stroke(petal, with: .color(monochrome ? .white : WPalette.mustard), lineWidth: 2.5)
                }

                // ✓ on prayed petals, the prayer's initial on the others.
                let a = (-90 + Double(i) * 72) * .pi / 180
                let p = CGPoint(x: (4 + 50 + cos(a) * 30) * u, y: (4 + 50 + sin(a) * 30) * u)
                let label = Text(done ? "✓" : String(name.prefix(1)))
                    .font(.system(size: 7 * u, weight: .black, design: .rounded))
                    .foregroundStyle(monochrome ? (done ? Color.black.opacity(0.55) : .white) : (done ? WPalette.ink : WPalette.hex(0x9C8A6E)))
                ctx.draw(label, at: p)
            }

            var disc = art
            if !monochrome { disc.addFilter(shadow) }
            disc.fill(Path(ellipseIn: CGRect(x: 33, y: 33, width: 34, height: 34)),
                      with: .color(monochrome ? .white.opacity(0.22) : WPalette.leaf))

            if let centerName {
                let name = Text(centerName)
                    .font(.system(size: 8.5 * u, weight: .black, design: .rounded))
                    .foregroundStyle(monochrome ? .white : WPalette.cream)
                ctx.draw(name, at: CGPoint(x: 54 * u, y: (centerTime == nil ? 54 : 50.5) * u))
            }
            if let centerTime {
                let time = Text(centerTime)
                    .font(.system(size: 7 * u, weight: .heavy, design: .rounded))
                    .foregroundStyle(monochrome ? .white : WPalette.mustard)
                ctx.draw(time, at: CGPoint(x: 54 * u, y: 60 * u))
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel("\(prayed.count) of 5 prayers prayed" + (next.map { ", next \($0)" } ?? ""))
    }
}

// MARK: - Prayer flower widget (small + Lock Screen circular)

struct PrayerFlowerWidgetView: View {
    let entry: PrayerDayEntry
    /// Lock Screen circular: the bare flower, no centre text or caption.
    var lock: Bool = false
    @Environment(\.widgetRenderingMode) private var mode

    var body: some View {
        Group {
            if lock {
                WPrayerFlower(
                    prayed: entry.prayedToday,
                    next: entry.nextIsToday ? entry.next?.name : nil,
                    size: 58,
                    monochrome: true
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                small
            }
        }
        .widgetURL(URL(string: "kheir://prayer"))
    }

    private var small: some View {
        let mono = mode.isMonochrome
        let ink2: Color = mono ? .white.opacity(0.8) : WPalette.ink2
        return VStack(spacing: 2) {
            WPrayerFlower(
                prayed: entry.prayedToday,
                next: entry.nextIsToday ? entry.next?.name : nil,
                centerName: entry.next?.name,
                centerTime: entry.next.map { WPrayerFormat.time($0.date) },
                size: 112,
                monochrome: mono
            )
            Group {
                if let next = entry.next {
                    Text("\(entry.prayedCount) of 5 · in \(wShortCountdown(from: entry.date, to: next.date))")
                } else {
                    Text("\(entry.prayedCount) of 5 prayed")
                }
            }
            .font(.system(size: 11, weight: .heavy, design: .rounded))
            .foregroundStyle(ink2)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PrayerFlowerWidget: Widget {
    let kind = "PrayerFlowerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerTimelineProvider()) { entry in
            PrayerFlowerEntryRoot(entry: entry)
        }
        .configurationDisplayName("Prayer Flower")
        .description("One petal for each prayer. Petals fill in as you mark your prayers.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
        .contentMarginsDisabled()
    }
}

private struct PrayerFlowerEntryRoot: View {
    let entry: PrayerDayEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if family == .accessoryCircular {
            PrayerFlowerWidgetView(entry: entry, lock: true)
                .containerBackground(for: .widget) { AccessoryWidgetBackground() }
        } else {
            PrayerFlowerWidgetView(entry: entry)
                .wAlwaysLight()
                .containerBackground(for: .widget) {
                    WPaperSheet(color: WPalette.cream, seed: 402).wAlwaysLight()
                }
        }
    }
}

// MARK: - Next prayer widget (medium + Lock Screen rectangular)

/// Light dusk paper sky: warm bands, the sun by day or a hanging crescent after
/// Maghrib, two torn green hills.
struct WDuskSky: View {
    /// After Maghrib (and before Fajr) the crescent hangs instead of the sun.
    let night: Bool
    var hillHeight: CGFloat = 62

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack(alignment: .topLeading) {
                LinearGradient(
                    colors: (night ? [0xD6A6A4, 0xE6B794, 0xF0C88A] : [0xE8A87A, 0xEDB884, 0xF0C88A]).map { WPalette.hex($0) },
                    startPoint: .top, endPoint: .bottom
                )
                // Paper bands: faint torn strips across the sky.
                ForEach(0..<3, id: \.self) { k in
                    WTornHill(baseline: 0, amplitude: 2.5, seed: 40 + k)
                        .fill(Color.white.opacity(0.07 + 0.03 * Double(k)))
                        .frame(height: h)
                        .offset(y: h * (0.18 + 0.17 * CGFloat(k)))
                }
                if night {
                    // A crescent hanging from a thread.
                    Path { p in
                        p.move(to: CGPoint(x: w - 48, y: 0))
                        p.addLine(to: CGPoint(x: w - 48, y: 18))
                    }
                    .stroke(WPalette.ink.opacity(0.35), lineWidth: 0.8)
                    Crescent()
                        .fill(WPalette.moon)
                        .frame(width: 34, height: 34)
                        .rotationEffect(.degrees(-18))
                        .wPaperShadow(depth: 0.9)
                        .position(x: w - 50, y: 34)
                    ForEach(0..<3, id: \.self) { k in
                        Star5()
                            .fill(WPalette.cream.opacity(0.9))
                            .frame(width: 6, height: 6)
                            .position(x: w * (0.48 + 0.12 * CGFloat(k)), y: 14 + 12 * wSeeded(k, salt: 4))
                    }
                } else {
                    Circle()
                        .fill(WPalette.hex(0xF7B733, 0.25))
                        .frame(width: 66, height: 66)
                        .position(x: w - 53, y: 41)
                    Circle()
                        .fill(WPalette.hex(0xF7B733))
                        .frame(width: 46, height: 46)
                        .wPaperShadow(depth: 0.9)
                        .position(x: w - 53, y: 41)
                }
                ZStack {
                    WTornHill(baseline: 0.35, amplitude: 6, seed: 31).fill(WPalette.hex(0x7FAE7A)).wPaperShadow(depth: 0.7)
                    WTornHill(baseline: 0.62, amplitude: 5, seed: 32).fill(WPalette.hex(0x4E8A5A)).wPaperShadow(depth: 0.9)
                }
                .frame(width: w, height: hillHeight)
                .offset(y: h - hillHeight)
            }
        }
    }
}

struct NextPrayerWidgetView: View {
    let entry: PrayerDayEntry
    /// Lock Screen rectangular instead of the medium home-screen layout.
    var lock: Bool = false
    @Environment(\.widgetRenderingMode) private var mode

    var body: some View {
        Group {
            if lock { rectangular } else { medium }
        }
        .widgetURL(URL(string: "kheir://prayer"))
    }

    // MARK: Medium

    private var medium: some View {
        let mono = mode.isMonochrome
        let ink: Color = mono ? .white : WPalette.ink
        return ZStack(alignment: .topLeading) {
            gardenRow
            VStack(alignment: .leading, spacing: 0) {
                WPaperTag(text: "Next prayer", seed: 420, color: WPalette.cream)
                if let next = entry.next {
                    Text("\(next.name) \(Text(WPrayerFormat.time(next.date)).foregroundStyle(mono ? Color.white : WPalette.hex(0x8B2E1A)))")
                        .font(.system(size: 25, weight: .black, design: .rounded))
                        .foregroundStyle(ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.top, 6)
                    countdownLine(next)
                } else {
                    Text("Open Kheir to load today’s prayer times.")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(ink)
                        .frame(maxWidth: 190, alignment: .leading)
                        .padding(.top, 8)
                }
            }
            .padding(.leading, 16)
            .padding(.top, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func countdownLine(_ next: WidgetPrayer) -> some View {
        let mono = mode.isMonochrome
        return HStack(spacing: 0) {
            Text("in \(Text(timerInterval: entry.date...max(entry.date, next.date), countsDown: true))")
                .monospacedDigit()
                .fixedSize()
            if let previous = entry.previous, entry.previousPrayed {
                Text(" · \(previous.name) prayed ✓").fixedSize()
            }
        }
        .font(.system(size: 12, weight: .heavy, design: .rounded))
        .foregroundStyle(mono ? Color.white.opacity(0.85) : WPalette.ink.opacity(0.75))
        .lineLimit(1)
    }

    /// Recent days' flowers planted along the hills, newest on the right.
    private var gardenRow: some View {
        let today = WDailyFlower.dayNumber(entry.date)
        return VStack {
            Spacer(minLength: 0)
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(0..<8, id: \.self) { slot in
                    let k = 7 - slot
                    WFlowerView(day: today - k, size: k.isMultiple(of: 2) ? 36 : 29)
                        .offset(y: CGFloat(k % 3) * 4)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 6)
        }
    }

    // MARK: Lock Screen rectangular

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let next = entry.next {
                Text("\(next.name) · \(WPrayerFormat.time(next.date))")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.8))
                Text("in \(wShortCountdown(from: entry.date, to: next.date))")
                    .font(.system(size: 21, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .widgetAccentable()
            } else {
                Text("Prayer times")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("Open Kheir")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
            }
            Text("\(entry.prayedCount) of 5 prayed")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
    }
}

struct NextPrayerWidget: Widget {
    let kind = "NextPrayerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerTimelineProvider()) { entry in
            NextPrayerEntryRoot(entry: entry)
        }
        .configurationDisplayName("Next Prayer")
        .description("The coming prayer with a live countdown, over the paper hills.")
        .supportedFamilies([.systemMedium, .accessoryRectangular])
        .contentMarginsDisabled()
    }
}

private struct NextPrayerEntryRoot: View {
    let entry: PrayerDayEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if family == .accessoryRectangular {
            NextPrayerWidgetView(entry: entry, lock: true)
                .containerBackground(for: .widget) { AccessoryWidgetBackground() }
        } else {
            NextPrayerWidgetView(entry: entry)
                .wAlwaysLight()
                .containerBackground(for: .widget) {
                    WDuskSky(night: Self.isNight(entry)).wAlwaysLight()
                }
        }
    }

    /// Night sky when the coming prayer is Isha or Fajr (i.e. after Maghrib).
    static func isNight(_ entry: PrayerDayEntry) -> Bool {
        guard let next = entry.next else {
            let h = Calendar.current.component(.hour, from: entry.date)
            return h >= 19 || h < 5
        }
        return next.name == "Isha" || next.name == "Fajr"
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Prayer flower", as: .systemSmall) {
    PrayerFlowerWidget()
} timeline: {
    PrayerDayEntry.placeholder
}

#Preview("Prayer flower · Lock", as: .accessoryCircular) {
    PrayerFlowerWidget()
} timeline: {
    PrayerDayEntry.placeholder
}

#Preview("Next prayer", as: .systemMedium) {
    NextPrayerWidget()
} timeline: {
    PrayerDayEntry.placeholder
    PrayerDayEntry.sample(at: Calendar.current.date(bySettingHour: 18, minute: 40, second: 0, of: .now) ?? .now,
                          prayed: ["Fajr", "Dhuhr", "Asr", "Maghrib"])
}

#Preview("Next prayer · Lock", as: .accessoryRectangular) {
    NextPrayerWidget()
} timeline: {
    PrayerDayEntry.placeholder
}
#endif

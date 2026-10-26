import WidgetKit
import SwiftUI

// MARK: - Day timeline (flower & verse, garden)
//
// Both widgets change only at midnight: one entry now and one at the next
// midnight, then WidgetKit asks again.

struct FlowerDayEntry: TimelineEntry {
    let date: Date
    /// Days in the user's streak (app group `widget_streak_days`), already
    /// zeroed when the streak was last recorded before yesterday.
    let streak: Int

    static var placeholder: FlowerDayEntry { FlowerDayEntry(date: Date(), streak: 12) }
}

struct FlowerDayProvider: TimelineProvider {
    func placeholder(in context: Context) -> FlowerDayEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (FlowerDayEntry) -> Void) {
        let entry = Self.entry(at: Date())
        completion(context.isPreview && entry.streak == 0 ? .placeholder : entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FlowerDayEntry>) -> Void) {
        let now = Date()
        let midnight = WidgetShared.nextMidnight(after: now)
        let entries = [Self.entry(at: now), Self.entry(at: midnight)]
        completion(Timeline(entries: entries, policy: .after(WidgetShared.nextMidnight(after: midnight))))
    }

    /// The app writes the streak and the day it was recorded when Home opens.
    /// A streak recorded today or yesterday still stands; older means it lapsed.
    static func entry(at date: Date) -> FlowerDayEntry {
        let defaults = WidgetShared.defaults
        let days = defaults?.integer(forKey: "widget_streak_days") ?? 0
        guard days > 0, let recorded = defaults?.string(forKey: "widget_streak_day") else {
            return FlowerDayEntry(date: date, streak: max(0, days))
        }
        let cal = Calendar.current
        let yesterday = cal.date(byAdding: .day, value: -1, to: date) ?? date
        let fresh = recorded == WPrayerLog.dayKey(date) || recorded == WPrayerLog.dayKey(yesterday)
        return FlowerDayEntry(date: date, streak: fresh ? days : 0)
    }
}

// MARK: - Flower & verse (small)

struct FlowerVerseWidgetView: View {
    let entry: FlowerDayEntry
    @Environment(\.widgetRenderingMode) private var mode

    var body: some View {
        let verse = WDailyVerse.forDate(entry.date)
        let mono = mode.isMonochrome
        VStack(spacing: 3) {
            WFlowerView(date: entry.date, size: 50)
            Text("“\(verse.meaning)”")
                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                .foregroundStyle(mono ? Color.white : WPalette.ink)
                .multilineTextAlignment(.center)
                .lineSpacing(0.5)
                .lineLimit(4)
                .minimumScaleFactor(0.75)
                .fixedSize(horizontal: false, vertical: true)
            Text(verse.ref)
                .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                .foregroundStyle(mono ? Color.white.opacity(0.7) : WPalette.ink2.opacity(0.85))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetURL(URL(string: "kheir://home"))
    }
}

struct FlowerVerseWidget: Widget {
    let kind = "FlowerVerseWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FlowerDayProvider()) { entry in
            FlowerVerseWidgetView(entry: entry)
                .wAlwaysLight()
                .containerBackground(for: .widget) {
                    WPaperSheet(color: WPalette.cream, seed: 401).wAlwaysLight()
                }
        }
        .configurationDisplayName("Flower & Verse")
        .description("Today’s paper flower and a short verse that changes every day.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

// MARK: - Your garden (medium)

struct GardenWidgetView: View {
    let entry: FlowerDayEntry
    @Environment(\.widgetRenderingMode) private var mode

    /// Flowers for past streak days in the ground row (today stands on its own).
    private static let rowSlots = 11

    var body: some View {
        let mono = mode.isMonochrome
        let ink: Color = mono ? .white : WPalette.ink
        let ink2: Color = mono ? .white.opacity(0.75) : WPalette.ink2
        let today = WDailyFlower.dayNumber(entry.date)
        let past = min(max(entry.streak - 1, 0), Self.rowSlots)

        ZStack(alignment: .topLeading) {
            // Kraft ground strip with a torn top edge.
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                WTornHill(baseline: 0.08, amplitude: 1.5, seed: 450)
                    .fill(mono ? Color.white.opacity(0.18) : WPalette.kraft)
                    .wPaperShadow(depth: mono ? 0 : 0.7)
                    .frame(height: 48)
            }

            // One small flower per streak day, newest on the right.
            GeometryReader { geo in
                let slot = (geo.size.width - 20) / CGFloat(Self.rowSlots)
                ForEach(0..<past, id: \.self) { i in
                    let daysAgo = past - i
                    WFlowerView(day: today - daysAgo, size: 22)
                        .position(
                            x: 10 + slot * (CGFloat(Self.rowSlots - past + i) + 0.5),
                            y: geo.size.height - 26 - 22 * 0.65 + CGFloat(i % 2) * 2
                        )
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                WPaperTag(text: "Your garden", seed: 451, color: WPalette.hex(0x7FAE7A))
                Text(entry.streak == 1 ? "1 day" : "\(entry.streak) days")
                    .font(.system(size: 23, weight: .black, design: .rounded))
                    .foregroundStyle(ink)
                    .padding(.top, 5)
                Text(entry.streak > 0 ? "one flower for each day" : "open Kheir to plant today’s flower")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(ink2)
            }
            .padding(.leading, 16)
            .padding(.top, 14)

            VStack(spacing: 0) {
                WFlowerView(date: entry.date, size: 54)
                Text("TODAY")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(ink2)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 16)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetURL(URL(string: "kheir://home"))
    }
}

struct GardenWidget: Widget {
    /// The app reloads this kind when it records the streak (HomeViewModel).
    let kind = "GardenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FlowerDayProvider()) { entry in
            GardenWidgetView(entry: entry)
                .wAlwaysLight()
                .containerBackground(for: .widget) {
                    WPaperSheet(color: WPalette.cream, seed: 452).wAlwaysLight()
                }
        }
        .configurationDisplayName("Your Garden")
        .description("Your streak as a garden: one paper flower for each day.")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Flower & verse", as: .systemSmall) {
    FlowerVerseWidget()
} timeline: {
    FlowerDayEntry.placeholder
    FlowerDayEntry(date: Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now, streak: 13)
}

#Preview("Your garden", as: .systemMedium) {
    GardenWidget()
} timeline: {
    FlowerDayEntry.placeholder
    FlowerDayEntry(date: .now, streak: 3)
    FlowerDayEntry(date: .now, streak: 0)
}
#endif

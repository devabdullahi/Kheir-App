import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct NextPrayerEntry: TimelineEntry {
    let date: Date
    /// The coming prayer, or nil when the app has not written a schedule yet.
    let next: WidgetPrayer?
    /// The five prayers of the day shown in the medium size (today, or tomorrow after Isha).
    let day: [WidgetPrayer]
    let dayDate: Date

    static var placeholder: NextPrayerEntry {
        let now = Date()
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
        return NextPrayerEntry(date: now, next: day[2], day: day, dayDate: now)
    }
}

// MARK: - Timeline Provider

struct NextPrayerProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextPrayerEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (NextPrayerEntry) -> Void) {
        let schedule = WidgetPrayerSchedule.load()
        let entry = schedule.map { Self.entry(at: Date(), schedule: $0) } ?? .placeholder
        completion(context.isPreview && entry.next == nil ? .placeholder : entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextPrayerEntry>) -> Void) {
        let now = Date()
        guard let schedule = WidgetPrayerSchedule.load() else {
            let empty = NextPrayerEntry(date: now, next: nil, day: [], dayDate: now)
            completion(Timeline(entries: [empty], policy: .after(now.addingTimeInterval(3600))))
            return
        }
        // One entry now, then one at every prayer time: the countdown text runs
        // live in between, and each prayer time hands over to the next.
        let changes = schedule.obligatory.map(\.date).filter { $0 > now }
        let entries = ([now] + changes).map { Self.entry(at: $0, schedule: schedule) }
        let refresh = changes.last ?? now.addingTimeInterval(3600)
        completion(Timeline(entries: entries, policy: .after(refresh)))
    }

    static func entry(at date: Date, schedule: WidgetPrayerSchedule) -> NextPrayerEntry {
        let next = schedule.obligatory.first { $0.date > date }
        let calendar = Calendar.current
        // After Isha the "day" view rolls over to tomorrow.
        let dayDate = next.map { calendar.isDate($0.date, inSameDayAs: date) ? date : $0.date } ?? date
        return NextPrayerEntry(date: date, next: next, day: schedule.prayers(onDayOf: dayDate), dayDate: dayDate)
    }
}

// MARK: - Entry View

struct NextPrayerWidgetEntryView: View {
    let entry: NextPrayerEntry

    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.widgetRenderingMode) private var mode

    private var dark: Bool { colorScheme == .dark }
    private var ink: Color { mode.isMonochrome ? .primary : WPalette.text(dark) }
    private var ink2: Color { mode.isMonochrome ? .secondary : WPalette.text2(dark) }
    private var gold: Color { mode.isMonochrome ? .primary : WPalette.gold(dark) }

    var body: some View {
        Group {
            if entry.next == nil {
                emptyState
            } else if family == .systemMedium {
                mediumLayout
            } else {
                smallLayout
            }
        }
        .widgetURL(URL(string: "kheir://prayer"))
    }

    // MARK: Small: next prayer, time and live countdown

    private var smallLayout: some View {
        let next = entry.next!
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                WPaperTag(text: "Next", seed: 310)
                Spacer(minLength: 4)
                WPaperIcon(WIcon(prayer: next.name), size: 26)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(next.name)
                    .font(.system(size: 19, weight: .heavy, design: .rounded))
                    .foregroundStyle(ink)
                Text(next.date, format: .dateTime.hour().minute())
                    .font(.system(size: 21, weight: .black, design: .rounded))
                    .foregroundStyle(gold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .widgetAccentable()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            HStack(spacing: 3) {
                Text("in")
                Text(timerInterval: entry.date...max(entry.date, next.date), countsDown: true)
                    .monospacedDigit()
            }
            .font(.system(size: 11, weight: .heavy, design: .rounded))
            .foregroundStyle(ink2)
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    // MARK: Medium: today's five prayers as paper tiles

    private var mediumLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                WPaperTag(text: dayTitle, seed: 312)
                Spacer(minLength: 4)
                WPaperIcon(.clock, size: 18)
            }
            HStack(spacing: 6) {
                ForEach(Array(entry.day.enumerated()), id: \.element) { k, prayer in
                    tile(prayer, isNext: prayer == entry.next, seed: 313 + k)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var dayTitle: String {
        let isToday = Calendar.current.isDate(entry.dayDate, inSameDayAs: entry.date)
        let day = entry.dayDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        return "\(isToday ? "Today" : "Tomorrow") · \(day)"
    }

    private func tile(_ prayer: WidgetPrayer, isNext: Bool, seed: Int) -> some View {
        VStack(spacing: 2) {
            WPaperIcon(WIcon(prayer: prayer.name), size: 22)
            Text(prayer.name)
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(isNext && !mode.isMonochrome ? WPalette.ink : ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(prayer.date, format: .dateTime.hour(.defaultDigits(amPM: .omitted)).minute())
                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                .foregroundStyle(isNext && !mode.isMonochrome ? WPalette.ink.opacity(0.75) : ink2)
                .lineLimit(1)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 2)
        .frame(maxWidth: .infinity)
        .wPaper(isNext ? WPalette.mustard : WPalette.raised(dark), depth: isNext ? 1.6 : 0.4, radius: 10, seed: seed)
        .rotationEffect(.degrees(isNext ? -2 : 0))
        .zIndex(isNext ? 1 : 0)
        .modifier(AccentIf(isNext))
    }

    // MARK: Empty: no schedule yet

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                WPaperTag(text: "Next", seed: 310)
                Spacer(minLength: 4)
                WPaperIcon(.clock, size: 22)
            }
            Spacer(minLength: 0)
            Text("Open Kheir to load today’s prayer times.")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(ink)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct AccentIf: ViewModifier {
    let on: Bool
    init(_ on: Bool) { self.on = on }
    func body(content: Content) -> some View {
        content.widgetAccentable(on)
    }
}

// MARK: - Widget Declaration

struct NextPrayerWidget: Widget {
    let kind: String = "NextPrayerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextPrayerProvider()) { entry in
            NextPrayerWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    WPaperSheet(seed: 311)
                }
        }
        .configurationDisplayName("Next Prayer")
        .description("The coming prayer with a live countdown, and today’s five prayers.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    NextPrayerWidget()
} timeline: {
    NextPrayerEntry.placeholder
}

#Preview("Medium", as: .systemMedium) {
    NextPrayerWidget()
} timeline: {
    NextPrayerEntry.placeholder
}

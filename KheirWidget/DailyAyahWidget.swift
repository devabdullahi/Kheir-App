import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct DailyAyahEntry: TimelineEntry {
    let date: Date
    let arabicText: String
    let translation: String
    let surahName: String
    let verseRef: String

    static let placeholder = DailyAyahEntry(
        date: Date(),
        arabicText: "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ",
        translation: "In the name of Allah, the Entirely Merciful, the Especially Merciful.",
        surahName: "الفاتحة",
        verseRef: "Al-Fatiha 1:1"
    )

    func at(_ date: Date) -> DailyAyahEntry {
        DailyAyahEntry(date: date, arabicText: arabicText, translation: translation, surahName: surahName, verseRef: verseRef)
    }
}

// MARK: - Timeline Provider

struct DailyAyahProvider: TimelineProvider {

    private static let appGroupID = "group.com.kheir.shared"

    func placeholder(in context: Context) -> DailyAyahEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyAyahEntry) -> Void) {
        completion(entryForToday())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyAyahEntry>) -> Void) {
        let entry = entryForToday()
        let calendar = Calendar.current
        let now = Date()
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now.addingTimeInterval(86400)
        let nextMidnight = calendar.startOfDay(for: tomorrow)
        // The large size shows a still of the paper sky, so add an entry at each
        // change of sky phase (same ayah) to keep the colours true to the hour.
        let boundaries = [4, 6, 10, 15, 17, 19].compactMap {
            calendar.date(bySettingHour: $0, minute: 0, second: 0, of: now)
        }.filter { $0 > now }
        let entries = [entry] + boundaries.map { entry.at($0) }
        completion(Timeline(entries: entries, policy: .after(nextMidnight)))
    }

    private func entryForToday() -> DailyAyahEntry {
        guard let defaults = UserDefaults(suiteName: Self.appGroupID) else {
            return .placeholder
        }

        guard let arabicText = defaults.string(forKey: "widget_ayah_arabic"),
              let translation = defaults.string(forKey: "widget_ayah_translation"),
              let verseRef = defaults.string(forKey: "widget_ayah_ref") else {
            return .placeholder
        }

        let surahName = defaults.string(forKey: "widget_ayah_surah") ?? ""

        return DailyAyahEntry(
            date: Date(),
            arabicText: arabicText,
            translation: translation,
            surahName: surahName,
            verseRef: verseRef
        )
    }
}

// MARK: - Entry View

struct DailyAyahWidgetEntryView: View {
    let entry: DailyAyahEntry

    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.widgetRenderingMode) private var mode

    private var dark: Bool { colorScheme == .dark }
    private var ink: Color { mode.isMonochrome ? .primary : WPalette.text(dark) }
    private var ink2: Color { mode.isMonochrome ? .secondary : WPalette.text2(dark) }

    var body: some View {
        Group {
            switch family {
            case .systemSmall: smallLayout
            case .systemLarge: largeLayout
            default: mediumLayout
            }
        }
        .widgetURL(URL(string: "kheir://home/ayah"))
    }

    private func header(_ title: String, seed: Int) -> some View {
        HStack(alignment: .center) {
            WPaperTag(text: title, seed: seed)
            Spacer(minLength: 4)
            WPaperIcon(.book, size: 18)
        }
    }

    private func arabic(_ size: CGFloat, lines: Int?) -> some View {
        Text(entry.arabicText)
            .font(.system(size: size, weight: .regular, design: .serif))
            .lineSpacing(size * 0.25)
            .multilineTextAlignment(.trailing)
            .lineLimit(lines)
            .minimumScaleFactor(0.7)
            .foregroundStyle(ink)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .environment(\.layoutDirection, .rightToLeft)
    }

    private func footer(showBrand: Bool) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(entry.verseRef)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 4)
            if showBrand { Text("Kheir").fontWeight(.black) }
        }
        .font(.system(size: 11, weight: .heavy, design: .rounded))
        .foregroundStyle(ink2)
    }

    // MARK: Small (2x2): header, ayah, reference

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 6) {
            header("Ayah", seed: 301)
            arabic(20, lines: 3)
                .frame(maxHeight: .infinity)
            footer(showBrand: false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Medium (4x2)

    private var mediumLayout: some View {
        VStack(alignment: .leading, spacing: 6) {
            header("Daily Ayah", seed: 302)
            VStack(alignment: .leading, spacing: 4) {
                arabic(19, lines: 2)
                Text(entry.translation)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .lineLimit(2)
                    .foregroundStyle(ink2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: .infinity)
            footer(showBrand: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Large (4x4): paper sky strip with the ayah on cardstock below

    private var largeLayout: some View {
        VStack(spacing: 0) {
            // The sky itself lives in the container background so it can bleed to
            // the edges; leave room for it here.
            Color.clear.frame(height: 70)
            VStack(alignment: .leading, spacing: 10) {
                header("Daily Ayah", seed: 305)
                arabic(22, lines: 5)
                    .frame(maxHeight: .infinity)
                Text(entry.translation)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .lineLimit(5)
                    .foregroundStyle(ink2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                footer(showBrand: true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .wPaper(WPalette.card(dark), depth: 1.2, radius: 12, seed: 306)
            .rotationEffect(.degrees(-0.4))
        }
    }
}

// MARK: - Background

/// Cardstock for small/medium; for large a raised sheet with the paper sky at the top.
struct DailyAyahBackground: View {
    let date: Date
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        if family == .systemLarge {
            ZStack(alignment: .top) {
                WPaperSheet(color: WPalette.raised(scheme == .dark), seed: 304)
                WPaperSky(date: date, height: 118)
            }
        } else {
            WPaperSheet(seed: family == .systemSmall ? 301 : 302)
        }
    }
}

// MARK: - Widget Declaration

struct DailyAyahWidget: Widget {
    let kind: String = "DailyAyahWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailyAyahProvider()) { entry in
            DailyAyahWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    DailyAyahBackground(date: entry.date)
                }
        }
        .configurationDisplayName("Daily Ayah")
        .description("The verse of the day from the Quran.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    DailyAyahWidget()
} timeline: {
    DailyAyahEntry.placeholder
}

#Preview("Medium", as: .systemMedium) {
    DailyAyahWidget()
} timeline: {
    DailyAyahEntry.placeholder
}

#Preview("Large", as: .systemLarge) {
    DailyAyahWidget()
} timeline: {
    DailyAyahEntry.placeholder
}

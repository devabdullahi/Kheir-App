import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct DailyAyahEntry: TimelineEntry {
    let date: Date
    let arabicText: String
    let translation: String
    let verseRef: String

    static let placeholder = DailyAyahEntry(
        date: Date(),
        arabicText: "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ",
        translation: "In the name of Allah, the Entirely Merciful, the Especially Merciful.",
        verseRef: "Al-Fatiha 1:1"
    )
}

// MARK: - Timeline Provider
//
// The app writes the ayah of the day to the App Group (`widget_ayah_arabic`,
// `widget_ayah_translation`, `widget_ayah_ref`; HomeViewModel.syncAyahToWidget)
// and reloads this kind. The pressed flowers follow the date, so refresh at midnight.

struct DailyAyahProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailyAyahEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (DailyAyahEntry) -> Void) {
        completion(Self.entry(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyAyahEntry>) -> Void) {
        let now = Date()
        completion(Timeline(entries: [Self.entry(at: now)], policy: .after(WidgetShared.nextMidnight(after: now))))
    }

    static func entry(at date: Date) -> DailyAyahEntry {
        guard let defaults = WidgetShared.defaults,
              let arabic = defaults.string(forKey: "widget_ayah_arabic"),
              let translation = defaults.string(forKey: "widget_ayah_translation"),
              let ref = defaults.string(forKey: "widget_ayah_ref") else {
            return DailyAyahEntry(date: date, arabicText: DailyAyahEntry.placeholder.arabicText,
                                  translation: DailyAyahEntry.placeholder.translation, verseRef: DailyAyahEntry.placeholder.verseRef)
        }
        return DailyAyahEntry(date: date, arabicText: arabic, translation: translation, verseRef: ref)
    }
}

// MARK: - Entry View (large): a taped paper card on kraft, pressed flowers tucked around it

struct DailyAyahWidgetView: View {
    let entry: DailyAyahEntry
    @Environment(\.widgetRenderingMode) private var mode

    var body: some View {
        let mono = mode.isMonochrome
        let ink: Color = mono ? .white : WPalette.ink
        let today = WDailyFlower.dayNumber(entry.date)

        ZStack(alignment: .topLeading) {
            // The cream card, torn at the edges.
            Color.clear
                .wPaper(WPalette.cream, depth: 1.3, edge: .torn, radius: 6, seed: 470)
                .padding(14)

            // Washi tape holding the card.
            Rectangle()
                .fill(mono ? Color.white.opacity(0.35) : WPalette.mustard.opacity(0.6))
                .frame(width: 74, height: 22)
                .overlay(WTornStrip(seed: 471).fill(Color.white.opacity(mono ? 0 : 0.12)))
                .rotationEffect(.degrees(-3))
                .frame(maxWidth: .infinity)
                .padding(.top, 3)

            // Pressed flowers from the garden.
            WFlowerView(day: today - 2, size: 50, extraTilt: -24)
                .offset(x: 0, y: 18)
            GeometryReader { geo in
                WFlowerView(day: today - 5, size: 28, extraTilt: 30)
                    .position(x: geo.size.width - 48, y: 54)
                WFlowerView(day: today, size: 62, extraTilt: 18)
                    .position(x: geo.size.width - 46, y: geo.size.height - 54)
            }

            VStack(alignment: .leading, spacing: 10) {
                WPaperTag(text: "Daily ayah", seed: 472)
                Text(entry.arabicText)
                    .font(.system(size: 25, weight: .regular, design: .serif))
                    .lineSpacing(6)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(5)
                    .minimumScaleFactor(0.4)
                    .foregroundStyle(ink)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .environment(\.layoutDirection, .rightToLeft)
                Text(entry.translation)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .lineSpacing(1.5)
                    .lineLimit(6)
                    .minimumScaleFactor(0.55)
                    .foregroundStyle(ink.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(entry.verseRef)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(ink.opacity(0.6))
                    .lineLimit(1)
            }
            .padding(.horizontal, 36)
            .padding(.top, 50)
            .padding(.bottom, 64)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetURL(URL(string: "kheir://home/ayah"))
    }
}

// MARK: - Widget Declaration

struct DailyAyahWidget: Widget {
    /// HomeViewModel reloads this kind when it writes a new ayah.
    let kind: String = "DailyAyahWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailyAyahProvider()) { entry in
            DailyAyahWidgetView(entry: entry)
                .wAlwaysLight()
                .containerBackground(for: .widget) {
                    WPaperSheet(color: WPalette.kraftSheet, seed: 473).wAlwaysLight()
                }
        }
        .configurationDisplayName("Daily Ayah")
        .description("The ayah of the day on a taped paper card, with pressed flowers.")
        .supportedFamilies([.systemLarge])
        .contentMarginsDisabled()
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Daily ayah", as: .systemLarge) {
    DailyAyahWidget()
} timeline: {
    DailyAyahEntry.placeholder
}
#endif

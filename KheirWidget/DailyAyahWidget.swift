import WidgetKit
import SwiftUI

// MARK: - Theme Colors (matching app's Color+Theme.swift)

private extension Color {
    // Dark mode
    static let darkBackground = Color(red: 0.08, green: 0.09, blue: 0.18)
    static let darkCardSurface = Color(red: 0.08, green: 0.16, blue: 0.14)
    static let islamicGold = Color(red: 0.85, green: 0.68, blue: 0.32)
    static let darkBodyText = Color(red: 0.93, green: 0.93, blue: 0.90)

    // Light mode
    static let lightBackground = Color(red: 0.97, green: 0.95, blue: 0.90)
    static let lightPrimary = Color(red: 0.13, green: 0.37, blue: 0.27)
    static let lightBodyText = Color(red: 0.08, green: 0.09, blue: 0.18)
}

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
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let nextMidnight = Calendar.current.startOfDay(for: tomorrow)
        let timeline = Timeline(entries: [entry], policy: .after(nextMidnight))
        completion(timeline)
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

    // Adaptive colors matching the app
    private var primaryColor: Color {
        colorScheme == .dark ? .islamicGold : .lightPrimary
    }
    private var textColor: Color {
        colorScheme == .dark ? .darkBodyText : .lightBodyText
    }
    private var secondaryTextColor: Color {
        colorScheme == .dark ? .darkBodyText.opacity(0.7) : .lightBodyText.opacity(0.6)
    }
    private var cardSurface: Color {
        colorScheme == .dark ? .darkCardSurface : .white
    }
    private var bgColor: Color {
        colorScheme == .dark ? .darkBackground : .lightBackground
    }

    var body: some View {
        switch family {
        case .systemSmall:
            smallLayout
        case .systemLarge:
            largeLayout
        default:
            mediumLayout
        }
    }

    // MARK: Small (2x2)

    private var smallLayout: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Spacer(minLength: 0)

            Text(entry.arabicText)
                .font(.system(size: 15, weight: .regular, design: .serif))
                .multilineTextAlignment(.trailing)
                .lineLimit(3)
                .foregroundStyle(textColor)
                .environment(\.layoutDirection, .rightToLeft)

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Text(entry.verseRef)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(primaryColor.opacity(0.8))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
        .widgetURL(URL(string: "kheir://home/ayah"))
    }

    // MARK: Medium (4x2)

    private var mediumLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text("Daily Ayah")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(primaryColor)
                Spacer()
                Image(systemName: "book.fill")
                    .font(.caption)
                    .foregroundStyle(primaryColor.opacity(0.6))
            }

            // Arabic text
            Text(entry.arabicText)
                .font(.system(size: 18, weight: .regular, design: .serif))
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .foregroundStyle(textColor)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .environment(\.layoutDirection, .rightToLeft)

            // Translation
            Text(entry.translation)
                .font(.caption)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .foregroundStyle(secondaryTextColor)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            // Surah reference
            Text(entry.verseRef)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(primaryColor.opacity(0.8))
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetURL(URL(string: "kheir://home/ayah"))
    }

    // MARK: Large (4x4)

    private var largeLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Daily Ayah")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(primaryColor)
                Spacer()
                Image(systemName: "book.fill")
                    .font(.caption)
                    .foregroundStyle(primaryColor.opacity(0.6))
            }

            Spacer(minLength: 4)

            // Arabic text — full display
            Text(entry.arabicText)
                .font(.system(size: 24, weight: .regular, design: .serif))
                .multilineTextAlignment(.trailing)
                .foregroundStyle(textColor)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .environment(\.layoutDirection, .rightToLeft)

            // Divider line
            Rectangle()
                .fill(primaryColor.opacity(0.2))
                .frame(height: 1)
                .padding(.vertical, 4)

            // Translation — full display
            Text(entry.translation)
                .font(.body)
                .multilineTextAlignment(.leading)
                .foregroundStyle(textColor)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 4)

            // Surah reference
            HStack {
                Text(entry.verseRef)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(primaryColor.opacity(0.8))
                Spacer()
                Text("Kheir")
                    .font(.caption2)
                    .foregroundStyle(secondaryTextColor)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetURL(URL(string: "kheir://home/ayah"))
    }
}

// MARK: - Widget Declaration

struct DailyAyahWidget: Widget {
    let kind: String = "DailyAyahWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailyAyahProvider()) { entry in
            DailyAyahWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    AdaptiveWidgetBackground()
                }
        }
        .configurationDisplayName("Daily Ayah")
        .description("The verse of the day from the Quran.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// Adaptive background that matches the app's theme
private struct AdaptiveWidgetBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        colorScheme == .dark
            ? Color(red: 0.08, green: 0.09, blue: 0.18)
            : Color(red: 0.97, green: 0.95, blue: 0.90)
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

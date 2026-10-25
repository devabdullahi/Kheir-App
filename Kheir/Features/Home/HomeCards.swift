import SwiftUI

// MARK: - Home cards
//
// Small cut-paper cards that Home orders by the user's intentions. Each one is a
// single entry point; the screens behind them own their own data.

/// Shared look for the small cards: an overline, a bold line and an optional note.
struct HomeCardLabel: View {
    let overline: String
    let title: String
    var note: String? = nil
    var overlineColor: Color? = nil
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(overline)
                .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(overlineColor ?? Color.adaptiveGold(scheme))
            Text(title)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.adaptiveText(scheme))
                .fixedSize(horizontal: false, vertical: true)
            if let note {
                Text(note)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.adaptiveSecondaryText(scheme))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: Next prayer

struct NextPrayerCard: View {
    let prayerName: String
    let prayerTime: Date?
    let countdown: String
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        NavigationLink(destination: PrayerTimesView()) {
            HStack(spacing: 10) {
                PaperIconView(.forPrayer(prayerName), size: 26)
                HomeCardLabel(
                    overline: "Next prayer",
                    title: prayerName.isEmpty ? "Prayer times" : "\(prayerName) · \(prayerTime.map(HomeFormat.time) ?? "")"
                )
                Text(countdown)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.adaptiveGold(scheme))
                    .contentTransition(.numericText(countsDown: true))
            }
            .cardStyle(scheme, seed: 901)
        }
        .buttonStyle(PaperPressStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(prayerName.isEmpty ? "Prayer times" : "Next prayer \(prayerName), in \(countdown)")
        .accessibilityIdentifier("nextPrayerCard")
    }
}

// MARK: Quran goal

struct QuranGoalCard: View {
    let goal: QuranGoal
    let lastSurah: Int
    let lastAyah: Int
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        NavigationLink(destination: ReadingView(surahNumber: lastSurah, scrollToAyah: lastAyah)) {
            HStack(spacing: 12) {
                PaperIconView(.book, size: 28)
                HomeCardLabel(
                    overline: "Quran · \(goal.title)",
                    title: "Continue at \(lastSurah):\(lastAyah)",
                    note: goalNote
                )
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.adaptiveSecondaryText(scheme))
            }
            .cardStyle(scheme, seed: 902)
        }
        .buttonStyle(PaperPressStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Quran goal: \(goal.title). Continue at surah \(lastSurah), ayah \(lastAyah).")
        .accessibilityIdentifier("quranGoalCard")
    }

    private var goalNote: String {
        switch goal {
        case .oneAyah: "Today: one ayah, read slowly"
        case .onePage: "Today: one page"
        case .tenMinutes: "Today: ten minutes of reading or listening"
        case .finishInMonth: "Today: one juzʾ"
        }
    }
}

// MARK: Reflect

struct ReflectCard: View {
    @Environment(\.colorScheme) private var scheme
    @State private var showJournal = false

    var body: some View {
        Button { showJournal = true } label: {
            HStack(spacing: 10) {
                PaperIconView(.pen, size: 24)
                HomeCardLabel(overline: "Reflect", title: "What brought you ease today?")
            }
            .paperPiece(Color.adaptiveCardElevated(scheme), material: .card, depth: 1, seed: 904)
        }
        .buttonStyle(PaperPressStyle())
        .sheet(isPresented: $showJournal) { JournalView() }
        .accessibilityLabel("Reflect: what brought you ease today? Opens your journal.")
        .accessibilityIdentifier("reflectCard")
    }
}

// MARK: Masjids

struct MasjidCard: View {
    @Environment(\.colorScheme) private var scheme
    @State private var showFinder = false

    var body: some View {
        Button { showFinder = true } label: {
            HStack(spacing: 10) {
                PaperIconView(.masjid, size: 26)
                HomeCardLabel(overline: "Nearby", title: "Find a masjid")
                PaperIconView(.pin, size: 16)
            }
            .cardStyle(scheme, seed: 905)
        }
        .buttonStyle(PaperPressStyle())
        .sheet(isPresented: $showFinder) { MasjidFinderView() }
        .accessibilityLabel("Find a masjid nearby")
        .accessibilityIdentifier("masjidCard")
    }
}

// MARK: Journey cards

/// Shown at the top of Home for someone new to Islam.
struct StartHereCard: View {
    @Environment(\.colorScheme) private var scheme
    @State private var showGuide = false

    var body: some View {
        Button { showGuide = true } label: {
            HStack(spacing: 10) {
                PaperIconView(.star, size: 24)
                HomeCardLabel(
                    overline: "Start here",
                    title: "How to pray, step by step",
                    note: "5 short steps",
                    overlineColor: .paperTerracotta
                )
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.adaptiveSecondaryText(scheme))
            }
            .paperPiece(Color.adaptiveCardSurface(scheme), material: .card, depth: 1.6, seed: 906)
            .rotationEffect(.degrees(-0.6))
        }
        .buttonStyle(PaperPressStyle())
        .sheet(isPresented: $showGuide) { HowToPraySheet() }
        .accessibilityLabel("Start here: how to pray, step by step")
        .accessibilityIdentifier("startHereCard")
    }
}

/// Shown for someone going deeper: today's ayah in its place in the surah.
struct TafsirCard: View {
    let ayah: DailyAyah
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        NavigationLink(destination: ReadingView(surahNumber: ayah.surahNumber, scrollToAyah: ayah.ayahNumber)) {
            HStack(spacing: 10) {
                PaperIconView(.book, size: 22)
                HomeCardLabel(overline: "Go deeper", title: "Tafsir of today’s ayah", note: "\(ayah.surahEnglishName) \(ayah.surahNumber):\(ayah.ayahNumber)")
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.adaptiveSecondaryText(scheme))
            }
            .cardStyle(scheme, seed: 907)
        }
        .buttonStyle(PaperPressStyle())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("tafsirCard")
    }
}

/// A gentle first guide to the prayer. Placeholder until the full lessons exist.
struct HowToPraySheet: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss

    private let steps: [(String, String)] = [
        ("Prepare", "Make wudu, find a clean place and face the Qibla."),
        ("Begin", "Make the intention in your heart, raise your hands and say “Allāhu akbar”."),
        ("Stand and recite", "Recite Al-Fātiḥah, then a short passage of the Quran."),
        ("Bow and prostrate", "Bow (rukūʿ), stand, then prostrate twice (sujūd), saying the remembrances."),
        ("Finish", "Sit for the tashahhud and end by turning your head right and left with “As-salāmu ʿalaykum”.")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    PaperTag(text: "Start here", color: .paperTerracotta, ink: .lightCardSurface, seed: 31)
                    Text("How to pray, step by step")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(Color.adaptiveText(scheme))
                    ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(i + 1)")
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                                .foregroundStyle(Color.lightBodyText)
                                .frame(width: 28, height: 28)
                                .paperPiece(.islamicGold, material: .construction, depth: 0.6, edge: .torn, radius: 14, seed: 60 + i, padding: nil)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(step.0)
                                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                                    .foregroundStyle(Color.adaptiveText(scheme))
                                Text(step.1)
                                    .font(.system(size: 14, design: .rounded))
                                    .foregroundStyle(Color.adaptiveSecondaryText(scheme))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .cardStyle(scheme, seed: 70 + i)
                    }
                    Text("Full lessons with audio are on their way.")
                        .font(.footnote)
                        .foregroundStyle(Color.adaptiveSecondaryText(scheme))
                }
                .padding(20)
            }
            .paperBackground()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Formatting

enum HomeFormat {
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()

    static func time(_ date: Date) -> String { timeFormatter.string(from: date) }

    /// "01:24:10" until `target`, or "--:--:--" when unknown.
    static func countdown(to target: Date?, now: Date = .now) -> String {
        guard let target else { return "--:--:--" }
        let s = max(0, Int(target.timeIntervalSince(now)))
        return String(format: "%02d:%02d:%02d", s / 3600, s % 3600 / 60, s % 60)
    }
}

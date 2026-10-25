import SwiftUI

// MARK: - Home layout pieces
//
// The redesigned Home: the date and the streak on one slim strip, today's five
// prayers as a tracker (the current prayer lifted, prayed ones ticked), and the
// smaller intentions as compact two-up tiles, so the Daily Ayah reaches the fold.

// MARK: Today's prayers

/// Today's five prayers as a tracker. The prayer whose time it is now is lifted on
/// mustard paper (the same "now" the sky names). Tapping a prayer that has begun
/// marks it prayed: the tile lies flat with a green tick. Tap again to undo.
/// Reads the countdown view model itself so the per-second tick stays local.
struct TodayPrayersStrip: View {
    let viewModel: PrayerCountdownViewModel
    @State private var prayed: Set<String> = PrayerLog.prayed(on: .now)
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let prayers = (viewModel.todayPrayerTimes?.all ?? []).filter { PrayerWindow.five.contains($0.name) }
        let _ = viewModel.countdownText   // re-evaluated each tick so "now" moves on time
        let now = PrayerWindow.current(in: viewModel.todayPrayerTimes)
        let highlighted = now ?? prayers.first { $0.time > .now }?.name
        VStack(alignment: .leading, spacing: 10) {
            NavigationLink(destination: PrayerTimesView()) {
                HStack {
                    PaperTag(text: "Today’s prayers", color: Color.islamicGold, ink: Color(hex: "#2B2118"), seed: 905)
                    Spacer()
                    Text("\(prayed.intersection(PrayerWindow.five).count) of 5")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.adaptiveSecondaryText(scheme))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.adaptiveSecondaryText(scheme))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Prayer times. \(prayed.count) of 5 prayed today.")
            .accessibilityIdentifier("nextPrayerCard")

            if prayers.isEmpty {
                Text("Prayer times appear once your location is set.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.adaptiveSecondaryText(scheme))
            } else {
                HStack(spacing: 6) {
                    ForEach(Array(prayers.enumerated()), id: \.offset) { index, prayer in
                        tile(prayer, isNow: prayer.name == highlighted, seed: 910 + index)
                    }
                }
            }
        }
        .cardStyle(scheme, seed: 901)
        .onReceive(NotificationCenter.default.publisher(for: .kheirPrayerMarkedPrayed)) { _ in
            prayed = PrayerLog.prayed(on: .now)
        }
    }

    private func tile(_ prayer: PrayerTime, isNow: Bool, seed: Int) -> some View {
        let done = prayed.contains(prayer.name)
        let begun = prayer.time <= .now
        return Button {
            guard begun else { return }
            if done {
                PrayerLog.unmarkPrayed(prayer.name, on: .now)
            } else {
                PrayerLog.markPrayed(prayer.name, on: .now)
                HapticManager.shared.success()
            }
            withAnimation(.open(0.25)) { prayed = PrayerLog.prayed(on: .now) }
        } label: {
            VStack(spacing: 3) {
                PaperIconView(.forPrayer(prayer.name), size: 22, animated: !done)
                Text(prayer.name)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(prayer.time.formatted(.dateTime.hour(.defaultDigits(amPM: .omitted)).minute()))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .opacity(0.75)
            }
            .foregroundStyle(isNow && !done ? Color(hex: "#2B2118") : Color.adaptiveText(scheme))
            .frame(maxWidth: .infinity)
            .paperPiece(
                isNow && !done ? Color.islamicGold : Color.adaptiveCardElevated(scheme),
                material: .card,
                depth: isNow && !done ? 1.6 : (done ? 0.2 : 0.5),
                radius: 10,
                seed: seed,
                padding: 7
            )
            .opacity(done ? 0.78 : 1)
            .overlay(alignment: .topTrailing) {
                if done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(Color(hex: "#FBF5E8"))
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(Color.lightPrimary))
                        .paperShadow(depth: 0.6)
                        .offset(x: 4, y: -4)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
            }
            .rotationEffect(.degrees(isNow && !done ? -2 : 0))
        }
        .buttonStyle(PaperPressStyle())
        .disabled(!begun)
        .zIndex(isNow ? 1 : 0)
        .accessibilityLabel("\(prayer.name), \(HomeFormat.time(prayer.time))\(done ? ", prayed" : "")\(isNow ? ", now" : "")")
        .accessibilityHint(begun ? (done ? "Double tap to undo" : "Double tap to mark prayed") : "Not yet time")
    }
}

// MARK: Square tiles for the smaller intentions

/// A compact paper tile: icon beside a title and a quiet second line.
struct HomeTile<Destination: View>: View {
    let icon: PaperIcon
    let overline: String
    let title: String
    var note: String? = nil
    let seed: Int
    @ViewBuilder let destination: () -> Destination
    var presentAsSheet = false

    @State private var showSheet = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Group {
            if presentAsSheet {
                Button { showSheet = true } label: { content }
                    .sheet(isPresented: $showSheet) { destination() }
            } else {
                NavigationLink(destination: destination) { content }
            }
        }
        .buttonStyle(PaperPressStyle())
        .accessibilityElement(children: .combine)
    }

    private var content: some View {
        HStack(spacing: 10) {
            PaperIconView(icon, size: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(Color.adaptiveText(scheme))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(note ?? overline)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.adaptiveSecondaryText(scheme))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
        .paperPiece(Color.adaptiveCardSurface(scheme), material: .card, depth: 1, seed: seed, padding: 12)
    }
}

/// The small intentions laid out two-up.
struct IntentionTiles: View {
    let intentions: [Intention]
    private var settings: AppSettings { .shared }

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(intentions, id: \.self) { tile(for: $0) }
        }
    }

    @ViewBuilder
    private func tile(for intention: Intention) -> some View {
        switch intention {
        case .readQuran:
            HomeTile(icon: .book, overline: "Quran", title: "Continue at \(settings.lastReadSurah):\(settings.lastReadAyah)", note: settings.quranGoal.title, seed: 930) {
                ReadingView(surahNumber: settings.lastReadSurah, scrollToAyah: settings.lastReadAyah)
            }
        case .journal:
            HomeTile(icon: .pen, overline: "Reflect", title: "Journal", note: "Reflect on today", seed: 931, destination: { JournalView() }, presentAsSheet: true)
        case .masjids:
            HomeTile(icon: .masjid, overline: "Nearby", title: "Find a masjid", seed: 932, destination: { MasjidFinderView() }, presentAsSheet: true)
        case .prayOnTime, .adhkar:
            EmptyView()
        }
    }
}

// MARK: Prayer window

/// "Now" on Home: the prayer whose time has begun and not yet ended. Fajr ends at
/// sunrise (between sunrise and Dhuhr no prayer is current); the others run until
/// the next prayer begins. The sky and the tiles both read from here.
enum PrayerWindow {
    static let five = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]

    static func current(in times: DayPrayerTimes?, at now: Date = .now) -> String? {
        guard let times else { return nil }
        if now >= times.fajr && now < times.sunrise { return "Fajr" }
        if now >= times.isha { return "Isha" }
        if now >= times.maghrib { return "Maghrib" }
        if now >= times.asr { return "Asr" }
        if now >= times.dhuhr { return "Dhuhr" }
        return nil
    }

    /// The sky's caption under the countdown.
    static func caption(times: DayPrayerTimes?, nextName: String, nextTime: Date?) -> String {
        let at = nextTime.map { " · \(HomeFormat.time($0))" } ?? ""
        switch current(in: times) {
        case "Fajr": return "left to pray Fajr · sunrise\(at)"
        case let name?: return "\(name) now · \(nextName)\(at)"
        case nil: return "until \(nextName)\(at)"
        }
    }
}

// MARK: Hijri date

enum HijriLabel {
    private static let months = [
        "Muḥarram", "Ṣafar", "Rabīʿ al-Awwal", "Rabīʿ al-Ākhir", "Jumādā al-Ūlā", "Jumādā al-Ākhirah",
        "Rajab", "Shaʿbān", "Ramaḍān", "Shawwāl", "Dhū al-Qaʿdah", "Dhū al-Ḥijjah",
    ]

    /// "14 Jumādā al-Ūlā 1448" (Umm al-Qura calendar).
    static func string(for date: Date = .now) -> String {
        let calendar = Calendar(identifier: .islamicUmmAlQura)
        let parts = calendar.dateComponents([.day, .month, .year], from: date)
        guard let day = parts.day, let month = parts.month, let year = parts.year, (1...12).contains(month) else { return "" }
        return "\(day) \(months[month - 1]) \(year)"
    }
}

// MARK: Day strip

/// The date and the streak on one slim strip: the Hijri date leads, the Gregorian
/// date is a quiet second line, today's flower on the left, the streak palm on the right.
struct DayStrip: View {
    let streakData: StreakData?
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let flower = DailyFlower.forDate(.now)
        HStack(spacing: 10) {
            DailyFlowerView(date: .now, size: 30)
                .frame(width: 36, height: 40)
                .accessibilityLabel("Today's flower: \(flower.species.name)")
            VStack(alignment: .leading, spacing: 1) {
                Text(HijriLabel.string())
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(Color.adaptiveText(scheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text("\(Date.now.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))) · \(flower.species.name)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.adaptiveSecondaryText(scheme))
            }
            Spacer(minLength: 6)
            if let streakData {
                HStack(spacing: 4) {
                    StreakPlantView(days: streakData.currentStreak, size: 48)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(streakData.currentStreak == 1 ? "1 day" : "\(streakData.currentStreak) days")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundStyle(Color.adaptiveText(scheme))
                        Text("growing")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.adaptiveSecondaryText(scheme))
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Daily streak: \(streakData.currentStreak) days")
            }
        }
        .paperPiece(Color.adaptiveCardSurface(scheme), material: .card, depth: 1, seed: 41, padding: 12)
        .rotationEffect(.degrees(-0.3))
    }
}

// MARK: Full hadith

/// The whole hadith on a sheet of paper: English, then Arabic, then the source.
struct HadithSheet: View {
    let hadith: DailyHadith
    @Environment(\.colorScheme) private var scheme
    private var settings: AppSettings { .shared }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PaperTag(text: "Daily Hadith", color: .paperRose, ink: .lightBodyText, seed: 6)
                Text(hadith.text)
                    .font(.system(size: 17, design: .rounded))
                    .lineSpacing(4)
                    .foregroundStyle(Color.adaptiveText(scheme))
                    .textSelection(.enabled)
                if !hadith.arabicText.isEmpty {
                    Text(hadith.arabicText)
                        .arabicFont(size: CGFloat(settings.arabicFontSize))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(Color.adaptiveText(scheme))
                        .textSelection(.enabled)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(hadith.source)
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.adaptivePrimary(scheme))
                    if !hadith.narrator.isEmpty {
                        Text("Narrated by \(hadith.narrator)")
                            .font(.system(size: 13.5, design: .rounded))
                            .foregroundStyle(Color.adaptiveSecondaryText(scheme))
                    }
                }
                if !hadith.grade.isEmpty, hadith.grade.lowercased() != "unknown" {
                    PaperTag(text: "Grade: \(hadith.grade)", color: Color(hex: "#7FAE7A"), ink: .lightBodyText, seed: 7)
                }
            }
            .padding(24)
        }
        .paperBackground()
    }
}

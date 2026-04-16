import Foundation
import Combine
import CoreLocation
import SwiftUI
import UIKit
import WidgetKit

// MARK: - Load State

enum ContentLoadState {
    case loading
    case loaded
    case failed
    case offline
}

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var dailyAyah: DailyAyah?
    @Published var dailyHadith: DailyHadith?
    @Published var nextPrayerName: String = ""
    @Published var nextPrayerTime: Date?
    @Published var countdownText: String = "--:--:--"
    @Published var hijriDate: String = ""
    @Published var gregorianDate: String = ""
    @Published var isLoading = false
    @Published var ayahState: ContentLoadState = .loading
    @Published var hadithState: ContentLoadState = .loading

    private var timer: Timer?
    private var midnightObserver: NSObjectProtocol?
    private let cache: any CacheManaging
    private let apiService: any AyahFetching & HadithFetching
    private let locationService: LocationService
    private let prayerTimesService: PrayerTimesService
    private let settings: AppSettings

    init(
        apiService: any AyahFetching & HadithFetching = APIService.shared,
        cacheManager: any CacheManaging = CacheManager.shared,
        locationService: LocationService = .shared,
        prayerTimesService: PrayerTimesService = .shared,
        settings: AppSettings = .shared
    ) {
        self.apiService = apiService
        self.cache = cacheManager
        self.locationService = locationService
        self.prayerTimesService = prayerTimesService
        self.settings = settings
        let today = Date()
        gregorianDate = today.gregorianString
        hijriDate = today.hijriString
    }

    func onAppear() {
        Task { await loadDailyContent() }
        loadPrayerCountdown()
        startCountdownTimer()
        subscribeMidnightRollover()
    }

    func onDisappear() {
        timer?.invalidate()
        if let observer = midnightObserver {
            NotificationCenter.default.removeObserver(observer)
            midnightObserver = nil
        }
    }

    // MARK: - Refresh (bypasses date-guard)

    func refresh() async {
        let today = currentDayKey()
        isLoading = true
        ayahState = .loading
        hadithState = .loading
        async let ayahFetch: Void = fetchDailyAyah(dateKey: today, forceRefresh: true)
        async let hadithFetch: Void = fetchDailyHadith(dateKey: today, forceRefresh: true)
        _ = await (ayahFetch, hadithFetch)
        isLoading = false
    }

    // MARK: - Daily Content

    /// Returns today's cache key using the device-local timezone (YYYY-MM-DD).
    private static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone.current
        return f
    }()

    private func currentDayKey() -> String {
        Self.dayKeyFormatter.string(from: Date())
    }

    func loadDailyContent() async {
        let today = currentDayKey()

        // Load cached first — update state immediately if available
        if let cached = cache.loadDailyAyah(for: today) {
            dailyAyah = cached
            ayahState = .loaded
            syncAyahToWidget(cached)
        }
        if let cached = cache.loadDailyHadith(for: today) {
            dailyHadith = cached
            hadithState = .loaded
        }

        // Fetch fresh — parallel
        isLoading = true
        async let ayahFetch: Void = fetchDailyAyah(dateKey: today, forceRefresh: false)
        async let hadithFetch: Void = fetchDailyHadith(dateKey: today, forceRefresh: false)
        _ = await (ayahFetch, hadithFetch)
        isLoading = false
    }

    private func fetchDailyAyah(dateKey: String, forceRefresh: Bool) async {
        guard forceRefresh || dailyAyah == nil || dailyAyah?.dateString != dateKey else {
            ayahState = .loaded
            return
        }
        ayahState = .loading
        do {
            // First fetch arabic to get the ayah number, then fetch translation
            let arabic = try await apiService.fetchRandomAyah(edition: "quran-uthmani")
            let translation = try await apiService.fetchAyahTranslation(
                number: arabic.number,
                edition: settings.translationLanguage.rawValue
            )
            // Note: these must be sequential since translation needs arabic.number

            let ayah = DailyAyah(
                surahNumber: translation.surah.number,
                surahName: translation.surah.name,
                surahEnglishName: translation.surah.englishName,
                ayahNumber: translation.numberInSurah,
                arabicText: arabic.text,
                translationText: translation.text,
                transliteration: "",
                dateString: dateKey
            )
            dailyAyah = ayah
            ayahState = .loaded
            cache.cacheDailyAyah(ayah)
            syncAyahToWidget(ayah)
        } catch {
            print("Daily Ayah fetch error: \(error)")
            ayahState = dailyAyah != nil ? .offline : .failed
        }
    }

    private func fetchDailyHadith(dateKey: String, forceRefresh: Bool) async {
        guard forceRefresh || dailyHadith == nil || dailyHadith?.dateString != dateKey else {
            hadithState = .loaded
            return
        }
        hadithState = .loading
        do {
            let (entry, collection, sectionName) = try await apiService.fetchRandomHadith()

            let grade = entry.grades.first?.grade ?? "Unknown"
            let hadith = DailyHadith(
                text: entry.text,
                source: collection.displayName,
                chapter: sectionName,
                narrator: "",
                grade: grade,
                dateString: dateKey
            )
            dailyHadith = hadith
            hadithState = .loaded
            cache.cacheDailyHadith(hadith)
        } catch {
            print("Daily Hadith fetch error: \(error). Using fallback.")
            let fallbackHadiths = [
                DailyHadith(text: "The best among you are those who have the best manners and character.", source: "Sahih al-Bukhari", chapter: "Good Manners", narrator: "Abdullah ibn Amr", grade: "Sahih", dateString: dateKey),
                DailyHadith(text: "None of you truly believes until he loves for his brother what he loves for himself.", source: "Sahih al-Bukhari", chapter: "Faith", narrator: "Anas ibn Malik", grade: "Sahih", dateString: dateKey),
                DailyHadith(text: "The strong man is not the one who can overpower others. Rather, the strong man is the one who controls himself when he is angry.", source: "Sahih al-Bukhari", chapter: "Good Manners", narrator: "Abu Hurairah", grade: "Sahih", dateString: dateKey),
                DailyHadith(text: "Whoever believes in Allah and the Last Day, let him speak good or remain silent.", source: "Sahih al-Bukhari", chapter: "Good Manners", narrator: "Abu Hurairah", grade: "Sahih", dateString: dateKey),
                DailyHadith(text: "Make things easy and do not make them difficult, cheer the people up and do not put them off.", source: "Sahih al-Bukhari", chapter: "Knowledge", narrator: "Anas ibn Malik", grade: "Sahih", dateString: dateKey),
            ]
            let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
            let hadith = fallbackHadiths[dayOfYear % fallbackHadiths.count]
            dailyHadith = hadith
            hadithState = .offline
            cache.cacheDailyHadith(hadith)
        }
    }

    // MARK: - Prayer Countdown
    private func loadPrayerCountdown() {
        guard let location = locationService.currentLocation else {
            // Try loading after a delay
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if let loc = locationService.currentLocation {
                    await updateNextPrayer(location: loc)
                }
            }
            return
        }
        Task {
            await updateNextPrayer(location: location)
        }
    }

    private func updateNextPrayer(location: CLLocationCoordinate2D) async {
        guard let times = await prayerTimesService.fetchPrayerTimes(
            coordinate: location,
            method: settings.calculationMethod,
            madhab: settings.madhab
        ) else { return }

        let now = Date()
        let allTimes = times.all
        if let next = allTimes.first(where: { $0.time > now }) {
            nextPrayerName = next.name
            nextPrayerTime = next.time
        } else {
            // All prayers passed, show next Fajr
            nextPrayerName = "Fajr"
            nextPrayerTime = Calendar.current.date(byAdding: .day, value: 1, to: times.fajr)
        }
    }

    private func startCountdownTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let target = self.nextPrayerTime else { return }
                self.countdownText = Date().timeRemaining(to: target)
                if target <= Date() {
                    self.loadPrayerCountdown()
                }
            }
        }
    }

    // MARK: - Midnight Rollover

    /// Subscribes to significant time changes (DST, date rollover at device-local midnight).
    /// On fire, clears stale cached daily content and reloads for the new date.
    private func subscribeMidnightRollover() {
        midnightObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.significantTimeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let today = Date()
                self.gregorianDate = today.gregorianString
                self.hijriDate = today.hijriString
                // Nil out stale content so the date-guard in fetchDailyX triggers
                self.dailyAyah = nil
                self.dailyHadith = nil
                await self.loadDailyContent()
                self.loadPrayerCountdown()
            }
        }
    }

    // MARK: - Retry

    func retryAyah() async {
        ayahState = .loading
        let today = currentDayKey()
        await fetchDailyAyah(dateKey: today, forceRefresh: true)
    }

    func retryHadith() async {
        hadithState = .loading
        let today = currentDayKey()
        await fetchDailyHadith(dateKey: today, forceRefresh: true)
    }

    // MARK: - Bookmarking
    @Published var isAyahBookmarked = false
    @Published var isHadithBookmarked = false

    func checkBookmarkStates() {
        if let ayah = dailyAyah {
            isAyahBookmarked = cache.isAyahBookmarked(surah: ayah.surahNumber, ayah: ayah.ayahNumber)
        }
        if let hadith = dailyHadith {
            isHadithBookmarked = cache.isHadithBookmarked(text: hadith.text, source: hadith.source)
        }
    }

    func toggleAyahBookmark() {
        guard let ayah = dailyAyah else { return }
        if isAyahBookmarked {
            cache.removeAyahBookmark(surah: ayah.surahNumber, ayah: ayah.ayahNumber)
        } else {
            let bookmark = BookmarkedAyah(
                surahNumber: ayah.surahNumber,
                surahName: ayah.surahEnglishName,
                ayahNumber: ayah.ayahNumber,
                arabicText: ayah.arabicText,
                translationText: ayah.translationText
            )
            cache.saveAyahBookmark(bookmark)
        }
        isAyahBookmarked.toggle()
    }

    func toggleHadithBookmark() {
        guard let hadith = dailyHadith else { return }
        if isHadithBookmarked {
            cache.removeHadithBookmark(text: hadith.text, source: hadith.source)
        } else {
            let bookmark = BookmarkedHadith(
                text: hadith.text,
                source: hadith.source,
                narrator: hadith.narrator,
                grade: hadith.grade
            )
            cache.saveHadithBookmark(bookmark)
        }
        isHadithBookmarked.toggle()
    }

    // MARK: - Share
    func shareAyahText() -> String {
        guard let ayah = dailyAyah else { return "" }
        return """
        \(ayah.arabicText)

        \(ayah.translationText)

        - \(ayah.surahEnglishName) (\(ayah.surahNumber):\(ayah.ayahNumber))
        """
    }

    func shareHadithText() -> String {
        guard let hadith = dailyHadith else { return "" }
        var text = """
        \(hadith.text)

        - \(hadith.source)
        """
        if !hadith.narrator.isEmpty {
            text += "\nNarrated by \(hadith.narrator)"
        }
        text += "\nGrade: \(hadith.grade)"
        return text
    }

    // MARK: - Widget Sync

    private func syncAyahToWidget(_ ayah: DailyAyah) {
        guard let defaults = UserDefaults(suiteName: "group.com.kheir.shared") else { return }
        defaults.set(ayah.arabicText, forKey: "widget_ayah_arabic")
        defaults.set(ayah.translationText, forKey: "widget_ayah_translation")
        defaults.set(ayah.surahName, forKey: "widget_ayah_surah")
        defaults.set("\(ayah.surahEnglishName) \(ayah.surahNumber):\(ayah.ayahNumber)", forKey: "widget_ayah_ref")
        WidgetCenter.shared.reloadTimelines(ofKind: "DailyAyahWidget")
    }
}

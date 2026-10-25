import Foundation
import SwiftUI
import Observation

/// App-wide user preferences backed by `UserDefaults.standard`.
///
/// `@AppStorage` cannot be used inside an `@Observable` class, so each property
/// is a plain stored value that is hydrated from `UserDefaults` in `init` and
/// written back in `didSet`. Keys and defaults match the previous `@AppStorage`
/// declarations so existing user data carries over unchanged.
@MainActor
@Observable
final class AppSettings {
    static let shared = AppSettings()

    @ObservationIgnored private let defaults: UserDefaults

    // MARK: - Display
    var appTheme: AppTheme = .system {
        didSet { defaults.set(appTheme.rawValue, forKey: "appTheme") }
    }
    var arabicFontSize: Double = 28 {
        didSet { defaults.set(arabicFontSize, forKey: "arabicFontSize") }
    }
    var showTransliteration: Bool = true {
        didSet { defaults.set(showTransliteration, forKey: "showTransliteration") }
    }

    // MARK: - Quran
    var translationLanguage: TranslationLanguage = .english {
        didSet { defaults.set(translationLanguage.rawValue, forKey: "translationLanguage") }
    }
    var selectedQari: String = "ar.alafasy" {
        didSet { defaults.set(selectedQari, forKey: "selectedQari") }
    }

    // MARK: - Prayer Times
    var calculationMethod: CalculationMethodOption = .muslimWorldLeague {
        didSet { defaults.set(calculationMethod.rawValue, forKey: "calculationMethod") }
    }
    var madhab: MadhabOption = .shafi {
        didSet { defaults.set(madhab.rawValue, forKey: "madhab") }
    }
    var fajrNotification: Bool = true {
        didSet { defaults.set(fajrNotification, forKey: "fajrNotification") }
    }
    var sunriseNotification: Bool = false {
        didSet { defaults.set(sunriseNotification, forKey: "sunriseNotification") }
    }
    var dhuhrNotification: Bool = true {
        didSet { defaults.set(dhuhrNotification, forKey: "dhuhrNotification") }
    }
    var asrNotification: Bool = true {
        didSet { defaults.set(asrNotification, forKey: "asrNotification") }
    }
    var maghribNotification: Bool = true {
        didSet { defaults.set(maghribNotification, forKey: "maghribNotification") }
    }
    var ishaNotification: Bool = true {
        didSet { defaults.set(ishaNotification, forKey: "ishaNotification") }
    }
    var azanSound: String = "azan_makkah" {
        didSet { defaults.set(azanSound, forKey: "azanSound") }
    }

    // MARK: - Location
    var useAutoLocation: Bool = true {
        didSet { defaults.set(useAutoLocation, forKey: "useAutoLocation") }
    }
    var manualCity: String = "" {
        didSet { defaults.set(manualCity, forKey: "manualCity") }
    }
    var distanceUnit: DistanceUnit = .kilometers {
        didSet { defaults.set(distanceUnit.rawValue, forKey: "distanceUnit") }
    }

    // MARK: - Reading Position
    var lastReadSurah: Int = 1 {
        didSet { defaults.set(lastReadSurah, forKey: "lastReadSurah") }
    }
    var lastReadAyah: Int = 1 {
        didSet { defaults.set(lastReadAyah, forKey: "lastReadAyah") }
    }

    // MARK: - Personalisation (set during onboarding, editable in Settings)
    var userName: String = "" {
        didSet { defaults.set(userName, forKey: "userName") }
    }
    var journey: Journey = .praying {
        didSet { defaults.set(journey.rawValue, forKey: "journey") }
    }
    /// What the user asked Kheir to help with; decides the order of cards on Home.
    var intentions: Set<Intention> = [.prayOnTime, .readQuran] {
        didSet { defaults.set(intentions.map(\.rawValue).sorted(), forKey: "intentions") }
    }
    var arabicLevel: ArabicLevel = .learning {
        didSet {
            defaults.set(arabicLevel.rawValue, forKey: "arabicLevel")
            showTransliteration = arabicLevel != .fluent
        }
    }
    var quranGoal: QuranGoal = .onePage {
        didSet { defaults.set(quranGoal.rawValue, forKey: "quranGoal") }
    }
    /// Minutes before Fajr for the gentle wake-up; `nil` means off.
    var fajrWakeOffset: Int? = nil {
        didSet { defaults.set(fajrWakeOffset ?? -1, forKey: "fajrWakeOffset") }
    }
    var morningAdhkarMinutes: Int = 6 * 60 + 20 {
        didSet { defaults.set(morningAdhkarMinutes, forKey: "morningAdhkarMinutes") }
    }
    var eveningAdhkarBeforeMaghrib: Int = 30 {
        didSet { defaults.set(eveningAdhkarBeforeMaghrib, forKey: "eveningAdhkarBeforeMaghrib") }
    }
    var adhkarRemindersOn: Bool = false {
        didSet { defaults.set(adhkarRemindersOn, forKey: "adhkarRemindersOn") }
    }
    var weeklyReminders: Set<WeeklyReminder> = [.alKahf, .jumuah, .ramadan] {
        didSet { defaults.set(weeklyReminders.map(\.rawValue).sorted(), forKey: "weeklyReminders") }
    }
    /// People the user wants to remember in dua. Stays on device.
    var duaNames: [DuaName] = [] {
        didSet { defaults.set(try? JSONEncoder().encode(duaNames), forKey: "duaNames") }
    }
    /// Paper sound effects (the eraser and pencil in onboarding page turns).
    var soundEffects: Bool = true {
        didSet { defaults.set(soundEffects, forKey: "soundEffects") }
    }
    /// Back up progress to iCloud so it returns on a new iPhone.
    var iCloudBackup: Bool = false {
        didSet { defaults.set(iCloudBackup, forKey: "iCloudBackup") }
    }

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Hydrate from persisted values. Once `defaults` is set every property is
        // initialized, so these assignments go through `didSet` and re-write the
        // same value — harmless, and it keeps a single code path for persistence.
        if let raw = defaults.string(forKey: "appTheme"), let value = AppTheme(rawValue: raw) { appTheme = value }
        if defaults.object(forKey: "arabicFontSize") != nil { arabicFontSize = defaults.double(forKey: "arabicFontSize") }
        if defaults.object(forKey: "showTransliteration") != nil { showTransliteration = defaults.bool(forKey: "showTransliteration") }
        if let raw = defaults.string(forKey: "translationLanguage"), let value = TranslationLanguage(rawValue: raw) { translationLanguage = value }
        if let value = defaults.string(forKey: "selectedQari") { selectedQari = value }
        if let raw = defaults.string(forKey: "calculationMethod"), let value = CalculationMethodOption(rawValue: raw) { calculationMethod = value }
        if let raw = defaults.string(forKey: "madhab"), let value = MadhabOption(rawValue: raw) { madhab = value }
        if defaults.object(forKey: "fajrNotification") != nil { fajrNotification = defaults.bool(forKey: "fajrNotification") }
        if defaults.object(forKey: "sunriseNotification") != nil { sunriseNotification = defaults.bool(forKey: "sunriseNotification") }
        if defaults.object(forKey: "dhuhrNotification") != nil { dhuhrNotification = defaults.bool(forKey: "dhuhrNotification") }
        if defaults.object(forKey: "asrNotification") != nil { asrNotification = defaults.bool(forKey: "asrNotification") }
        if defaults.object(forKey: "maghribNotification") != nil { maghribNotification = defaults.bool(forKey: "maghribNotification") }
        if defaults.object(forKey: "ishaNotification") != nil { ishaNotification = defaults.bool(forKey: "ishaNotification") }
        if let value = defaults.string(forKey: "azanSound") { azanSound = value }
        if defaults.object(forKey: "useAutoLocation") != nil { useAutoLocation = defaults.bool(forKey: "useAutoLocation") }
        if let value = defaults.string(forKey: "manualCity") { manualCity = value }
        if let raw = defaults.string(forKey: "distanceUnit"), let value = DistanceUnit(rawValue: raw) { distanceUnit = value }
        if defaults.object(forKey: "lastReadSurah") != nil { lastReadSurah = defaults.integer(forKey: "lastReadSurah") }
        if defaults.object(forKey: "lastReadAyah") != nil { lastReadAyah = defaults.integer(forKey: "lastReadAyah") }
        if let value = defaults.string(forKey: "userName") { userName = value }
        if let raw = defaults.string(forKey: "journey"), let value = Journey(rawValue: raw) { journey = value }
        if let raw = defaults.stringArray(forKey: "intentions") { intentions = Set(raw.compactMap(Intention.init(rawValue:))) }
        if let raw = defaults.string(forKey: "arabicLevel"), let value = ArabicLevel(rawValue: raw) { arabicLevel = value }
        if let raw = defaults.string(forKey: "quranGoal"), let value = QuranGoal(rawValue: raw) { quranGoal = value }
        if defaults.object(forKey: "fajrWakeOffset") != nil { let v = defaults.integer(forKey: "fajrWakeOffset"); fajrWakeOffset = v < 0 ? nil : v }
        if defaults.object(forKey: "morningAdhkarMinutes") != nil { morningAdhkarMinutes = defaults.integer(forKey: "morningAdhkarMinutes") }
        if defaults.object(forKey: "eveningAdhkarBeforeMaghrib") != nil { eveningAdhkarBeforeMaghrib = defaults.integer(forKey: "eveningAdhkarBeforeMaghrib") }
        if defaults.object(forKey: "adhkarRemindersOn") != nil { adhkarRemindersOn = defaults.bool(forKey: "adhkarRemindersOn") }
        if let raw = defaults.stringArray(forKey: "weeklyReminders") { weeklyReminders = Set(raw.compactMap(WeeklyReminder.init(rawValue:))) }
        if let data = defaults.data(forKey: "duaNames"), let value = try? JSONDecoder().decode([DuaName].self, from: data) { duaNames = value }
        if defaults.object(forKey: "soundEffects") != nil { soundEffects = defaults.bool(forKey: "soundEffects") }
        if defaults.object(forKey: "iCloudBackup") != nil { iCloudBackup = defaults.bool(forKey: "iCloudBackup") }
    }
}

// MARK: - Enums
enum AppTheme: String, CaseIterable {
    /// Light (kraft), Dark (night indigo), System, or Sky: light from Fajr to Maghrib, dark after.
    case dark, light, system, sky
    var displayName: String {
        switch self {
        case .light: return "Kraft"
        case .dark: return "Night"
        case .system: return "System"
        case .sky: return "Follow the sky"
        }
    }
    /// Fixed scheme, or `nil` to follow the system. `.sky` is resolved against prayer times by the caller.
    var colorScheme: ColorScheme? {
        switch self {
        case .dark: return .dark
        case .light: return .light
        case .system, .sky: return nil
        }
    }
}

// MARK: - Personalisation
enum Journey: String, CaseIterable, Codable {
    case newToIslam, returning, praying, deeper
    var title: String {
        switch self {
        case .newToIslam: "New to Islam"
        case .returning: "Coming back to it"
        case .praying: "Praying daily"
        case .deeper: "Going deeper"
        }
    }
}

enum Intention: String, CaseIterable, Codable {
    case prayOnTime, readQuran, adhkar, journal, masjids
    var title: String {
        switch self {
        case .prayOnTime: "Pray on time"
        case .readQuran: "Read more Quran"
        case .adhkar: "Morning & evening adhkar"
        case .journal: "Reflect & journal"
        case .masjids: "Find masjids nearby"
        }
    }
}

enum ArabicLevel: String, CaseIterable, Codable {
    case fluent, learning, notYet
    var title: String {
        switch self {
        case .fluent: "Fluent"
        case .learning: "Learning"
        case .notYet: "Not yet"
        }
    }
}

enum QuranGoal: String, CaseIterable, Codable {
    case oneAyah, onePage, tenMinutes, finishInMonth
    var title: String {
        switch self {
        case .oneAyah: "1 ayah a day"
        case .onePage: "1 page a day"
        case .tenMinutes: "10 minutes a day"
        case .finishInMonth: "Finish in 30 days"
        }
    }
}

enum WeeklyReminder: String, CaseIterable, Codable {
    case alKahf, jumuah, mondayThursdayFasts, whiteDays, ramadan
    var title: String {
        switch self {
        case .alKahf: "Surah Al-Kahf"
        case .jumuah: "Jumuʿah"
        case .mondayThursdayFasts: "Monday & Thursday fasts"
        case .whiteDays: "White Days fasts"
        case .ramadan: "Ramadan & Eid"
        }
    }
}

struct DuaName: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var note: String = ""
}

enum TranslationLanguage: String, CaseIterable {
    case english = "en.asad"
    case urdu = "ur.jalandhry"
    case french = "fr.hamidullah"
    case turkish = "tr.ates"
    case indonesian = "id.indonesian"
    case bangla = "bn.bengali"
    case spanish = "es.cortes"
    case german = "de.aburida"

    var displayName: String {
        switch self {
        case .english: return "English"
        case .urdu: return "Urdu"
        case .french: return "French"
        case .turkish: return "Turkish"
        case .indonesian: return "Indonesian"
        case .bangla: return "Bangla"
        case .spanish: return "Spanish"
        case .german: return "German"
        }
    }
}

enum CalculationMethodOption: String, CaseIterable {
    case muslimWorldLeague = "MWL"
    case isna = "ISNA"
    case egyptian = "Egyptian"
    case karachi = "Karachi"
    case ummAlQura = "UmmAlQura"
    case gulf = "Gulf"
    case qatar = "Qatar"

    var displayName: String {
        switch self {
        case .muslimWorldLeague: return "Muslim World League"
        case .isna: return "ISNA"
        case .egyptian: return "Egyptian"
        case .karachi: return "Karachi"
        case .ummAlQura: return "Umm al-Qura"
        case .gulf: return "Gulf"
        case .qatar: return "Qatar"
        }
    }
}

enum MadhabOption: String, CaseIterable {
    case shafi = "Shafi"
    case hanafi = "Hanafi"
}

enum DistanceUnit: String, CaseIterable {
    case kilometers = "km"
    case miles = "mi"
    var displayName: String {
        switch self {
        case .kilometers: return "Kilometers"
        case .miles: return "Miles"
        }
    }
}

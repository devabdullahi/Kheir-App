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
    }
}

// MARK: - Enums
enum AppTheme: String, CaseIterable {
    case dark, light, system
    var displayName: String {
        rawValue.capitalized
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .dark: return .dark
        case .light: return .light
        case .system: return nil
        }
    }
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

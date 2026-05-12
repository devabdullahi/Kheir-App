import Foundation
import SwiftUI
import Combine

@MainActor
class AppSettings: ObservableObject {
    static let shared = AppSettings()

    // MARK: - Display
    @AppStorage("appTheme") var appTheme: AppTheme = .system
    @AppStorage("arabicFontSize") var arabicFontSize: Double = 28
    @AppStorage("showTransliteration") var showTransliteration: Bool = true

    // MARK: - Quran
    @AppStorage("translationLanguage") var translationLanguage: TranslationLanguage = .english
    @AppStorage("selectedQari") var selectedQari: String = "ar.alafasy"

    // MARK: - Prayer Times
    @AppStorage("calculationMethod") var calculationMethod: CalculationMethodOption = .muslimWorldLeague
    @AppStorage("madhab") var madhab: MadhabOption = .shafi
    @AppStorage("fajrNotification") var fajrNotification: Bool = true
    @AppStorage("sunriseNotification") var sunriseNotification: Bool = false
    @AppStorage("dhuhrNotification") var dhuhrNotification: Bool = true
    @AppStorage("asrNotification") var asrNotification: Bool = true
    @AppStorage("maghribNotification") var maghribNotification: Bool = true
    @AppStorage("ishaNotification") var ishaNotification: Bool = true
    @AppStorage("azanSound") var azanSound: String = "azan_makkah"

    // MARK: - Location
    @AppStorage("useAutoLocation") var useAutoLocation: Bool = true
    @AppStorage("manualCity") var manualCity: String = ""
    @AppStorage("distanceUnit") var distanceUnit: DistanceUnit = .kilometers

    // MARK: - Reading Position
    @AppStorage("lastReadSurah") var lastReadSurah: Int = 1
    @AppStorage("lastReadAyah") var lastReadAyah: Int = 1

    private init() {}
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

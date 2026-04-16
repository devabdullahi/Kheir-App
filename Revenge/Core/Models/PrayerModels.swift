import Foundation

struct PrayerTime: Identifiable {
    let id = UUID()
    let name: String
    let time: Date
    let icon: String
    var isNext: Bool = false

    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: time)
    }
}

struct DayPrayerTimes {
    let fajr: Date
    let sunrise: Date
    let dhuhr: Date
    let asr: Date
    let maghrib: Date
    let isha: Date

    var all: [PrayerTime] {
        [
            PrayerTime(name: "Fajr", time: fajr, icon: "sunrise"),
            PrayerTime(name: "Sunrise", time: sunrise, icon: "sun.and.horizon"),
            PrayerTime(name: "Dhuhr", time: dhuhr, icon: "sun.max"),
            PrayerTime(name: "Asr", time: asr, icon: "sun.min"),
            PrayerTime(name: "Maghrib", time: maghrib, icon: "sunset"),
            PrayerTime(name: "Isha", time: isha, icon: "moon.stars")
        ]
    }
}

// MARK: - Aladhan API Fallback Response
struct AladhanResponse: Codable {
    let code: Int
    let data: AladhanData
}

struct AladhanData: Codable {
    let timings: AladhanTimings
    let date: AladhanDate
}

struct AladhanTimings: Codable {
    let Fajr: String
    let Sunrise: String
    let Dhuhr: String
    let Asr: String
    let Maghrib: String
    let Isha: String
}

struct AladhanDate: Codable {
    let hijri: HijriDate
}

struct HijriDate: Codable {
    let date: String
    let day: String
    let month: HijriMonth
    let year: String
}

struct HijriMonth: Codable {
    let number: Int
    let en: String
    let ar: String
}

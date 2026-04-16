import Foundation
import CoreLocation

enum AppConstants {
    static let kaabaCoordinate = CLLocationCoordinate2D(latitude: 21.4225, longitude: 39.8262)
    static let quranBaseURL = "https://api.alquran.cloud/v1"
    /// Base URL for ayah audio. Append `/{bitrate}/{edition}/{globalAyahNumber}.mp3`.
    static let audioBaseURL = "https://cdn.islamic.network/quran/audio"
    static let aladhanBaseURL = "https://api.aladhan.com/v1"
    static let hadithBaseURL = "https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1"
    static let totalSurahs = 114
    static let maxNotifications = 64
    static let notificationDaysAhead = 7
}

import Foundation
import CoreLocation

// MARK: - Adhan Integration
//
// SETUP (one-time, in Xcode):
//   File > Add Package Dependencies...
//   URL: https://github.com/batoulapps/adhan-swift
//   Version: Up to Next Major from 1.4.0
//   Add product "Adhan" to the Revenge target.
//
// Once added, the #if canImport(Adhan) block below activates automatically,
// replacing the DST-unsafe local solar fallback with Adhan's accurate calculation.

#if canImport(Adhan)
import Adhan
#endif

final class PrayerTimesService: @unchecked Sendable {
    static let shared = PrayerTimesService()
    private init() {}

    /// Fetches prayer times for the given coordinate and date.
    /// Primary source: Aladhan API (network).
    /// Offline fallback: Adhan Swift library (accurate, DST-safe) when imported;
    /// otherwise the legacy local solar approximation.
    func fetchPrayerTimes(
        coordinate: CLLocationCoordinate2D,
        date: Date = Date(),
        method: CalculationMethodOption = .muslimWorldLeague,
        madhab: MadhabOption = .shafi
    ) async -> DayPrayerTimes? {
        // Try API first
        do {
            let methodInt = apiMethodNumber(for: method)
            let data = try await APIService.shared.fetchPrayerTimes(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                method: methodInt
            )
            return parsePrayerTimes(data.timings, date: date)
        } catch {
            print("Prayer times API error: \(error)")
            return calculateOfflinePrayerTimes(coordinate: coordinate, date: date, method: method, madhab: madhab)
        }
    }

    private func parsePrayerTimes(_ timings: AladhanTimings, date: Date) -> DayPrayerTimes? {
        guard let fajr = Date.fromTimeString(timings.Fajr, on: date),
              let sunrise = Date.fromTimeString(timings.Sunrise, on: date),
              let dhuhr = Date.fromTimeString(timings.Dhuhr, on: date),
              let asr = Date.fromTimeString(timings.Asr, on: date),
              let maghrib = Date.fromTimeString(timings.Maghrib, on: date),
              let isha = Date.fromTimeString(timings.Isha, on: date) else {
            return nil
        }
        return DayPrayerTimes(fajr: fajr, sunrise: sunrise, dhuhr: dhuhr, asr: asr, maghrib: maghrib, isha: isha)
    }

    // MARK: - Offline Calculation (Adhan preferred, local solar fallback)

    private func calculateOfflinePrayerTimes(
        coordinate: CLLocationCoordinate2D,
        date: Date,
        method: CalculationMethodOption,
        madhab: MadhabOption
    ) -> DayPrayerTimes? {
#if canImport(Adhan)
        return calculateAdhanPrayerTimes(coordinate: coordinate, date: date, method: method, madhab: madhab)
#else
        // TODO(phase2): replace with Adhan Swift library — add package via Xcode (see SETUP comment above)
        return calculateLocalPrayerTimes(coordinate: coordinate, date: date, method: method, madhab: madhab)
#endif
    }

    // MARK: - Adhan-backed Calculation

#if canImport(Adhan)
    /// Uses the Adhan Swift library for DST-safe, accurate prayer time calculation.
    private func calculateAdhanPrayerTimes(
        coordinate: CLLocationCoordinate2D,
        date: Date,
        method: CalculationMethodOption,
        madhab: MadhabOption
    ) -> DayPrayerTimes? {
        let adhanCoordinates = Adhan.Coordinates(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        var params = adhanCalculationParameters(for: method)
        params.madhab = adhanMadhab(for: madhab)

        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let dateComponents = DateComponents(
            calendar: calendar,
            year: components.year,
            month: components.month,
            day: components.day
        ).date.map({ calendar.dateComponents([.year, .month, .day], from: $0) }),
              let prayerTimes = Adhan.PrayerTimes(
                  coordinates: adhanCoordinates,
                  date: dateComponents,
                  calculationParameters: params
              ) else {
            return nil
        }

        return DayPrayerTimes(
            fajr: prayerTimes.fajr,
            sunrise: prayerTimes.sunrise,
            dhuhr: prayerTimes.dhuhr,
            asr: prayerTimes.asr,
            maghrib: prayerTimes.maghrib,
            isha: prayerTimes.isha
        )
    }

    private func adhanCalculationParameters(for method: CalculationMethodOption) -> Adhan.CalculationParameters {
        switch method {
        case .muslimWorldLeague: return Adhan.CalculationMethod.muslimWorldLeague.params
        case .isna:              return Adhan.CalculationMethod.northAmerica.params
        case .egyptian:          return Adhan.CalculationMethod.egyptian.params
        case .karachi:           return Adhan.CalculationMethod.karachi.params
        case .ummAlQura:         return Adhan.CalculationMethod.ummAlQura.params
        case .gulf:              return Adhan.CalculationMethod.dubai.params
        case .qatar:             return Adhan.CalculationMethod.qatar.params
        }
    }

    private func adhanMadhab(for madhab: MadhabOption) -> Adhan.Madhab {
        switch madhab {
        case .shafi:  return .shafi
        case .hanafi: return .hanafi
        }
    }
#endif

    // MARK: - Legacy Local Solar Approximation (pre-Adhan fallback, DST-unsafe)

    private func calculateLocalPrayerTimes(
        coordinate: CLLocationCoordinate2D,
        date: Date,
        method: CalculationMethodOption,
        madhab: MadhabOption
    ) -> DayPrayerTimes? {
        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        let lat = coordinate.latitude
        let lng = coordinate.longitude

        // Solar calculations
        let d = Double(dayOfYear)
        let decl = -23.45 * cos(2 * .pi / 365 * (d + 10))
        let eqt = -7.655 * sin(2 * .pi / 365 * d) + 9.873 * sin(4 * .pi / 365 * d + 3.588)
        let timezone = Double(TimeZone.current.secondsFromGMT(for: date)) / 3600.0

        let noon = 12.0 + (lng / (-15.0)) + timezone - eqt / 60.0

        func hourAngle(angle: Double) -> Double {
            let latRad = lat * .pi / 180
            let declRad = decl * .pi / 180
            let cosHA = (sin(angle * .pi / 180) - sin(latRad) * sin(declRad)) / (cos(latRad) * cos(declRad))
            guard cosHA >= -1 && cosHA <= 1 else { return 0 }
            return acos(cosHA) * 180 / .pi / 15.0
        }

        let (fajrAngle, ishaAngle) = angles(for: method)

        let fajrTime = noon - hourAngle(angle: -fajrAngle)
        let sunrise = noon - hourAngle(angle: -0.833)
        let dhuhr = noon
        let maghrib = noon + hourAngle(angle: -0.833)
        let isha = noon + hourAngle(angle: -ishaAngle)

        // Asr: shadow length = 1 (Shafi) or 2 (Hanafi) + shadow at noon
        let latRad = lat * .pi / 180
        let declRad = decl * .pi / 180
        let shadowFactor: Double = madhab == .hanafi ? 2 : 1
        let asrAngle = atan(1.0 / (shadowFactor + tan(abs(latRad - declRad))))
        let asrHA = acos((sin(asrAngle) - sin(latRad) * sin(declRad)) / (cos(latRad) * cos(declRad)))
        let asr = noon + (asrHA * 180 / .pi / 15.0)

        func makeDate(hours: Double) -> Date {
            var comps = calendar.dateComponents([.year, .month, .day], from: date)
            let h = Int(hours)
            let m = Int((hours - Double(h)) * 60)
            comps.hour = h
            comps.minute = m
            return calendar.date(from: comps) ?? date
        }

        return DayPrayerTimes(
            fajr: makeDate(hours: fajrTime),
            sunrise: makeDate(hours: sunrise),
            dhuhr: makeDate(hours: dhuhr),
            asr: makeDate(hours: asr),
            maghrib: makeDate(hours: maghrib),
            isha: makeDate(hours: isha)
        )
    }

    private func angles(for method: CalculationMethodOption) -> (fajr: Double, isha: Double) {
        switch method {
        case .muslimWorldLeague: return (18, 17)
        case .isna: return (15, 15)
        case .egyptian: return (19.5, 17.5)
        case .karachi: return (18, 18)
        case .ummAlQura: return (18.5, 90) // Isha is 90 min after Maghrib
        case .gulf: return (19.5, 90)
        case .qatar: return (18, 90)
        }
    }

    private func apiMethodNumber(for method: CalculationMethodOption) -> Int {
        switch method {
        case .muslimWorldLeague: return 3
        case .isna: return 2
        case .egyptian: return 5
        case .karachi: return 1
        case .ummAlQura: return 4
        case .gulf: return 8
        case .qatar: return 10
        }
    }
}

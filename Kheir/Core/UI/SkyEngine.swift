import SwiftUI
import Combine
import os

// MARK: - SkyPeriod

/// One named segment of the daily prayer-time cycle,
/// with the sky states that bookend it and the concrete wall-clock times.
private struct SkyPeriod {
    let name: String
    let startDate: Date
    let endDate: Date
    let startState: SkyState
    let endState: SkyState

    /// Linear progress (0–1) for `now` within this period.
    func progress(at now: Date) -> Double {
        let total   = endDate.timeIntervalSince(startDate)
        let elapsed = now.timeIntervalSince(startDate)
        guard total > 0 else { return 0 }
        return max(0, min(1, elapsed / total))
    }

    /// True when `now` falls within [startDate, endDate).
    func contains(_ now: Date) -> Bool {
        now >= startDate && now < endDate
    }
}

// MARK: - SkyEngine

/// Observes the current time relative to today's prayer times and publishes
/// a continuously-interpolated `SkyState` that drives `DynamicSkyView`.
///
/// Usage:
/// ```swift
/// @State private var skyEngine = SkyEngine(dayPrayerTimes: prayerTimes)
/// ```
@MainActor
@Observable
final class SkyEngine {

    // MARK: Public API

    /// The interpolated sky state for the current moment. Updates every 30 seconds.
    private(set) var currentState: SkyState = .isha

    /// Human-readable name of the active prayer period (e.g. "Fajr", "Dhuhr").
    private(set) var currentPrayerName: String = ""

    // MARK: Private State

    private var periods: [SkyPeriod] = []

    // Timer.publish is kept as a Combine pipeline — it is the idiomatic way to
    // drive a repeating wall-clock observer on the main RunLoop. The sink
    // assigns to plain vars; @Observable tracks the mutations automatically.
    private var timer: AnyCancellable?
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Kheir",
        category: "SkyEngine"
    )

    // MARK: Init

    /// - Parameter prayerTimes: Array of `(name, time)` tuples for today, in any order.
    ///   Typically sourced from `DayPrayerTimes.all`.
    init(prayerTimes: [(name: String, time: Date)] = []) {
        loadPrayerTimes(prayerTimes)
        startTimer()
    }

    // MARK: Prayer Times Configuration

    /// Replaces the active prayer schedule and immediately recalculates the sky state.
    func loadPrayerTimes(_ prayerTimes: [(name: String, time: Date)]) {
        periods = Self.buildPeriods(from: prayerTimes)
        update()
    }

    // MARK: Update

    /// Recalculates `currentState` and `currentPrayerName` based on `Date()`.
    ///
    /// Called automatically every `DesignTokens.skyUpdateInterval` seconds.
    /// You may also call this manually (e.g. after loading new prayer times).
    func update() {
        let now = Date()

        guard !periods.isEmpty else {
            currentState = Self.fallbackState(for: now)
            currentPrayerName = "—"
            return
        }

        // The active period is the last one whose start is at or before now.
        let active = periods.last(where: { $0.startDate <= now }) ?? periods[0]
        currentPrayerName = active.name

        let interpolated = SkyState.interpolate(
            from: active.startState,
            to:   active.endState,
            progress: active.progress(at: now)
        )
        currentState = interpolated

        logger.debug(
            "Sky — period: \(active.name), progress: \(String(format: "%.3f", active.progress(at: now)))"
        )
    }

    // MARK: Timer

    private func startTimer() {
        timer = Timer.publish(every: DesignTokens.skyUpdateInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.update() }
    }

    // MARK: Period Construction

    private static func skyState(for prayerName: String) -> SkyState {
        switch prayerName.lowercased() {
        case "fajr":    return .fajr
        case "sunrise": return .sunrise
        case "dhuhr":   return .dhuhr
        case "asr":     return .asr
        case "maghrib": return .maghrib
        case "isha":    return .isha
        default:        return .isha
        }
    }

    private static func buildPeriods(from prayerTimes: [(name: String, time: Date)]) -> [SkyPeriod] {
        guard !prayerTimes.isEmpty else { return [] }

        let sorted = prayerTimes.sorted { $0.time < $1.time }
        var result: [SkyPeriod] = []

        for (index, prayer) in sorted.enumerated() {
            // The period ends when the next prayer begins; the last period runs for one hour.
            let lastPeriodDuration: TimeInterval = 3600
            let startDate  = prayer.time
            let endDate    = index + 1 < sorted.count
                ? sorted[index + 1].time
                : prayer.time.addingTimeInterval(lastPeriodDuration)

            let startState = skyState(for: prayer.name)
            let endState   = index + 1 < sorted.count
                ? skyState(for: sorted[index + 1].name)
                : .isha

            result.append(SkyPeriod(
                name: prayer.name,
                startDate: startDate,
                endDate: endDate,
                startState: startState,
                endState: endState
            ))
        }

        return result
    }

    // MARK: Fallback (no prayer times loaded)

    /// Produces a reasonable sky state purely from the wall-clock hour when
    /// prayer times have not yet been loaded.
    private static func fallbackState(for date: Date) -> SkyState {
        switch Calendar.current.component(.hour, from: date) {
        case 0..<5:   return .isha
        case 5..<7:   return .fajr
        case 7..<12:  return .sunrise
        case 12..<15: return .dhuhr
        case 15..<18: return .asr
        case 18..<20: return .maghrib
        default:      return .isha
        }
    }
}

// MARK: - Convenience Init

extension SkyEngine {
    /// Creates a `SkyEngine` directly from a `DayPrayerTimes` value.
    convenience init(dayPrayerTimes: DayPrayerTimes) {
        self.init(prayerTimes: dayPrayerTimes.all.map { ($0.name, $0.time) })
    }
}

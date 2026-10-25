import SwiftUI
import Observation
import CoreLocation
import AVFoundation
import UserNotifications

// MARK: - Navigation

/// Where the onboarding book is and which page is showing.
///
/// Page 0 is the cover; pages 1–18 are the pages of the book. Every animation is a
/// pure function of time since a start date (one clock), so the stage only needs
/// `book` and `turn` to draw any frame.
@MainActor
@Observable
final class OnboardingFlow {
    static let lastPage = 18
    static let eraseMs: Double = 820
    static let writeMs: Double = 900
    static var turnMs: Double { eraseMs + writeMs }
    static let bookMs: Double = 1350

    enum Book: Equatable {
        case closed
        case opening(Date)
        case open
        case closing(Date)
    }

    /// One eraser-and-pencil page change.
    struct Turn: Equatable {
        let id = UUID()
        let from: Int
        let to: Int
        let dir: Int
        let start: Date
    }

    /// The page we are on, or heading to while a turn plays.
    var page = 0
    var book: Book = .closed
    var turn: Turn?
    /// Set when the user taps a tag on the summary page: Continue then returns to the summary.
    var returnToSummary = false
    var reduceMotion = false

    #if DEBUG
    /// Freezes the book or the page turn at this many ms, for screenshots.
    var frozenMs: Double?
    #endif

    var isAnimating: Bool {
        if turn != nil { return true }
        switch book {
        case .opening, .closing: return true
        default: return false
        }
    }

    func openBook() {
        guard book == .closed else { return }
        page = 1
        if reduceMotion { book = .open; return }
        let start = Date()
        book = .opening(start)
        settle(after: Self.bookMs) { [weak self] in
            if self?.book == .opening(start) { self?.book = .open }
        }
    }

    func closeBook() {
        guard book == .open else { return }
        finishTurn()
        if reduceMotion { book = .closed; page = 0; return }
        let start = Date()
        book = .closing(start)
        settle(after: Self.bookMs) { [weak self] in
            guard let self, self.book == .closing(start) else { return }
            self.book = .closed
            self.page = 0
        }
    }

    func go(to target: Int) {
        let current = page
        finishTurn()
        guard target != current, (0...Self.lastPage).contains(target) else { return }
        if target == 0 { closeBook(); return }
        if reduceMotion || book != .open { page = target; return }
        let turn = Turn(from: current, to: target, dir: target > current ? 1 : -1, start: .now)
        page = target
        self.turn = turn
        settle(after: Self.turnMs) { [weak self] in
            if self?.turn?.id == turn.id { self?.turn = nil }
        }
    }

    /// Tap during a turn: jump straight to its end.
    func finishTurn() {
        turn = nil
    }

    func next() {
        if returnToSummary, page != Self.lastPage {
            returnToSummary = false
            go(to: Self.lastPage)
        } else {
            go(to: page + 1)
        }
    }

    func back() {
        returnToSummary = false
        if page == 1 { closeBook() } else { go(to: page - 1) }
    }

    /// From the summary: go back to the page that set this answer.
    func edit(page target: Int) {
        returnToSummary = true
        go(to: target)
    }

    private func settle(after ms: Double, _ body: @escaping @MainActor () -> Void) {
        #if DEBUG
        if frozenMs != nil { return }
        #endif
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(Int(ms)))
            body()
        }
    }
}

// MARK: - Setup (the answers and the services behind them)

/// Everything the pages need besides navigation. Answers go straight into
/// `AppSettings` the moment they are made, so nothing is lost if the user leaves.
@MainActor
@Observable
final class OnboardingSetup {
    let settings = AppSettings.shared

    enum LocationAsk: Equatable { case idle, asking, granted, denied }

    var locationAsk: LocationAsk = .idle
    var showCitySearch = false
    var cityQuery = ""
    var citySearching = false
    var cityMessage: String?

    /// Today's times for the chosen method, always fetched with the standard Asr;
    /// the Ḥanafī Asr is derived from it (see `asr(for:)`).
    var times: DayPrayerTimes?
    var timesLoading = false
    @ObservationIgnored private var timesKey = ""
    var methodWasAuto = true
    @ObservationIgnored private var methodPicked = false

    var notificationsAllowed: Bool?
    var testSent = false

    var playingQari: String?
    @ObservationIgnored private var player: AVPlayer?

    var coordinate: CLLocationCoordinate2D? {
        LocationService.shared.currentLocation ?? LocationService.shared.lastKnownLocation
    }

    // MARK: Location

    func refreshLocationState() {
        switch LocationService.shared.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: locationAsk = .granted
        case .denied, .restricted:
            locationAsk = .denied
            showCitySearch = true
        default: break
        }
    }

    /// The real iOS prompt. Returns true when permission is already granted.
    func askLocation() -> Bool {
        let service = LocationService.shared
        switch service.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            settings.useAutoLocation = true
            locationAsk = .granted
            service.startUpdating()
            return true
        case .denied, .restricted:
            locationAsk = .denied
            showCitySearch = true
            return false
        default:
            settings.useAutoLocation = true
            locationAsk = .asking
            service.requestPermission()
            return false
        }
    }

    func searchCity() async -> Bool {
        let query = cityQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else {
            cityMessage = "Type a city name."
            return false
        }
        citySearching = true
        defer { citySearching = false }
        guard let found = await LocationService.shared.geocodeCity(query) else {
            cityMessage = "We couldn’t find “\(query)”. Try adding the country."
            return false
        }
        LocationService.shared.setLocation(found)
        settings.manualCity = query
        settings.useAutoLocation = false
        cityMessage = nil
        timesKey = ""
        return true
    }

    var placeName: String? {
        if !settings.useAutoLocation, !settings.manualCity.isEmpty { return settings.manualCity }
        return nil
    }

    // MARK: Calculation method

    /// Picks the method most masjids in the region use, once, unless the user chose one.
    func autoPickMethod() {
        guard !methodPicked else { return }
        methodPicked = true
        let method = Self.regionMethod(coordinate: coordinate, region: Locale.current.region?.identifier)
        settings.calculationMethod = method
        methodWasAuto = true
    }

    func choose(method: CalculationMethodOption) {
        methodPicked = true
        methodWasAuto = false
        settings.calculationMethod = method
    }

    static func regionMethod(coordinate: CLLocationCoordinate2D?, region: String?) -> CalculationMethodOption {
        if let c = coordinate {
            let lat = c.latitude, lon = c.longitude
            func inBox(_ la: ClosedRange<Double>, _ lo: ClosedRange<Double>) -> Bool { la.contains(lat) && lo.contains(lon) }
            if inBox(24.4...26.2, 50.7...51.7) { return .qatar }
            if inBox(22.5...26.1, 51.5...56.4) || inBox(28.5...30.1, 46.5...48.5) || inBox(25.8...26.3, 50.3...50.7) || inBox(16.6...26.4, 52...59.9) { return .gulf }
            if inBox(16...32.2, 34.5...55.7) { return .ummAlQura }
            if inBox(22...31.7, 24.7...36.9) { return .egyptian }
            if inBox(6...37.1, 60.5...92.7) { return .karachi }
            if inBox(14...72, -170 ... -52) { return .isna }
            return .muslimWorldLeague
        }
        switch region ?? "" {
        case "US", "CA": return .isna
        case "SA": return .ummAlQura
        case "QA": return .qatar
        case "AE", "KW", "BH", "OM": return .gulf
        case "EG": return .egyptian
        case "PK", "IN", "BD", "AF": return .karachi
        default: return .muslimWorldLeague
        }
    }

    static func methodSubtitle(_ method: CalculationMethodOption) -> String {
        switch method {
        case .muslimWorldLeague: "Used across Europe and much of the world"
        case .isna: "Islamic Society of North America"
        case .egyptian: "Egyptian General Authority of Survey"
        case .karachi: "University of Islamic Sciences, Karachi"
        case .ummAlQura: "Umm al-Qura University, Makkah"
        case .gulf: "Gulf region"
        case .qatar: "Qatar"
        }
    }

    // MARK: Prayer times

    func loadTimes() async {
        guard let c = coordinate else { return }
        let key = "\(c.latitude.rounded(toPlaces: 2)),\(c.longitude.rounded(toPlaces: 2)),\(settings.calculationMethod.rawValue)"
        guard key != timesKey else { return }
        timesKey = key
        timesLoading = true
        let fetched = await PrayerTimesService.shared.fetchPrayerTimes(
            coordinate: c,
            date: .now,
            method: settings.calculationMethod,
            madhab: .shafi
        )
        if timesKey == key { times = fetched }
        timesLoading = false
    }

    /// Asr for a school. The standard time comes from the fetched times; the Ḥanafī
    /// time adds the difference between the two shadow lengths for this place and day.
    func asr(for madhab: MadhabOption) -> Date? {
        guard let times else { return nil }
        guard madhab == .hanafi, let c = coordinate else { return times.asr }
        guard let one = Self.asrHourAngle(factor: 1, latitude: c.latitude, date: times.dhuhr),
              let two = Self.asrHourAngle(factor: 2, latitude: c.latitude, date: times.dhuhr) else { return times.asr }
        return times.asr.addingTimeInterval((two - one) * 3600)
    }

    /// Hours after solar noon when an object's shadow is `factor` times its height (plus the noon shadow).
    static func asrHourAngle(factor: Double, latitude: Double, date: Date) -> Double? {
        let day = Double(Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1)
        let rad = Double.pi / 180
        let decl = 23.44 * sin(2 * .pi * (284 + day) / 365) * rad
        let phi = latitude * rad
        let altitude = atan(1 / (factor + tan(abs(phi - decl))))
        let cosH = (sin(altitude) - sin(phi) * sin(decl)) / (cos(phi) * cos(decl))
        guard abs(cosH) <= 1 else { return nil }
        return acos(cosH) / rad / 15
    }

    /// The five daily prayers with Asr for the chosen school.
    var dailyPrayers: [(name: String, icon: PaperIcon, time: Date)] {
        guard let t = times else { return [] }
        return [
            ("Fajr", .fajr, t.fajr),
            ("Dhuhr", .dhuhr, t.dhuhr),
            ("Asr", .asr, asr(for: settings.madhab) ?? t.asr),
            ("Maghrib", .maghrib, t.maghrib),
            ("Isha", .isha, t.isha)
        ]
    }

    func nextPrayer(after now: Date) -> (name: String, icon: PaperIcon, time: Date)? {
        let list = dailyPrayers
        guard !list.isEmpty else { return nil }
        if let upcoming = list.first(where: { $0.time > now }) { return upcoming }
        let fajr = list[0]
        return (fajr.name, fajr.icon, fajr.time.addingTimeInterval(86_400))
    }

    // MARK: Notifications

    func refreshNotificationState() async {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        switch status {
        case .authorized, .provisional, .ephemeral: notificationsAllowed = true
        case .denied: notificationsAllowed = false
        default: notificationsAllowed = nil
        }
    }

    func requestNotifications() async {
        notificationsAllowed = await NotificationService.shared.requestPermission()
    }

    func sendTest() async {
        if notificationsAllowed != true { await requestNotifications() }
        guard notificationsAllowed == true else { return }
        NotificationService.shared.sendTestNotification()
        testSent = true
    }

    // MARK: Reciter samples

    func toggleSample(_ qari: Qari) {
        if playingQari == qari.identifier {
            stopSample()
            return
        }
        stopSample()
        guard let url = APIService.shared.audioURL(qari: qari.identifier, surah: 1, ayah: 1, bitrate: qari.bitrate) else { return }
        let player = AVPlayer(url: url)
        self.player = player
        playingQari = qari.identifier
        player.play()
        let id = qari.identifier
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(7))
            if self?.playingQari == id { self?.stopSample() }
        }
    }

    func stopSample() {
        player?.pause()
        player = nil
        playingQari = nil
    }

    // MARK: Finish

    /// Schedules the week of prayer notifications if the user allowed them.
    func finish() async {
        stopSample()
        settings.userName = settings.userName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard notificationsAllowed == true, let c = coordinate else { return }
        await NotificationService.shared.scheduleWeekOfNotifications(coordinate: (c.latitude, c.longitude), settings: settings)
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let m = pow(10, Double(places))
        return (self * m).rounded() / m
    }
}

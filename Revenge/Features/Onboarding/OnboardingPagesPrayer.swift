import SwiftUI
import CoreLocation

// MARK: - 7 · Location (explained before iOS asks)

struct LocationPage: View {
    @Environment(OnboardingFlow.self) private var flow
    @Environment(OnboardingSetup.self) private var setup
    @FocusState private var cityFocused: Bool

    var body: some View {
        @Bindable var setup = self.setup
        let status = LocationService.shared.authorizationStatus
        OBPage(number: 7) {
            LocationScene()
                .frame(width: 210, height: 160)
                .frame(maxWidth: .infinity)
                .padding(.top, 22)
                .obEnter(1)
            OBHeading(text: "Prayer times for where you are").padding(.top, 10).obEnter(2)
            OBLead(text: "Your location sets accurate times and the Qibla direction.").obEnter(3)

            HStack(alignment: .top, spacing: 12) {
                PaperIconView(.shield, size: 30)
                Text("\(Text("Stays on your phone.").bold().foregroundStyle(OBInk.ink)) Never sold, never shared, never used for ads.")
                    .font(.subheadline)
                    .foregroundStyle(OBInk.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .paperPiece(OBInk.raised, depth: 0.6, edge: .torn, radius: 3, seed: 640, padding: nil)
            .accessibilityElement(children: .combine)
            .padding(.top, 14)
            .obEnter(4)

            if setup.locationAsk == .denied {
                Text("Location is off for Kheir. Search for your city instead, or turn it on later in Settings.")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(OBInk.terracotta)
                    .padding(.top, 12)
            }

            if setup.showCitySearch {
                VStack(alignment: .leading, spacing: 8) {
                    OBOverline(text: "Your city")
                    HStack(spacing: 8) {
                        TextField("e.g. Birmingham, UK", text: $setup.cityQuery)
                            .font(.body.weight(.bold))
                            .textContentType(.addressCity)
                            .submitLabel(.search)
                            .focused($cityFocused)
                            .onSubmit { search() }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .paperPiece(OBInk.card, depth: 0.8, radius: 10, seed: 645, padding: nil)
                            .accessibilityLabel("City name")
                        Button(action: search) {
                            Group {
                                if setup.citySearching {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Find")
                                }
                            }
                            .font(.headline.weight(.black))
                            .foregroundStyle(.white)
                            .frame(minWidth: 64, minHeight: 44)
                            .paperPiece(OBInk.green, material: .construction, depth: 1.1, radius: 10, seed: 646, padding: nil)
                        }
                        .buttonStyle(PaperPressStyle())
                        .accessibilityLabel("Find city")
                    }
                    if let message = setup.cityMessage {
                        Text(message).font(.footnote).foregroundStyle(OBInk.terracotta)
                    }
                }
                .padding(.top, 16)
                .transition(.opacity)
            }
        } footer: {
            OBButton(seed: 641, action: allow) {
                if setup.locationAsk == .asking {
                    HStack(spacing: 8) { ProgressView().tint(.white); Text("Waiting for iOS…") }
                } else if setup.locationAsk == .granted {
                    Text("Continue")
                } else {
                    Text("Allow location")
                }
            }
            .accessibilityHint("Shows the iOS location prompt")
            .obEnter(5)
            if !setup.showCitySearch {
                OBGhostButton("Search for my city instead") {
                    withAnimation(.open(0.3)) { setup.showCitySearch = true }
                    cityFocused = true
                }
                .obEnter(6)
            }
        }
        .onAppear { setup.refreshLocationState() }
        .onChange(of: status) { _, _ in
            let wasAsking = setup.locationAsk == .asking
            setup.refreshLocationState()
            if wasAsking, setup.locationAsk == .granted { flow.next() }
        }
    }

    private func allow() {
        if setup.locationAsk == .granted || setup.askLocation() { flow.next() }
    }

    private func search() {
        cityFocused = false
        Task {
            if await setup.searchCity() { flow.next() }
        }
    }
}

/// A paper map pin hopping over a torn green hill, with a masjid beside it.
struct LocationScene: View {
    var body: some View {
        ZStack {
            Ellipse().fill(.black.opacity(0.12)).frame(width: 126, height: 16).offset(y: 66)
            HillShape()
                .fill(OBInk.leaf)
                .frame(width: 200, height: 40)
                .paperShadow(depth: 0.8)
                .offset(y: 54)
            PaperIconView(.masjid, size: 40).offset(x: 62, y: 22)
            LoopClock(period: 1_800) { t in
                let hop = flow(t, [(0, 0), (450, -6), (990, 0), (1080, 0), (1_800, 0)])
                let squash = flow(t, [(0, 1), (450, 1.04), (990, 1), (1080, 0.94), (1_260, 1), (1_800, 1)])
                PaperIconView(.pin, size: 64)
                    .scaleEffect(x: 2 - squash, y: squash, anchor: .bottom)
                    .offset(y: hop)
            }
            .offset(x: -10, y: -14)
        }
        .accessibilityHidden(true)
    }
}

struct HillShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + 2, y: r.minY + r.height * 0.55))
        p.addQuadCurve(to: CGPoint(x: r.midX - 10, y: r.minY + r.height * 0.4), control: CGPoint(x: r.width * 0.2, y: r.minY - 4))
        p.addQuadCurve(to: CGPoint(x: r.maxX - 2, y: r.minY + r.height * 0.2), control: CGPoint(x: r.width * 0.75, y: r.minY + r.height * 0.7))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - 8 · Calculation method

struct MethodPage: View {
    @Environment(OnboardingFlow.self) private var flow
    @Environment(OnboardingSetup.self) private var setup
    @State private var showAll = false

    var body: some View {
        let settings = setup.settings
        let method = settings.calculationMethod
        let coordinate = setup.coordinate
        OBPage(number: 8) {
            OBHeading(text: setup.methodWasAuto ? "We matched your region" : "Your calculation method").padding(.top, 26).obEnter(1)
            OBLead(text: "Check today’s times against your local masjid.").obEnter(2)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        OBOverline(text: "Calculation method")
                        Text(method.displayName).font(.title3.weight(.black))
                        Text(OnboardingSetup.methodSubtitle(method)).font(.footnote).foregroundStyle(OBInk.ink2)
                    }
                    Spacer()
                    if setup.methodWasAuto {
                        OBTag(text: "Auto", color: OBInk.leaf, seed: 650, tilt: 3)
                            .accessibilityLabel("Picked automatically for your region")
                    }
                }
                Line().stroke(OBInk.ink.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [4, 4])).frame(height: 1).padding(.vertical, 12)
                TodayTimesRow(prayers: setup.dailyPrayers, loading: setup.timesLoading, hasLocation: coordinate != nil)
            }
            .padding(16)
            .paperPiece(OBInk.card, depth: 1.4, radius: 14, seed: 651, padding: nil)
            .padding(.top, 16)
            .obEnter(3)

            VStack(spacing: 8) {
                let others = CalculationMethodOption.allCases.filter { $0 != method }
                ForEach(Array((showAll ? others : Array(others.prefix(2))).enumerated()), id: \.element) { k, option in
                    Button {
                        setup.choose(method: option)
                    } label: {
                        HStack {
                            Text(option.displayName).font(.body.weight(.bold))
                            Spacer()
                            Text("›").foregroundStyle(OBInk.ink2)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 11)
                        .paperPiece(OBInk.raised, depth: 0.4, radius: 12, seed: 652 + k, padding: nil)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PaperPressStyle())
                    .accessibilityLabel("Use \(option.displayName)")
                    .accessibilityHint(OnboardingSetup.methodSubtitle(option))
                }
                if !showAll {
                    OBGhostButton("Doesn’t match your masjid? See all methods") {
                        withAnimation(.open(0.3)) { showAll = true }
                    }
                }
            }
            .padding(.top, 12)
            .obEnter(4)
        } footer: {
            OBButton("Looks right", seed: 656) { flow.next() }.obEnter(5)
        }
        .onAppear { setup.autoPickMethod() }
        .task(id: "\(coordinate?.latitude ?? 0),\(coordinate?.longitude ?? 0),\(method.rawValue)") {
            await setup.loadTimes()
        }
    }
}

/// Today's five prayers in a row, from the chosen method.
struct TodayTimesRow: View {
    let prayers: [(name: String, icon: PaperIcon, time: Date)]
    let loading: Bool
    let hasLocation: Bool

    var body: some View {
        if prayers.isEmpty {
            HStack(spacing: 8) {
                if loading { ProgressView() }
                Text(hasLocation ? "Working out today’s times…" : "Add your location to preview today’s times.")
                    .font(.footnote).foregroundStyle(OBInk.ink2)
            }
            .frame(maxWidth: .infinity, minHeight: 60)
        } else {
            HStack(spacing: 4) {
                ForEach(prayers, id: \.name) { p in
                    VStack(spacing: 3) {
                        PaperIconView(p.icon, size: 22)
                        Text(p.name).font(.caption2.weight(.heavy)).lineLimit(1).minimumScaleFactor(0.7)
                        Text(p.time.obTime).font(.caption2).foregroundStyle(OBInk.ink2).lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(p.name) \(p.time.obTime)")
                }
            }
        }
    }
}

// MARK: - 9 · Asr

struct AsrPage: View {
    @Environment(OnboardingFlow.self) private var flow
    @Environment(OnboardingSetup.self) private var setup

    var body: some View {
        let settings = setup.settings
        OBPage(number: 9) {
            OBHeading(text: "How do you pray Asr?").padding(.top, 26).obEnter(1)
            OBLead(text: "Schools differ on when Asr begins.").obEnter(2)
            VStack(spacing: 16) {
                asrCard(.shafi, title: "Standard", subtitle: "Shāfiʿī · Mālikī · Ḥanbalī", seed: 660, tilt: -1.2).obEnter(3)
                asrCard(.hanafi, title: "Ḥanafī", subtitle: "Later Asr (shadow ×2)", seed: 661, tilt: 1).obEnter(4)
            }
            .padding(.top, 20)
            .animation(.open(0.3), value: settings.madhab)
        } footer: {
            OBButton("Continue", seed: 662) { flow.next() }.obEnter(5)
            OBGhostButton("Not sure — use Standard") {
                settings.madhab = .shafi
                flow.next()
            }
            .obEnter(6)
        }
        .task { await setup.loadTimes() }
    }

    private func asrCard(_ madhab: MadhabOption, title: String, subtitle: String, seed: Int, tilt: Double) -> some View {
        let selected = setup.settings.madhab == madhab
        let time = setup.asr(for: madhab)
        return Button {
            setup.settings.madhab = madhab
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.title3.weight(.black)).foregroundStyle(OBInk.ink)
                    Text(subtitle).font(.footnote).foregroundStyle(OBInk.ink2)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    PaperIconView(.asr, size: 28)
                    Text(time?.obTime ?? "—")
                        .font(.system(.title2, design: .rounded, weight: .black))
                        .foregroundStyle(selected ? OBInk.gold : OBInk.ink2)
                }
            }
            .padding(16)
            .paperPiece(selected ? OBInk.card : OBInk.raised, depth: selected ? 2 : 0.5, radius: 14, seed: seed, padding: nil)
            .overlay(alignment: .topTrailing) {
                if selected { OBTick().offset(x: 6, y: -6).transition(.scale.combined(with: .opacity)) }
            }
            .rotationEffect(.degrees(selected ? tilt : 0))
            .contentShape(Rectangle())
        }
        .buttonStyle(PaperPressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(subtitle). Asr today at \(time?.obTime ?? "unknown")")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - 10 · Athan & reminders

struct AthanPage: View {
    @Environment(OnboardingFlow.self) private var flow
    @Environment(OnboardingSetup.self) private var setup

    static let voices: [(id: String, name: String)] = [
        ("azan_makkah", "Makkah"), ("azan_madinah", "Madinah"), ("azan_mishary", "Mishary"), ("azan_aqsa", "Al-Aqṣā")
    ]

    var body: some View {
        @Bindable var settings = setup.settings
        let rows: [(String, PaperIcon, Binding<Bool>)] = [
            ("Fajr", .fajr, $settings.fajrNotification),
            ("Dhuhr", .dhuhr, $settings.dhuhrNotification),
            ("Asr", .asr, $settings.asrNotification),
            ("Maghrib", .maghrib, $settings.maghribNotification),
            ("Isha", .isha, $settings.ishaNotification)
        ]
        OBPage(number: 10) {
            OBHeading(text: "Hear the athan").padding(.top, 26).obEnter(1)
            OBLead(text: "Pick the prayers and the voice.").obEnter(2)

            VStack(spacing: 2) {
                ForEach(Array(rows.enumerated()), id: \.offset) { k, row in
                    Toggle(isOn: row.2) {
                        HStack(spacing: 10) {
                            PaperIconView(row.1, size: 22)
                            Text(row.0).font(.body.weight(.heavy))
                        }
                    }
                    .toggleStyle(PaperToggleStyle(index: k))
                    .padding(.vertical, 5)
                    .accessibilityLabel("Athan for \(row.0)")
                }
            }
            .padding(16)
            .paperPiece(OBInk.card, depth: 1, radius: 14, seed: 670, padding: nil)
            .padding(.top, 14)
            .obEnter(3)

            OBOverline(text: "Voice").padding(.top, 16).obEnter(4)
            OBFlow(spacing: 8) {
                ForEach(Array(Self.voices.enumerated()), id: \.offset) { k, voice in
                    OBChoiceTag(text: voice.name, selected: settings.azanSound == voice.id, seed: 675 + k, k: k, salt: 5) {
                        settings.azanSound = voice.id
                    }
                    .accessibilityLabel("Athan voice: \(voice.name)")
                }
            }
            .padding(.top, 8)
            .obEnter(5)

            if setup.notificationsAllowed == false {
                Text("Notifications are off for Kheir. You can turn them on in iOS Settings; your choices are saved.")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(OBInk.terracotta)
                    .padding(.top, 12)
            } else if setup.testSent {
                Text("Test sent. It arrives in about 5 seconds.")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(OBInk.green)
                    .padding(.top, 12)
                    .accessibilityAddTraits(.updatesFrequently)
            }
        } footer: {
            if setup.notificationsAllowed == nil {
                OBButton(seed: 679, action: { Task { await setup.requestNotifications() } }) {
                    HStack(spacing: 8) { PaperIconView(.bell, size: 20); Text("Allow notifications") }
                }
                .accessibilityHint("Shows the iOS notification prompt")
                .obEnter(6)
            } else {
                OBButton("Continue", seed: 679) { flow.next() }.obEnter(6)
            }
            if setup.notificationsAllowed != false {
                OBGhostButton("Send a test athan") { Task { await setup.sendTest() } }
                    .obEnter(7)
            }
        }
        .task { await setup.refreshNotificationState() }
    }
}

// MARK: - 11 · Help with Fajr

struct FajrPage: View {
    @Environment(OnboardingFlow.self) private var flow
    @Environment(OnboardingSetup.self) private var setup
    @State private var choice: Int = 20

    private let options: [(Int, String)] = [(0, "At Fajr"), (10, "10 min before"), (20, "20 min before"), (30, "30 min before")]

    var body: some View {
        let fajr = setup.times.map { $0.fajr.addingTimeInterval(86_400) }
        OBPage(number: 11) {
            OBHeading(text: "Want help waking for Fajr?").padding(.top, 26).obEnter(1)
            OBLead(text: "A gentle wake-up before the athan.").obEnter(2)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    PaperIconView(.fajr, size: 38)
                    VStack(alignment: .leading, spacing: 2) {
                        OBOverline(text: "Tomorrow")
                        Text("Fajr · \(fajr?.obTime ?? "at dawn")").font(.title3.weight(.black))
                    }
                }
                .accessibilityElement(children: .combine)
                Line().stroke(OBInk.ink.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [4, 4])).frame(height: 1).padding(.vertical, 12)
                OBOverline(text: "Wake me").padding(.bottom, 8)
                OBFlow(spacing: 8) {
                    ForEach(Array(options.enumerated()), id: \.offset) { k, option in
                        OBChoiceTag(text: option.1, selected: choice == option.0, seed: 771 + k, k: k, salt: 6) {
                            choice = option.0
                        }
                        .accessibilityLabel("Wake me \(option.1)")
                    }
                }
                Text("A soft sound that builds up, then the athan. Snooze never carries you past sunrise.")
                    .font(.footnote)
                    .foregroundStyle(OBInk.ink2)
                    .padding(.top, 12)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .paperPiece(OBInk.card, depth: 1.4, radius: 14, seed: 770, padding: nil)
            .padding(.top, 16)
            .obEnter(3)
        } footer: {
            OBButton("Help me wake up", seed: 776) {
                setup.settings.fajrWakeOffset = choice
                flow.next()
            }
            .obEnter(4)
            OBGhostButton("No thanks") {
                setup.settings.fajrWakeOffset = nil
                flow.next()
            }
            .obEnter(5)
        }
        .onAppear {
            if let saved = setup.settings.fajrWakeOffset { choice = saved }
        }
        .task { await setup.loadTimes() }
    }
}

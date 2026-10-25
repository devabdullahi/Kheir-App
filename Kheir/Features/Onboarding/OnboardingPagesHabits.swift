import SwiftUI

// MARK: - 12 · Daily routines

struct RoutinesPage: View {
    @Environment(OnboardingFlow.self) private var flow
    @Environment(OnboardingSetup.self) private var setup

    private let mornings = [5 * 60 + 30, 6 * 60, 6 * 60 + 20, 6 * 60 + 45, 7 * 60 + 15, 8 * 60]
    private let evenings = [15, 30, 45, 60]

    static func clock(_ minutes: Int) -> String {
        var c = DateComponents()
        c.hour = minutes / 60
        c.minute = minutes % 60
        return (Calendar.current.date(from: c) ?? .now).obTime
    }

    var body: some View {
        let settings = setup.settings
        let maghrib = setup.times?.maghrib
        let eveningLabel = maghrib.map { $0.addingTimeInterval(-Double(settings.eveningAdhkarBeforeMaghrib) * 60).obTime }
            ?? "\(settings.eveningAdhkarBeforeMaghrib) min before"
        OBPage(number: 12) {
            OBHeading(text: "A little every day").padding(.top, 26).obEnter(1)
            OBLead(text: "Short adhkar after Fajr and before Maghrib.").obEnter(2)
            VStack(spacing: 14) {
                routineCard(icon: .sunrise, title: "Morning adhkar", subtitle: "10 short remembrances", seed: 680, tilt: -0.6) {
                    Menu {
                        ForEach(mornings, id: \.self) { m in
                            Button(Self.clock(m)) { settings.morningAdhkarMinutes = m }
                        }
                    } label: {
                        OBTag(text: Self.clock(settings.morningAdhkarMinutes), color: OBInk.mustard, seed: 681, tilt: 2, uppercase: false)
                            .frame(minHeight: 44)
                    }
                    .accessibilityLabel("Morning adhkar time, \(Self.clock(settings.morningAdhkarMinutes))")
                    .accessibilityHint("Changes the time")
                }
                .obEnter(3)
                routineCard(icon: .maghrib, title: "Evening adhkar", subtitle: "\(settings.eveningAdhkarBeforeMaghrib) min before Maghrib", seed: 682, tilt: 0.7) {
                    Menu {
                        ForEach(evenings, id: \.self) { m in
                            Button("\(m) min before Maghrib") { settings.eveningAdhkarBeforeMaghrib = m }
                        }
                    } label: {
                        OBTag(text: eveningLabel, color: OBInk.rose, seed: 683, tilt: -2, uppercase: false)
                            .frame(minHeight: 44)
                    }
                    .accessibilityLabel("Evening adhkar, \(settings.eveningAdhkarBeforeMaghrib) minutes before Maghrib")
                    .accessibilityHint("Changes the time")
                }
                .obEnter(4)
                HStack(alignment: .top, spacing: 12) {
                    PaperIconView(.sprout, size: 28)
                    Text("\(Text("Gentle streaks.").bold().foregroundStyle(OBInk.ink)) Miss a day and your progress pauses; it never resets to zero.")
                        .font(.subheadline)
                        .foregroundStyle(OBInk.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .paperPiece(OBInk.raised, depth: 0.5, edge: .torn, radius: 3, seed: 684, padding: nil)
                .accessibilityElement(children: .combine)
                .obEnter(5)
            }
            .padding(.top, 18)
        } footer: {
            OBButton("Set reminders", seed: 685) {
                settings.adhkarRemindersOn = true
                flow.next()
            }
            .obEnter(6)
            OBGhostButton("Maybe later") {
                settings.adhkarRemindersOn = false
                flow.next()
            }
            .obEnter(7)
        }
        .task { await setup.loadTimes() }
    }

    private func routineCard<Chip: View>(icon: PaperIcon, title: String, subtitle: String, seed: Int, tilt: Double, @ViewBuilder chip: () -> Chip) -> some View {
        HStack(spacing: 12) {
            PaperIconView(icon, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline.weight(.black))
                Text(subtitle).font(.footnote).foregroundStyle(OBInk.ink2)
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 8)
            chip()
        }
        .padding(16)
        .paperPiece(OBInk.card, depth: 1.2, radius: 14, seed: seed, padding: nil)
        .rotationEffect(.degrees(tilt))
    }
}

// MARK: - 13 · Weekly sunnahs

struct WeeklyPage: View {
    @Environment(OnboardingFlow.self) private var flow
    @Environment(OnboardingSetup.self) private var setup

    private let rows: [(WeeklyReminder, PaperIcon, String)] = [
        (.alKahf, .book, "Fridays after Fajr"),
        (.jumuah, .masjid, "Friday, 1 hour before"),
        (.mondayThursdayFasts, .sunrise, "Reminder the night before"),
        (.whiteDays, .isha, "13th–15th of each Hijri month"),
        (.ramadan, .star, "Countdowns and suhoor/iftar")
    ]

    var body: some View {
        let settings = setup.settings
        OBPage(number: 13) {
            OBHeading(text: "Beyond the daily prayers").padding(.top, 26).obEnter(1)
            OBLead(text: "Pick any reminders you’d like.").obEnter(2)
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { k, row in
                    Toggle(isOn: Binding(
                        get: { settings.weeklyReminders.contains(row.0) },
                        set: { on in
                            if on { settings.weeklyReminders.insert(row.0) } else { settings.weeklyReminders.remove(row.0) }
                        }
                    )) {
                        HStack(spacing: 10) {
                            PaperIconView(row.1, size: 24)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(row.0.title).font(.subheadline.weight(.heavy))
                                Text(row.2).font(.caption).foregroundStyle(OBInk.ink2)
                            }
                        }
                    }
                    .toggleStyle(PaperToggleStyle(index: k))
                    .padding(.vertical, 7)
                    .accessibilityLabel("\(row.0.title), \(row.2)")
                    if k < rows.count - 1 {
                        Line().stroke(OBInk.ink.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [4, 4])).frame(height: 1)
                    }
                }
            }
            .padding(16)
            .paperPiece(OBInk.card, depth: 1.2, radius: 14, seed: 780, padding: nil)
            .padding(.top, 14)
            .obEnter(3)
        } footer: {
            OBButton("Continue", seed: 781) { flow.next() }.obEnter(4)
        }
    }
}

// MARK: - 14 · Duas

struct DuaNamesPage: View {
    @Environment(OnboardingFlow.self) private var flow
    @Environment(OnboardingSetup.self) private var setup
    @State private var adding = false
    @State private var name = ""
    @State private var note = ""
    @FocusState private var nameFocused: Bool

    var body: some View {
        let settings = setup.settings
        OBPage(number: 14) {
            OBHeading(text: "Who would you like to make dua for?").padding(.top, 26).obEnter(1)
            OBLead(text: "We’ll remind you on Fridays.").obEnter(2)
            VStack(spacing: 12) {
                ForEach(Array(settings.duaNames.enumerated()), id: \.element.id) { k, person in
                    DuaNameCard(person: person, k: k) {
                        settings.duaNames.removeAll { $0.id == person.id }
                    }
                    .obEnter(3 + k)
                }
                if adding {
                    VStack(spacing: 8) {
                        TextField("Name", text: $name)
                            .font(.headline.weight(.heavy))
                            .focused($nameFocused)
                            .submitLabel(.next)
                            .accessibilityLabel("Name of the person")
                        TextField("What for? (optional)", text: $note)
                            .font(.subheadline.italic())
                            .submitLabel(.done)
                            .onSubmit(add)
                            .accessibilityLabel("What to make dua for, optional")
                        HStack {
                            OBGhostButton("Cancel") { withAnimation(.open(0.3)) { adding = false } }
                            OBButton("Add", seed: 797, action: add)
                        }
                    }
                    .padding(14)
                    .paperPiece(OBInk.card, depth: 1.2, radius: 12, seed: 798, padding: nil)
                    .transition(.opacity)
                } else {
                    Button {
                        withAnimation(.open(0.3)) { adding = true }
                        nameFocused = true
                    } label: {
                        HStack(spacing: 8) {
                            PaperIconView(.plus, size: 18)
                            Text("Add a name").font(.body.weight(.heavy))
                        }
                        .foregroundStyle(OBInk.ink2)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .paperPiece(OBInk.raised, depth: 0.3, edge: .torn, radius: 3, seed: 795, padding: nil)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PaperPressStyle())
                    .obEnter(3 + settings.duaNames.count)
                }
            }
            .padding(.top, 18)
            HStack(spacing: 8) {
                PaperIconView(.shield, size: 20)
                Text("Names stay on this phone.").font(.footnote).foregroundStyle(OBInk.ink2)
            }
            .padding(.top, 14)
            .accessibilityElement(children: .combine)
            .obEnter(4 + settings.duaNames.count)
        } footer: {
            OBButton("Continue", seed: 796) { add(); flow.next() }.obEnter(8)
            OBGhostButton("Skip") { flow.next() }.obEnter(9)
        }
    }

    private func add() {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty else { return }
        setup.settings.duaNames.append(DuaName(name: n, note: note.trimmingCharacters(in: .whitespacesAndNewlines)))
        name = ""
        note = ""
        nameFocused = true
    }
}

/// A name written on lined paper, taped down.
struct DuaNameCard: View {
    let person: DuaName
    let k: Int
    let onRemove: () -> Void

    var body: some View {
        let tilt = [-2.0, 1.5, -1.0, 1.2][k % 4]
        HStack(spacing: 6) {
            Text(person.name).font(.headline.weight(.heavy))
            if !person.note.isEmpty {
                Text("— \(person.note)").font(.subheadline.italic()).foregroundStyle(OBInk.ink2)
            }
            Spacer(minLength: 8)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.black))
                    .foregroundStyle(OBInk.ink2)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(person.name)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background {
            Canvas { ctx, size in
                var y: CGFloat = 21
                while y < size.height {
                    ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)), with: .color(OBInk.sky.opacity(0.45)))
                    y += 22
                }
            }
        }
        .paperPiece(OBInk.card, depth: 1.2, radius: 4, seed: 790 + k, padding: nil)
        .overlay(alignment: .topLeading) {
            Rectangle()
                .fill(OBInk.mustard.opacity(0.62))
                .frame(width: 38, height: 16)
                .rotationEffect(.degrees(tilt * 3))
                .offset(x: 16, y: -8)
                .accessibilityHidden(true)
        }
        .rotationEffect(.degrees(tilt))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - 15 · Choose your paper

struct PaperPage: View {
    @Environment(OnboardingFlow.self) private var flow
    @Environment(OnboardingSetup.self) private var setup

    var body: some View {
        @Bindable var settings = setup.settings
        OBPage(number: 15) {
            OBHeading(text: "Choose your paper").padding(.top, 26).obEnter(1)
            OBLead(text: "How Kheir looks on your table.").obEnter(2)
            HStack(alignment: .top, spacing: 12) {
                themeOption(.light, name: "Kraft", seed: 800) { Color(hex: "#E9D9BC") }
                themeOption(.dark, name: "Night", seed: 801) { Color(hex: "#1E2442") }
                themeOption(.sky, name: "Follow the sky", seed: 802) {
                    VStack(spacing: 0) { OBInk.sky; Color(hex: "#1E2442") }
                }
            }
            .padding(.top, 16)
            .obEnter(3)
            OBChoiceTag(text: "Match my iPhone", selected: settings.appTheme == .system, onColor: OBInk.mustard, seed: 803, k: 2) {
                settings.appTheme = .system
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
            .accessibilityLabel("Paper: match my iPhone’s light or dark setting")
            .obEnter(4)
            if settings.appTheme == .sky {
                Text("Light from Fajr to Maghrib, night paper after.")
                    .font(.footnote).foregroundStyle(OBInk.ink2)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }

            OBOverline(text: "Arabic text size").padding(.top, 18).obEnter(5)
            VStack(spacing: 8) {
                Text("ٱلْحَمْدُ لِلَّهِ")
                    .font(.custom("ScheherazadeNew-Regular", size: settings.arabicFontSize))
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .accessibilityLabel("Sample: Alhamdulillah")
                Slider(value: $settings.arabicFontSize, in: 20...44, step: 1) {
                    Text("Arabic text size")
                } minimumValueLabel: {
                    Text("ع").font(.custom("ScheherazadeNew-Regular", size: 16)).accessibilityHidden(true)
                } maximumValueLabel: {
                    Text("ع").font(.custom("ScheherazadeNew-Regular", size: 28)).accessibilityHidden(true)
                }
                .tint(OBInk.green)
                .accessibilityValue("\(Int(settings.arabicFontSize)) points")
            }
            .padding(16)
            .paperPiece(OBInk.card, depth: 0.8, radius: 14, seed: 805, padding: nil)
            .padding(.top, 8)
            .obEnter(6)
        } footer: {
            OBButton("Continue", seed: 806) { flow.next() }.obEnter(7)
        }
    }

    private func themeOption<BG: View>(_ theme: AppTheme, name: String, seed: Int, @ViewBuilder background: () -> BG) -> some View {
        let selected = setup.settings.appTheme == theme
        let card = theme == .dark ? OBInk.night : OBInk.card
        return Button {
            setup.settings.appTheme = theme
        } label: {
            VStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 2).fill(card).frame(height: 16).shadow(color: .black.opacity(0.3), radius: 1, x: 0.5, y: 1)
                    RoundedRectangle(cornerRadius: 2).fill(card).frame(height: 16).shadow(color: .black.opacity(0.3), radius: 1, x: 0.5, y: 1)
                        .padding(.trailing, 22)
                    RoundedRectangle(cornerRadius: 2).fill(OBInk.mustard).frame(width: 34, height: 16)
                }
                .padding(9)
                .frame(maxWidth: .infinity, minHeight: 100)
                .background { background() }
                .clipShape(CutShape(cornerRadius: 12, seed: seed))
                .paperShadow(depth: selected ? 2 : 0.6)
                .rotationEffect(.degrees(selected ? -2 : 0))
                Text(name).font(.caption.weight(.heavy)).foregroundStyle(OBInk.ink).multilineTextAlignment(.center)
                OBTick(size: 18).opacity(selected ? 1 : 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PaperPressStyle())
        .animation(.open(0.3), value: selected)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Paper: \(name)")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - 16 · Widgets & Live Activity

struct WidgetsPage: View {
    @Environment(OnboardingFlow.self) private var flow
    @Environment(OnboardingSetup.self) private var setup
    @State private var showHow = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { ctx in
            content(now: ctx.date)
        }
        .task { await setup.loadTimes() }
    }

    private func content(now: Date) -> some View {
        let next = setup.nextPrayer(after: now)
        return OBPage(number: 16) {
            OBHeading(text: "Kheir on your Home Screen").padding(.top, 26).obEnter(1)
            OBLead(text: "A daily ayah, and a countdown before each prayer.").obEnter(2)
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    OBTag(text: "Ayah", color: OBInk.mustard, seed: 690, tilt: -2)
                    Text("إِنَّ مَعَ ٱلْعُسْرِ يُسْرًا")
                        .font(.custom("ScheherazadeNew-Regular", size: 22))
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Spacer(minLength: 0)
                    Text("94:6").font(.caption2.weight(.heavy)).foregroundStyle(OBInk.ink2)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .paperPiece(OBInk.card, depth: 1.6, radius: 18, seed: 691, padding: nil)
                .rotationEffect(.degrees(-2))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Daily Ayah widget preview: Indeed, with hardship comes ease. 94:6")

                VStack(alignment: .leading, spacing: 4) {
                    OBTag(text: "Next", color: OBInk.mustard, seed: 692, tilt: 2)
                    Spacer(minLength: 0)
                    Text(next?.name ?? "Asr").font(.title3.weight(.black))
                    Text(next?.time.obTime ?? "—").font(.system(.headline, design: .rounded, weight: .black)).foregroundStyle(OBInk.gold)
                    if let next {
                        HStack(spacing: 3) {
                            Text("in")
                            OBCountdown(target: next.time)
                        }
                        .font(.caption).foregroundStyle(OBInk.ink2)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .aspectRatio(1, contentMode: .fit)
                .paperPiece(OBInk.card, depth: 1.6, radius: 18, seed: 693, padding: nil)
                .rotationEffect(.degrees(1.5))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Next prayer widget preview")
            }
            .padding(.top, 16)
            .obEnter(3)

            LiveActivityPreview(next: next)
                .padding(.top, 14)
                .obEnter(4)

            if showHow {
                VStack(alignment: .leading, spacing: 6) {
                    Text("1. Touch and hold your Home Screen until the apps jiggle.")
                    Text("2. Tap Edit, then Add Widget, and search for Kheir.")
                    Text("3. The countdown appears on its own before each prayer.")
                }
                .font(.footnote)
                .foregroundStyle(OBInk.ink2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(14)
                .paperPiece(OBInk.raised, depth: 0.5, edge: .torn, radius: 3, seed: 697, padding: nil)
                .padding(.top, 12)
                .transition(.opacity)
            }
        } footer: {
            if showHow {
                OBButton("Got it", seed: 695) { flow.next() }
            } else {
                OBButton("Show me how", seed: 695) { withAnimation(.open(0.3)) { showHow = true } }.obEnter(5)
            }
            OBGhostButton("Add later") { flow.next() }.obEnter(6)
        }
    }
}

/// The Live Activity before a prayer: night paper with a torn progress strip.
struct LiveActivityPreview: View {
    let next: (name: String, icon: PaperIcon, time: Date)?

    var body: some View {
        let name = next?.name ?? "Maghrib"
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                PaperIconView(next?.icon ?? .maghrib, size: 26)
                Text("\(name) · \(next?.time.obTime ?? "")").font(.headline.weight(.black))
                Spacer()
                if let next {
                    OBCountdown(target: next.time).font(.headline.weight(.black)).foregroundStyle(OBInk.mustard)
                }
            }
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                let remaining = next.map { $0.time.timeIntervalSince(ctx.date) } ?? 900
                let fraction = max(0.05, min(1, 1 - remaining / (3 * 3600)))
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Color(red: 0.95, green: 0.91, blue: 0.82).opacity(0.16)
                        OBInk.mustard.frame(width: geo.size.width * fraction)
                    }
                }
                .frame(height: 7)
                .clipShape(TornStripShape())
            }
        }
        .foregroundStyle(Color(hex: "#F3E9D2"))
        .padding(14)
        .paperPiece(OBInk.night, depth: 1.4, radius: 16, seed: 694, padding: nil)
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Live Activity preview: countdown to \(name)")
    }
}

// MARK: - 17 · Take your progress with you

struct AccountPage: View {
    @Environment(OnboardingFlow.self) private var flow
    @Environment(OnboardingSetup.self) private var setup

    var body: some View {
        let settings = setup.settings
        OBPage(number: 17, showsSkip: false) {
            OBHeading(text: "Take your progress with you").padding(.top, 26).obEnter(1)
            OBLead(text: "Turn on iCloud backup if you’d like your streak, goals and journal on a new iPhone. Everything works without it.").obEnter(2)

            HStack(alignment: .top) {
                stat(icon: AnyView(PaperIconView(.sprout, size: 28)), value: "Day 1", label: "streak")
                stat(icon: AnyView(PaperIconView(.book, size: 28)), value: settings.quranGoal.shortTitle, label: "daily goal")
                stat(icon: AnyView(DailyFlowerView(size: 24).accessibilityHidden(true)), value: "1 flower", label: "garden")
            }
            .padding(16)
            .paperPiece(OBInk.card, depth: 1.4, radius: 14, seed: 840, padding: nil)
            .rotationEffect(.degrees(-0.6))
            .padding(.top, 14)
            .obEnter(3)

            HStack(alignment: .top, spacing: 10) {
                PaperIconView(.shield, size: 24)
                Text("\(Text("Only for moving your progress.").bold().foregroundStyle(OBInk.ink)) Kept in your own iCloud, never on our servers, never sold. Location and dua names stay on your phone. Turn it off anytime in Settings.")
                    .font(.footnote)
                    .foregroundStyle(OBInk.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .paperPiece(OBInk.raised, depth: 0.5, edge: .torn, radius: 3, seed: 841, padding: nil)
            .accessibilityElement(children: .combine)
            .padding(.top, 10)
            .obEnter(4)
        } footer: {
            OBButton(seed: 842, action: {
                settings.iCloudBackup = true
                flow.next()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "icloud.fill").accessibilityHidden(true)
                    Text("Back up with iCloud")
                }
            }
            .accessibilityHint("Turns on iCloud backup")
            .obEnter(5)
            OBGhostButton("Not now") {
                settings.iCloudBackup = false
                flow.next()
            }
            .obEnter(6)
        }
    }

    private func stat(icon: AnyView, value: String, label: String) -> some View {
        VStack(spacing: 3) {
            icon.frame(height: 32)
            Text(value).font(.subheadline.weight(.black))
            Text(label).font(.caption2).foregroundStyle(OBInk.ink2)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

extension QuranGoal {
    var shortTitle: String {
        switch self {
        case .oneAyah: "1 ayah"
        case .onePage: "1 page"
        case .tenMinutes: "10 min"
        case .finishInMonth: "1 juzʾ"
        }
    }
}

// MARK: - 18 · Your Kheir

struct SummaryPage: View {
    @Environment(OnboardingFlow.self) private var flow
    @Environment(OnboardingSetup.self) private var setup
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        let settings = setup.settings
        let name = settings.userName.trimmingCharacters(in: .whitespacesAndNewlines)
        OBPage(number: 18, showsSkip: false) {
            DailyFlowerView(size: 46)
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
                .obEnter(1)
            Text(name.isEmpty ? "Your Kheir is ready" : "Your Kheir is ready, \(name)")
                .font(.system(.title2, design: .rounded, weight: .black))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)
                .obEnter(2)
            Text("Here’s what we set up for you. Tap any tag to change it.")
                .font(.callout).foregroundStyle(OBInk.ink2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
                .obEnter(3)

            OBFlow(spacing: 5, lineSpacing: 7, alignment: .center) {
                ForEach(Array(tags.enumerated()), id: \.offset) { k, tag in
                    Button { flow.edit(page: tag.page) } label: {
                        OBTag(text: tag.text, color: tag.color, seed: 820 + k, tilt: (seeded(k, salt: 7) - 0.5) * 5, uppercase: false)
                            .frame(minHeight: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PaperPressStyle())
                    .accessibilityLabel(tag.text)
                    .accessibilityHint("Goes back to change this")
                    .obEnter(4 + k)
                }
            }
            .padding(.top, 12)

            TimelineView(.periodic(from: .now, by: 30)) { ctx in
                if let next = setup.nextPrayer(after: ctx.date) {
                    HStack {
                        HStack(spacing: 10) {
                            PaperIconView(next.icon, size: 28)
                            VStack(alignment: .leading, spacing: 1) {
                                OBOverline(text: "Next prayer")
                                Text("\(next.name) · \(next.time.obTime)").font(.headline.weight(.black)).lineLimit(1)
                            }
                        }
                        Spacer()
                        OBCountdown(target: next.time)
                            .font(.system(.title2, design: .rounded, weight: .black))
                            .foregroundStyle(OBInk.gold)
                    }
                    .padding(16)
                    .paperPiece(OBInk.card, depth: 1.4, radius: 14, seed: 835, padding: nil)
                    .rotationEffect(.degrees(-0.6))
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.top, 14)
            .obEnter(5 + tags.count)
        } footer: {
            OBButton("Enter Kheir", seed: 836) {
                Task {
                    await setup.finish()
                    hasCompletedOnboarding = true
                }
            }
            .obEnter(6 + tags.count)
            Text("Change anything later in Settings.")
                .font(.footnote).foregroundStyle(OBInk.ink2)
                .obEnter(7 + tags.count)
        }
        .task { await setup.loadTimes() }
    }

    private struct SummaryTag { let text: String; let color: Color; let page: Int }

    private var tags: [SummaryTag] {
        let s = setup.settings
        var out: [SummaryTag] = []
        out.append(.init(text: s.journey.title, color: OBInk.rose, page: 2))
        if !s.intentions.isEmpty {
            out.append(.init(text: s.intentions.count == 1 ? "1 intention" : "\(s.intentions.count) intentions", color: OBInk.raised, page: 3))
        }
        out.append(.init(text: s.translationLanguage.displayName + (s.arabicLevel == .fluent ? " · Arabic fluent" : " + transliteration"), color: OBInk.raised, page: 4))
        out.append(.init(text: s.quranGoal.title, color: OBInk.mustard, page: 5))
        out.append(.init(text: Qari.resolve(s.selectedQari).name, color: OBInk.leaf, page: 6))
        if let city = setup.placeName {
            out.append(.init(text: city, color: OBInk.sky, page: 7))
        } else if setup.locationAsk == .granted || setup.coordinate != nil {
            out.append(.init(text: "Your location", color: OBInk.sky, page: 7))
        } else {
            out.append(.init(text: "Add location", color: OBInk.sky, page: 7))
        }
        out.append(.init(text: s.calculationMethod.displayName + (s.madhab == .hanafi ? " · Ḥanafī Asr" : " · Standard Asr"), color: OBInk.raised, page: 8))
        let voice = AthanPage.voices.first { $0.id == s.azanSound }?.name ?? "Makkah"
        out.append(.init(text: "Athan: \(voice)", color: OBInk.mustard, page: 10))
        out.append(.init(text: s.fajrWakeOffset.map { $0 == 0 ? "Fajr help at Fajr" : "Fajr help \($0) min" } ?? "No Fajr help", color: OBInk.sky, page: 11))
        out.append(.init(text: s.adhkarRemindersOn ? "Adhkar reminders" : "No adhkar reminders", color: OBInk.rose, page: 12))
        if s.weeklyReminders.contains(.alKahf) {
            out.append(.init(text: "Al-Kahf Fridays", color: OBInk.leaf, page: 13))
        } else if !s.weeklyReminders.isEmpty {
            out.append(.init(text: "\(s.weeklyReminders.count) weekly reminders", color: OBInk.leaf, page: 13))
        }
        if !s.duaNames.isEmpty {
            out.append(.init(text: s.duaNames.count == 1 ? "Duas for 1 person" : "Duas for \(s.duaNames.count) people", color: OBInk.rose, page: 14))
        }
        let paper: String = switch s.appTheme {
        case .light: "Kraft paper"
        case .dark: "Night paper"
        case .sky: "Follow the sky"
        case .system: "Match my iPhone"
        }
        out.append(.init(text: paper, color: OBInk.raised, page: 15))
        if s.iCloudBackup { out.append(.init(text: "iCloud backup", color: OBInk.sky, page: 17)) }
        return out
    }
}

import SwiftUI

// MARK: - 1 · Your name

struct NamePage: View {
    @Environment(OnboardingFlow.self) private var flow
    @Environment(OnboardingSetup.self) private var setup
    @FocusState private var focused: Bool

    var body: some View {
        @Bindable var settings = setup.settings
        OBPage(number: 1) {
            OBHeading(text: "What should we call you?").padding(.top, 26).obEnter(1)
            OBLead(text: "Only used to greet you. It stays on this phone.").obEnter(2)

            VStack(spacing: 0) {
                VStack(spacing: 2) {
                    Text("SALAM!")
                        .font(.system(.title2, design: .rounded, weight: .black))
                        .tracking(2)
                    Text("my name is")
                        .font(.caption.weight(.bold))
                        .opacity(0.85)
                }
                .foregroundStyle(OBInk.cream)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(OBInk.terracotta)
                .accessibilityHidden(true)

                TextField("Your name", text: $settings.userName)
                    .font(.system(.largeTitle, design: .rounded, weight: .black))
                    .multilineTextAlignment(.center)
                    .textContentType(.givenName)
                    .submitLabel(.continue)
                    .focused($focused)
                    .onSubmit { flow.next() }
                    .onChange(of: settings.userName) { _, new in
                        if new.count > 24 { settings.userName = String(new.prefix(24)) }
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 8)
                    .overlay(alignment: .bottom) {
                        Line().stroke(OBInk.ink.opacity(0.25), style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                            .frame(height: 2)
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 20)
                    .accessibilityLabel("Your name, optional")
            }
            .paperPiece(OBInk.card, depth: 1.6, radius: 14, seed: 610, padding: nil)
            .clipShape(CutShape(cornerRadius: 14, seed: 610))
            .paperShadow(depth: 1.6)
            .padding(.top, 34)
            .obEnter(3, tilt: -2)
        } footer: {
            OBButton("Continue", seed: 611) { focused = false; flow.next() }.obEnter(4)
            OBGhostButton("Skip for now") {
                focused = false
                setup.settings.userName = ""
                flow.next()
            }
            .obEnter(5)
        }
    }
}

/// A straight horizontal line (for the dashed write-on line).
struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.minX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        }
    }
}

// MARK: - 2 · Your journey

struct JourneyPage: View {
    @Environment(OnboardingFlow.self) private var flow
    @Environment(OnboardingSetup.self) private var setup

    private let options: [(Journey, PaperIcon, String)] = [
        (.newToIslam, .star, "Step-by-step guides, gentle pace"),
        (.returning, .sunrise, "Rebuild habits, no pressure"),
        (.praying, .clock, "Stay consistent"),
        (.deeper, .book, "Tafsir, memorising, more dhikr")
    ]

    var body: some View {
        OBPage(number: 2) {
            OBHeading(text: "Where are you on your journey?").padding(.top, 26).obEnter(1)
            OBLead(text: "So Kheir can meet you where you are.").obEnter(2)
            VStack(spacing: 9) {
                ForEach(Array(options.enumerated()), id: \.offset) { k, item in
                    OBOptionCard(item.0.title, subtitle: item.2, icon: item.1, selected: setup.settings.journey == item.0, seed: 720 + k, k: k) {
                        setup.settings.journey = item.0
                    }
                    .obEnter(3 + k)
                }
            }
            .padding(.top, 16)
        } footer: {
            OBButton("Continue", seed: 724) { flow.next() }.obEnter(7)
        }
    }
}

// MARK: - 3 · Intentions

struct IntentionsPage: View {
    @Environment(OnboardingFlow.self) private var flow
    @Environment(OnboardingSetup.self) private var setup

    private let options: [(Intention, PaperIcon)] = [
        (.prayOnTime, .clock), (.readQuran, .book), (.adhkar, .beads), (.journal, .pen), (.masjids, .masjid)
    ]

    var body: some View {
        OBPage(number: 3) {
            OBHeading(text: "What would you like help with?").padding(.top, 26).obEnter(1)
            OBLead(text: "Choose any. You can change this later.").obEnter(2)
            VStack(spacing: 9) {
                ForEach(Array(options.enumerated()), id: \.offset) { k, item in
                    let on = setup.settings.intentions.contains(item.0)
                    OBOptionCard(item.0.title, icon: item.1, selected: on, seed: 620 + k, k: k) {
                        if on { setup.settings.intentions.remove(item.0) } else { setup.settings.intentions.insert(item.0) }
                    }
                    .obEnter(3 + k)
                }
            }
            .padding(.top, 16)
        } footer: {
            OBButton("Continue", seed: 629) { flow.next() }.obEnter(8)
        }
    }
}

// MARK: - 4 · Arabic & translation

extension TranslationLanguage {
    /// The language's own name, as on its tag.
    var nativeName: String {
        switch self {
        case .english: "English"
        case .urdu: "اردو"
        case .french: "Français"
        case .turkish: "Türkçe"
        case .indonesian: "Bahasa"
        case .bangla: "বাংলা"
        case .spanish: "Español"
        case .german: "Deutsch"
        }
    }
}

struct ArabicPage: View {
    @Environment(OnboardingFlow.self) private var flow
    @Environment(OnboardingSetup.self) private var setup

    var body: some View {
        let settings = setup.settings
        OBPage(number: 4) {
            OBHeading(text: "How comfortable are you reading Arabic?").padding(.top, 26).obEnter(1)
            OBLead(text: "We’ll show help where you need it.").obEnter(2)

            VStack(spacing: 4) {
                Text("قُلْ هُوَ ٱللَّهُ أَحَدٌ")
                    .font(.custom("ScheherazadeNew-Regular", size: 28, relativeTo: .title))
                if settings.arabicLevel != .fluent {
                    Text("Qul huwa Allāhu aḥad")
                        .font(.footnote.italic())
                        .foregroundStyle(OBInk.ink2)
                        .transition(.opacity)
                }
                Text("Say, He is Allah, the One.")
                    .font(.footnote)
                    .foregroundStyle(OBInk.ink2)
            }
            .frame(maxWidth: .infinity)
            .padding(14)
            .paperPiece(OBInk.raised, depth: 0.6, edge: .torn, radius: 3, seed: 730, padding: nil)
            .animation(.open(0.3), value: settings.arabicLevel)
            .padding(.top, 14)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(settings.arabicLevel == .fluent ? "Sample: Qul huwa Allahu ahad. Say, He is Allah, the One." : "Sample with transliteration: Qul huwa Allahu ahad. Say, He is Allah, the One.")
            .obEnter(3)

            OBFlow(spacing: 8, alignment: .center) {
                ForEach(Array(ArabicLevel.allCases.enumerated()), id: \.offset) { k, level in
                    OBChoiceTag(text: level.title, selected: settings.arabicLevel == level, seed: 731 + k, k: k) {
                        settings.arabicLevel = level
                    }
                    .accessibilityLabel("Arabic: \(level.title)")
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 14)
            .obEnter(4)

            OBOverline(text: "Translation").padding(.top, 18).obEnter(5)
            OBFlow(spacing: 8) {
                ForEach(Array(TranslationLanguage.allCases.enumerated()), id: \.offset) { k, lang in
                    OBChoiceTag(text: lang.nativeName, selected: settings.translationLanguage == lang, onColor: OBInk.leaf, seed: 735 + k, k: k, salt: 4) {
                        settings.translationLanguage = lang
                    }
                    .accessibilityLabel("Translation: \(lang.displayName)")
                }
            }
            .padding(.top, 8)
            .obEnter(6)
        } footer: {
            OBButton("Continue", seed: 741) { flow.next() }.obEnter(7)
        }
    }
}

// MARK: - 5 · Quran goal

struct QuranGoalPage: View {
    @Environment(OnboardingFlow.self) private var flow
    @Environment(OnboardingSetup.self) private var setup

    private let subtitles: [QuranGoal: String] = [
        .oneAyah: "with its meaning",
        .onePage: "≈ 2 years to finish",
        .tenMinutes: "with audio",
        .finishInMonth: "≈ 1 juzʾ a day"
    ]

    var body: some View {
        OBPage(number: 5) {
            OBHeading(text: "How much Quran each day?").padding(.top, 26).obEnter(1)
            OBLead(text: "Small and steady beats big and rare.").obEnter(2)
            VStack(spacing: 9) {
                ForEach(Array(QuranGoal.allCases.enumerated()), id: \.offset) { k, goal in
                    OBOptionCard(goal.title, subtitle: subtitles[goal], icon: nil, selected: setup.settings.quranGoal == goal, seed: 750 + k, k: k) {
                        setup.settings.quranGoal = goal
                    }
                    .obEnter(3 + k)
                }
            }
            .padding(.top, 16)
            Text("“The most beloved deeds to Allah are the most consistent, even if small.” \(Text("· Bukhārī").foregroundStyle(OBInk.ink2.opacity(0.8)))")
                .font(.footnote)
                .foregroundStyle(OBInk.ink2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(14)
                .paperPiece(OBInk.raised, depth: 0.4, edge: .torn, radius: 3, seed: 754, padding: nil)
                .padding(.top, 14)
                .obEnter(7)
        } footer: {
            OBButton("Set my goal", seed: 755) { flow.next() }.obEnter(8)
        }
    }
}

// MARK: - 6 · Reciter

struct ReciterPage: View {
    @Environment(OnboardingFlow.self) private var flow
    @Environment(OnboardingSetup.self) private var setup

    static func subtitle(_ id: String) -> String {
        switch id {
        case "ar.alafasy": "Kuwait · warm, melodic"
        case "ar.abdurrahmaansudais": "Imam of Makkah · moving"
        case "ar.abdulsamad": "Egypt · classic mujawwad"
        case "ar.husary": "Egypt · precise, measured"
        case "ar.minshawi": "Egypt · soulful"
        default: ""
        }
    }

    var body: some View {
        OBPage(number: 6) {
            OBHeading(text: "Whose recitation moves you?").padding(.top, 26).obEnter(1)
            OBLead(text: "Tap to hear a few seconds.").obEnter(2)
            VStack(spacing: 9) {
                ForEach(Array(Qari.defaults.enumerated()), id: \.offset) { k, qari in
                    let selected = setup.settings.selectedQari == qari.identifier
                    let playing = setup.playingQari == qari.identifier
                    OBOptionCard(title: qari.name, subtitle: Self.subtitle(qari.identifier), selected: selected, seed: 760 + k, k: k, action: {
                        setup.settings.selectedQari = qari.identifier
                        setup.toggleSample(qari)
                    }) {
                        ZStack {
                            Circle().fill(playing ? OBInk.green : OBInk.card)
                                .shadow(color: .black.opacity(0.25), radius: 1, x: 0.5, y: 1)
                            if playing {
                                PlayingBars().frame(width: 16, height: 14)
                            } else {
                                PaperIconView(.play, size: 15)
                            }
                        }
                        .frame(width: 34, height: 34)
                    }
                    .accessibilityHint(playing ? "Playing a sample. Tap to stop." : "Selects this reciter and plays a short sample")
                    .obEnter(3 + k)
                }
            }
            .padding(.top, 16)
        } footer: {
            OBButton("Continue", seed: 766) { setup.stopSample(); flow.next() }.obEnter(8)
        }
        .onDisappear { setup.stopSample() }
    }
}

/// Three paper bars bouncing while a sample plays.
struct PlayingBars: View {
    var body: some View {
        LoopClock(period: 2_200) { t in
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<3, id: \.self) { i in
                    let h = 0.35 + 0.65 * (0.5 + 0.5 * wave(t, period: 1_100, phase: Double(i) * 0.18))
                    RoundedRectangle(cornerRadius: 1)
                        .fill(OBInk.cream)
                        .frame(width: 3.5)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .scaleEffect(x: 1, y: h, anchor: .bottom)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

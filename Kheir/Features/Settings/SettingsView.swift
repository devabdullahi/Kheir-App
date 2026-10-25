import SwiftUI
import UserNotifications

/// Settings as separate card sheets on the table, each headed by a torn kraft
/// label. Native controls (toggles, pickers, sliders) keep their shape and sit
/// on the paper.
struct SettingsView: View {
    @Bindable private var settings = AppSettings.shared
    private var backup = CloudBackupService.shared
    @Environment(\.colorScheme) private var colorScheme

    @State private var showPermissionDeniedAlert = false
    @State private var showDeleteBackupConfirm = false
    @State private var newDuaName = ""
    @State private var newDuaNote = ""

    /// Display order for the paper picker.
    private let themes: [AppTheme] = [.light, .dark, .system, .sky]

    @State private var liveActivityMessage: String?
    /// `nil` shows the menu; a page shows that topic.
    var page: SettingsPage? = nil

    var body: some View {
        if let page {
            pageView(page)
                .onAppear { backup.start() }
                .modifier(SettingsAlerts(showPermissionDenied: $showPermissionDeniedAlert, showDeleteBackup: $showDeleteBackupConfirm, backup: backup))
        } else {
            menu
        }
    }

    private var menu: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                profileStrip
                    .quickPlace(0)
                menuCard(index: 1, [.prayer, .quran, .appearance])
                menuCard(index: 2, [.duas, .backup])
                menuCard(index: 3, [.about])
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 120) // clear the tab bar
        }
        .scrollDismissesKeyboard(.interactively)
        .paperBackground()
        .navigationTitle("Settings")
        .toolbarTitleDisplayMode(.large)
        .onAppear { backup.start() }
        .accessibilityIdentifier("settingsScrollView")
    }

    // MARK: - Menu

    /// Settings is a short menu; each topic opens its own page.
    enum SettingsPage: Hashable {
        case you, prayer, quran, appearance, duas, backup, about

        var title: String {
            switch self {
            case .you: "You"
            case .prayer: "Prayer & athan"
            case .quran: "Quran"
            case .appearance: "Appearance & sound"
            case .duas: "Duas"
            case .backup: "Back up & transfer"
            case .about: "About Kheir"
            }
        }

        var icon: PaperIcon {
            switch self {
            case .you: .sprout
            case .prayer: .bell
            case .quran: .book
            case .appearance: .sun
            case .duas: .star
            case .backup: .shield
            case .about: .masjid
            }
        }
    }

    /// The current state of each topic, so the menu answers questions on its own.
    private func summary(_ page: SettingsPage) -> String {
        switch page {
        case .you:
            return settings.journey.title
        case .prayer:
            let on = [settings.fajrNotification, settings.dhuhrNotification, settings.asrNotification,
                      settings.maghribNotification, settings.ishaNotification].filter { $0 }.count
            let asr = settings.madhab == .hanafi ? "Ḥanafī Asr" : "Standard Asr"
            return "\(settings.calculationMethod.rawValue) · \(asr) · athan \(on)/5"
        case .quran:
            return "\(settings.translationLanguage.displayName) · \(settings.quranGoal.title)"
        case .appearance:
            return "\(settings.appTheme == .sky ? "Follow the sky" : settings.appTheme.displayName) · sounds \(settings.soundEffects ? "on" : "off")"
        case .duas:
            return settings.duaNames.isEmpty ? "Add people to remember" : "\(settings.duaNames.count) \(settings.duaNames.count == 1 ? "person" : "people")"
        case .backup:
            return settings.iCloudBackup ? "iCloud backup on" : "Off · on this iPhone only"
        case .about:
            return "Version, privacy, data providers"
        }
    }

    private func menuCard(index: Int, _ pages: [SettingsPage]) -> some View {
        card(seed: 190 + index) {
            ForEach(Array(pages.enumerated()), id: \.element) { i, page in
                if i > 0 { PaperRowDivider() }
                NavigationLink(value: page) {
                    HStack(spacing: 12) {
                        PaperIconView(page.icon, size: 26)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(page.title)
                                .font(.system(size: 16, weight: .heavy, design: .rounded))
                                .foregroundStyle(Color.adaptiveText(colorScheme))
                            Text(summary(page))
                                .font(.system(size: 12.5, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                                .lineLimit(1)
                        }
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(PaperPressStyle())
                .accessibilityHint(summary(page))
            }
        }
        .quickPlace(index)
    }

    /// Name, journey and today's flower in one strip; opens "You".
    private var profileStrip: some View {
        NavigationLink(value: SettingsPage.you) {
            HStack(spacing: 12) {
                DailyFlowerView(date: .now, size: 34)
                    .frame(width: 42, height: 46)
                VStack(alignment: .leading, spacing: 2) {
                    Text(settings.userName.isEmpty ? "As-salāmu ʿalaykum" : settings.userName)
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Text("\(settings.journey.title) · Kheir")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
            }
            .paperPiece(Color.adaptiveCardElevated(colorScheme), material: .card, depth: 1.2, seed: 170, padding: 14)
        }
        .buttonStyle(PaperPressStyle())
        .accessibilityIdentifier("settingsHeader")
    }

    // MARK: - Pages

    @ViewBuilder
    private func pageView(_ page: SettingsPage) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                switch page {
                case .you:
                    personalCard.quickPlace(0)
                case .prayer:
                    section("Times", seed: 174, index: 0) { prayerCard }
                    section("Athan", seed: 175, index: 1) { notificationsCard }
                    section("Reminders", seed: 176, index: 2) { remindersCard }
                    section("Location", seed: 178, index: 3) { locationCard }
                case .quran:
                    quranCard.quickPlace(0)
                case .appearance:
                    appearanceCard.quickPlace(0)
                    soundCard.quickPlace(1)
                case .duas:
                    duasCard.quickPlace(0)
                case .backup:
                    backupCard.quickPlace(0)
                case .about:
                    section("About", seed: 180, index: 0) { aboutCard }
                    section("Data providers", seed: 181, index: 1) { creditsCard }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
        .scrollDismissesKeyboard(.interactively)
        .paperBackground()
        .navigationTitle(page.title)
        .toolbarTitleDisplayMode(.inline)
    }

    private var soundCard: some View {
        card(seed: 189) {
            Toggle(isOn: $settings.soundEffects) {
                rowLabel("Paper sounds", icon: .pen)
            }
            .tint(Color.adaptivePrimary(colorScheme))
            caption("The book opening, the eraser and the pencil in onboarding. Follows the silent switch.")
        }
    }

    // MARK: - Layout helpers

    private func section<Content: View>(_ title: String, seed: Int, index: Int, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            PaperSectionTag(title: title, seed: seed)
                .padding(.top, 14)
                .padding(.leading, 4)
            content()
        }
        .quickPlace(index)
    }

    private func card<Content: View>(seed: Int, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperPiece(Color.adaptiveCardSurface(colorScheme), material: .card, depth: 1, radius: 18, seed: seed, padding: 16)
        .rotationEffect(.degrees((seeded(seed, salt: 9) - 0.5) * 0.8))
    }

    private func rowLabel(_ title: String, icon: PaperIcon? = nil) -> some View {
        HStack(spacing: 10) {
            if let icon { PaperIconView(icon, size: 20) }
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.adaptiveText(colorScheme))
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12.5, weight: .medium, design: .rounded))
            .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Header

    // MARK: - You (personalisation)

    private var personalCard: some View {
        card(seed: 182) {
            HStack(spacing: 10) {
                rowLabel("Name", icon: .pen)
                TextField("Optional", text: $settings.userName)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.trailing)
                    .textContentType(.givenName)
                    .submitLabel(.done)
                    .accessibilityIdentifier("userNameField")
            }

            PaperRowDivider()

            pickerRow("Your journey", icon: .star, id: "journeyPicker") {
                Picker("Your journey", selection: $settings.journey) {
                    ForEach(Journey.allCases, id: \.self) { Text($0.title).tag($0) }
                }
            }

            PaperRowDivider()

            VStack(alignment: .leading, spacing: 8) {
                rowLabel("Your intentions", icon: .sprout)
                caption("Decides which cards come first on Home.")
                ForEach(Array(Intention.allCases.enumerated()), id: \.element) { index, intention in
                    let isOn = settings.intentions.contains(intention)
                    Button {
                        withAnimation(.open(0.2)) {
                            if isOn { settings.intentions.remove(intention) } else { settings.intentions.insert(intention) }
                        }
                    } label: {
                        HStack(spacing: 10) {
                            PaperCheckbox(isOn: isOn, size: 22, seed: 600 + index)
                            Text(intention.title)
                                .font(.system(size: 14.5, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.adaptiveText(colorScheme))
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(intention.title)
                    .accessibilityAddTraits(isOn ? [.isSelected, .isButton] : .isButton)
                }
            }

            PaperRowDivider()

            pickerRow("Arabic reading", icon: .book, id: "arabicLevelPicker") {
                Picker("Arabic reading", selection: $settings.arabicLevel) {
                    ForEach(ArabicLevel.allCases, id: \.self) { Text($0.title).tag($0) }
                }
            }

            PaperRowDivider()

            pickerRow("Quran goal", icon: .bookmark, id: "quranGoalPicker") {
                Picker("Quran goal", selection: $settings.quranGoal) {
                    ForEach(QuranGoal.allCases, id: \.self) { Text($0.title).tag($0) }
                }
            }
        }
    }

    // MARK: - Appearance

    private var appearanceCard: some View {
        card(seed: 183) {
            VStack(alignment: .leading, spacing: 8) {
                rowLabel("Paper", icon: .sun)
                Picker("Theme", selection: $settings.appTheme) {
                    ForEach(themes, id: \.self) { theme in
                        Text(theme == .sky ? "Sky" : theme.displayName).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("themePicker")
                caption(settings.appTheme == .sky
                        ? "Follow the sky: kraft from Fajr to Maghrib, night paper after."
                        : "Sky follows the prayer times: kraft from Fajr to Maghrib, night paper after.")
            }

            PaperRowDivider()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    rowLabel("Arabic Font Size", icon: .aa)
                    Spacer()
                    Text("\(Int(settings.arabicFontSize))")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.adaptivePrimary(colorScheme))
                        .monospacedDigit()
                        .accessibilityIdentifier("arabicFontSizeValue")
                }
                Slider(value: $settings.arabicFontSize, in: 20...44, step: 2)
                    .tint(Color.adaptivePrimary(colorScheme))
                    .accessibilityIdentifier("arabicFontSizeSlider")

                Text("بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ")
                    .arabicFont(size: CGFloat(settings.arabicFontSize))
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .accessibilityLabel("Arabic font preview: In the name of Allah, the Most Gracious, the Most Merciful")
            }

            PaperRowDivider()

            Toggle(isOn: $settings.showTransliteration) {
                rowLabel("Show Transliteration", icon: .pen)
            }
            .tint(Color.adaptivePrimary(colorScheme))
            .accessibilityIdentifier("showTransliterationToggle")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("appearanceCard")
    }

    // MARK: - Quran

    private var quranCard: some View {
        card(seed: 184) {
            pickerRow("Translation", icon: .book, id: "translationLanguagePicker") {
                Picker("Translation Language", selection: $settings.translationLanguage) {
                    ForEach(TranslationLanguage.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
            }

            PaperRowDivider()

            pickerRow("Default Reciter", icon: .play, id: "reciterPicker") {
                Picker("Default Reciter", selection: $settings.selectedQari) {
                    ForEach(Qari.defaults) { Text($0.name).tag($0.identifier) }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("quranCard")
    }

    // MARK: - Prayer Times

    private var prayerCard: some View {
        card(seed: 185) {
            pickerRow("Calculation Method", icon: .clock, id: "calculationMethodPicker") {
                Picker("Calculation Method", selection: $settings.calculationMethod) {
                    ForEach(CalculationMethodOption.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
            }

            PaperRowDivider()

            pickerRow("Madhab", icon: .asr, id: "madhabPicker") {
                Picker("Madhab", selection: $settings.madhab) {
                    ForEach(MadhabOption.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("prayerCard")
    }

    // MARK: - Notifications

    private var notificationsCard: some View {
        card(seed: 186) {
            notificationToggle("Fajr", isOn: $settings.fajrNotification)
                .accessibilityIdentifier("fajrNotificationToggle")
            PaperRowDivider()
            notificationToggle("Sunrise", isOn: $settings.sunriseNotification)
                .accessibilityIdentifier("sunriseNotificationToggle")
            PaperRowDivider()
            notificationToggle("Dhuhr", isOn: $settings.dhuhrNotification)
                .accessibilityIdentifier("dhuhrNotificationToggle")
            PaperRowDivider()
            notificationToggle("Asr", isOn: $settings.asrNotification)
                .accessibilityIdentifier("asrNotificationToggle")
            PaperRowDivider()
            notificationToggle("Maghrib", isOn: $settings.maghribNotification)
                .accessibilityIdentifier("maghribNotificationToggle")
            PaperRowDivider()
            notificationToggle("Isha", isOn: $settings.ishaNotification)
                .accessibilityIdentifier("ishaNotificationToggle")
            PaperRowDivider()

            Button {
                NotificationService.shared.sendTestNotification()
            } label: {
                HStack(spacing: 10) {
                    PaperIconView(.bell, size: 20)
                    Text("Send Test Notification")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.adaptivePrimary(colorScheme))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PaperPressStyle())
            .accessibilityLabel("Send Test Notification")
            .accessibilityIdentifier("sendTestNotificationButton")
            PaperRowDivider()

            Button {
                Task {
                    liveActivityMessage = await PrayerLiveActivityManager.shared.startNow()
                        ?? "Countdown started. Lock your iPhone or look at the Dynamic Island."
                }
            } label: {
                HStack(spacing: 10) {
                    PaperIconView(.clock, size: 20)
                    Text("Show Prayer Countdown Now")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.adaptivePrimary(colorScheme))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PaperPressStyle())
            .accessibilityHint("Starts the Live Activity for the next prayer")
            if let liveActivityMessage {
                caption(liveActivityMessage)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("notificationsCard")
    }

    // MARK: - Reminders (Fajr help, adhkar, weekly sunnahs)

    private var remindersCard: some View {
        card(seed: 187) {
            pickerRow("Help with Fajr", icon: .fajr, id: "fajrHelpPicker") {
                Picker("Help with Fajr", selection: $settings.fajrWakeOffset) {
                    Text("Off").tag(Int?.none)
                    Text("At Fajr").tag(Int?.some(0))
                    Text("10 min before").tag(Int?.some(10))
                    Text("20 min before").tag(Int?.some(20))
                    Text("30 min before").tag(Int?.some(30))
                }
            }
            caption("A gentle sound that builds up before the athan.")

            PaperRowDivider()

            Toggle(isOn: $settings.adhkarRemindersOn) {
                rowLabel("Adhkar reminders", icon: .beads)
            }
            .tint(Color.adaptivePrimary(colorScheme))

            PaperRowDivider()

            VStack(alignment: .leading, spacing: 10) {
                rowLabel("Weekly sunnahs", icon: .moon)
                ForEach(WeeklyReminder.allCases, id: \.self) { reminder in
                    Toggle(reminder.title, isOn: Binding(
                        get: { settings.weeklyReminders.contains(reminder) },
                        set: { on in
                            if on { settings.weeklyReminders.insert(reminder) } else { settings.weeklyReminders.remove(reminder) }
                        }
                    ))
                    .font(.system(size: 14.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .tint(Color.adaptivePrimary(colorScheme))
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("remindersCard")
    }

    // MARK: - Duas

    private var duasCard: some View {
        card(seed: 188) {
            caption("People you'd like to remember in dua. Kheir reminds you on Fridays. Names never leave your phone unless iCloud backup is on.")

            ForEach(Array(settings.duaNames.enumerated()), id: \.element.id) { index, dua in
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(dua.name)
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                        if !dua.note.isEmpty {
                            Text(dua.note)
                                .font(.system(size: 13, design: .serif))
                                .italic()
                                .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                        }
                    }
                    Spacer()
                    Button {
                        withAnimation(.open(0.2)) { settings.duaNames.removeAll { $0.id == dua.id } }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PaperPressStyle())
                    .accessibilityLabel("Remove \(dua.name)")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .paperPiece(Color.adaptiveCardElevated(colorScheme), material: .card, depth: 0.5, radius: 6, seed: 620 + index, padding: nil)
                .overlay(alignment: .topLeading) {
                    PaperTape(seed: 620 + index).scaleEffect(0.55).offset(x: -4, y: -8)
                }
            }

            HStack(spacing: 8) {
                VStack(spacing: 6) {
                    TextField("Name", text: $newDuaName)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .textContentType(.name)
                    TextField("For… (optional)", text: $newDuaNote)
                        .font(.system(size: 13.5, design: .rounded))
                }
                Button(action: addDua) {
                    PaperIconView(.plus, size: 22)
                        .frame(width: 44, height: 44)
                        .paperPiece(.lightPrimary, material: .construction, depth: 0.9, radius: 10, seed: 640, padding: nil)
                }
                .buttonStyle(PaperPressStyle())
                .disabled(newDuaName.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityLabel("Add to duas")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("duasCard")
    }

    private func addDua() {
        let name = newDuaName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        withAnimation(.open(0.2)) {
            settings.duaNames.append(DuaName(name: name, note: newDuaNote.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        newDuaName = ""
        newDuaNote = ""
    }

    // MARK: - Location

    private var locationCard: some View {
        card(seed: 189) {
            Toggle(isOn: $settings.useAutoLocation) {
                rowLabel("Use GPS Location", icon: .pin)
            }
            .tint(Color.adaptivePrimary(colorScheme))
            .accessibilityIdentifier("useGPSToggle")

            if !settings.useAutoLocation {
                PaperRowDivider()
                HStack(spacing: 10) {
                    PaperIconView(.masjid, size: 20)
                    TextField("Enter city name", text: $settings.manualCity)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .accessibilityIdentifier("manualCityField")
                }
            }

            PaperRowDivider()

            pickerRow("Distance Unit", icon: .compass, id: "distanceUnitPicker") {
                Picker("Distance Unit", selection: $settings.distanceUnit) {
                    ForEach(DistanceUnit.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("locationCard")
    }

    // MARK: - Back up & transfer

    private var backupCard: some View {
        card(seed: 190) {
            Toggle(isOn: Binding(
                get: { settings.iCloudBackup },
                set: { backup.setEnabled($0) }
            )) {
                rowLabel("iCloud Backup", icon: .shield)
            }
            .tint(Color.adaptivePrimary(colorScheme))
            .accessibilityIdentifier("iCloudBackupToggle")

            caption("Your streak, goals, journal and garden come back on a new iPhone signed into the same Apple ID.")

            if settings.iCloudBackup {
                PaperRowDivider()

                HStack(spacing: 8) {
                    if backup.isSyncing {
                        ProgressView().controlSize(.small)
                        caption("Backing up…")
                    } else if !backup.isICloudAvailable {
                        caption("Sign in to iCloud in the Settings app to back up.")
                    } else if let last = backup.lastSynced {
                        caption("Last backed up \(last.formatted(.relative(presentation: .named)))")
                    } else {
                        caption("Not backed up yet")
                    }
                    Spacer()
                    Button("Back up now") {
                        Task { await backup.syncNow() }
                    }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.adaptivePrimary(colorScheme))
                    .disabled(backup.isSyncing)
                    .accessibilityIdentifier("backupNowButton")
                }
            }

            PaperRowDivider()

            Button(role: .destructive) {
                showDeleteBackupConfirm = true
            } label: {
                HStack {
                    Text("Delete backup")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.destructive)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PaperPressStyle())
            .accessibilityIdentifier("deleteBackupButton")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("backupCard")
    }

    // MARK: - About

    private var aboutCard: some View {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

        return card(seed: 191) {
            HStack(spacing: 14) {
                Image("AppIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 52, height: 52)
                    .clipShape(CutShape(cornerRadius: 12, seed: 192))
                    .paperShadow(depth: 0.8)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Kheir")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Text("Your daily Islamic companion")
                        .font(.system(size: 12.5, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                    Text("Version \(version) (\(build))")
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                        .accessibilityIdentifier("appVersionLabel")
                }
            }

            PaperRowDivider()

            linkRow("Rate Kheir on the App Store", icon: .star, url: "https://apps.apple.com/app/idYOUR_APP_ID")
                .accessibilityIdentifier("rateAppButton")

            PaperRowDivider()

            linkRow("Privacy Policy", icon: .shield, url: "https://kheir.app/privacy")
                .accessibilityIdentifier("privacyPolicyButton")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("aboutCard")
    }

    private func linkRow(_ title: String, icon: PaperIcon, url: String) -> some View {
        Button {
            if let link = URL(string: url) { UIApplication.shared.open(link) }
        } label: {
            HStack(spacing: 10) {
                PaperIconView(icon, size: 20)
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PaperPressStyle())
    }

    // MARK: - Credits

    private var creditsCard: some View {
        card(seed: 193) {
            creditRow(name: "Al-Quran Cloud", description: "Quran text & translations", url: "https://alquran.cloud", icon: .book)
            PaperRowDivider()
            creditRow(name: "Fawazahmed0 Hadith API", description: "Hadith collections & grades", url: "https://github.com/fawazahmed0/hadith-api", icon: .beads)
            PaperRowDivider()
            creditRow(name: "Aladhan Prayer Times", description: "Prayer time calculations", url: "https://aladhan.com", icon: .clock)
            PaperRowDivider()
            creditRow(name: "Adhan Swift", description: "Prayer times library by Batoul Apps", url: "https://github.com/batoulapps/adhan-swift", icon: .compass)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("creditsCard")
    }

    private func creditRow(name: String, description: String, url: String, icon: PaperIcon) -> some View {
        Button {
            if let link = URL(string: url) { UIApplication.shared.open(link) }
        } label: {
            HStack(spacing: 12) {
                PaperIconView(icon, size: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 14.5, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Text(description)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PaperPressStyle())
        .accessibilityLabel("\(name): \(description). Opens in browser.")
    }

    // MARK: - Picker row

    private func pickerRow<P: View>(_ label: String, icon: PaperIcon, id: String, @ViewBuilder picker: () -> P) -> some View {
        HStack(spacing: 10) {
            rowLabel(label, icon: icon)
            Spacer(minLength: 4)
            picker()
                .labelsHidden()
                .tint(Color.adaptivePrimary(colorScheme))
                .accessibilityIdentifier(id)
        }
    }

    // MARK: - Notification Toggle Helper

    /// Wraps a prayer notification toggle with contextual permission handling.
    /// - When flipping to true with `.notDetermined` status: requests permission first.
    /// - When flipping to true with `.denied` status: shows "Open Settings" alert.
    private func notificationToggle(_ label: String, isOn binding: Binding<Bool>) -> some View {
        Toggle(isOn: Binding(
            get: { binding.wrappedValue },
            set: { newValue in
                guard newValue else {
                    binding.wrappedValue = false
                    return
                }
                Task { @MainActor in
                    let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
                    switch status {
                    case .authorized, .provisional, .ephemeral:
                        binding.wrappedValue = true
                    case .notDetermined:
                        let granted = await NotificationService.shared.requestPermission()
                        binding.wrappedValue = granted
                    case .denied:
                        showPermissionDeniedAlert = true
                    @unknown default:
                        binding.wrappedValue = true
                    }
                }
            }
        )) {
            rowLabel(label, icon: PaperIcon.forPrayer(label))
        }
        .tint(Color.adaptivePrimary(colorScheme))
    }
}

/// The notification-permission alert and the delete-backup confirmation, shown from
/// whichever Settings page raised them.
private struct SettingsAlerts: ViewModifier {
    @Binding var showPermissionDenied: Bool
    @Binding var showDeleteBackup: Bool
    let backup: CloudBackupService

    func body(content: Content) -> some View {
        content
            .alert("Notifications Disabled", isPresented: $showPermissionDenied) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Prayer notifications are blocked. Open Settings to allow Kheir to send notifications.")
            }
            .confirmationDialog("Delete your iCloud backup?", isPresented: $showDeleteBackup, titleVisibility: .visible) {
                Button("Delete Backup", role: .destructive) {
                    backup.deleteBackup()
                    backup.setEnabled(false)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Everything stays on this iPhone. A new iPhone won't be able to restore it.")
            }
    }
}

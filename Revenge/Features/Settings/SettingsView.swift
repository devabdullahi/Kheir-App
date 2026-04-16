import SwiftUI
import UserNotifications

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.colorScheme) private var colorScheme

    // Notification permission alert state
    @State private var showPermissionDeniedAlert = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // MARK: - Header
                settingsHeader
                    .scrollReveal(delay: 0)

                // MARK: - Appearance
                appearanceCard
                    .scrollReveal(delay: 0.1)

                // MARK: - Quran
                quranCard
                    .scrollReveal(delay: 0.2)

                // MARK: - Prayer Times
                prayerCard
                    .scrollReveal(delay: 0.3)

                // MARK: - Notifications
                notificationsCard
                    .scrollReveal(delay: 0.4)

                // MARK: - Location
                locationCard
                    .scrollReveal(delay: 0.5)

                // MARK: - About
                aboutCard
                    .scrollReveal(delay: 0.6)

                // MARK: - Credits
                creditsCard
                    .scrollReveal(delay: 0.7)
            }
            .padding()
        }
        .background(
            ZStack {
                Color.adaptiveBackground(colorScheme).ignoresSafeArea()
                IslamicPatternBackground(colorScheme: colorScheme)
                    .opacity(0.04)
                    .ignoresSafeArea()
            }
        )
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .alert("Notifications Disabled", isPresented: $showPermissionDeniedAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Prayer notifications are blocked. Open Settings to allow Kheir to send notifications.")
        }
        .accessibilityIdentifier("settingsScrollView")
    }

    // MARK: - Settings Header

    private var settingsHeader: some View {
        VStack(spacing: 6) {
            Text("Settings")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(Color.adaptiveText(colorScheme))
            Text("Personalise your Kheir experience")
                .font(.subheadline)
                .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
        .accessibilityIdentifier("settingsHeader")
    }

    // MARK: - Section Label Helper

    private func sectionLabel(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption)
                .fontWeight(.semibold)
            Text(title.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .kerning(0.5)
        }
        .foregroundStyle(Color.adaptivePrimary(colorScheme))
    }

    // MARK: - Row Divider

    private var rowDivider: some View {
        Divider()
            .background(Color.adaptiveSecondaryText(colorScheme).opacity(0.2))
    }

    // MARK: - Appearance Card

    private var appearanceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("Appearance", systemImage: "paintpalette")

            rowDivider

            // Theme picker
            VStack(alignment: .leading, spacing: 6) {
                Text("Theme")
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Picker("Theme", selection: $settings.appTheme) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("themePicker")
            }

            rowDivider

            // Arabic font size slider
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Arabic Font Size")
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Spacer()
                    Text("\(Int(settings.arabicFontSize))")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.adaptivePrimary(colorScheme))
                        .monospacedDigit()
                        .accessibilityIdentifier("arabicFontSizeValue")
                }
                Slider(value: $settings.arabicFontSize, in: 20...44, step: 2)
                    .tint(Color.adaptivePrimary(colorScheme))
                    .accessibilityIdentifier("arabicFontSizeSlider")

                // Live preview
                Text("بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ")
                    .arabicFont(size: CGFloat(settings.arabicFontSize))
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .accessibilityLabel("Arabic font preview: In the name of Allah, the Most Gracious, the Most Merciful")
            }

            // MVP: hidden per PM decision; transliteration deferred to Phase 2
            // Toggle("Show Transliteration", isOn: $settings.showTransliteration)
            //     .tint(Color.adaptivePrimary(colorScheme))
        }
        .cardStyle(colorScheme)
        .accessibilityIdentifier("appearanceCard")
    }

    // MARK: - Quran Card

    private var quranCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("Quran", systemImage: "book.closed")

            rowDivider

            settingsPickerRow(
                label: "Translation",
                systemImage: "translate",
                accessibilityId: "translationLanguagePicker"
            ) {
                Picker("Translation Language", selection: $settings.translationLanguage) {
                    ForEach(TranslationLanguage.allCases, id: \.self) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .labelsHidden()
            }

            rowDivider

            settingsPickerRow(
                label: "Default Reciter",
                systemImage: "waveform",
                accessibilityId: "reciterPicker"
            ) {
                Picker("Default Reciter", selection: $settings.selectedQari) {
                    ForEach(Qari.defaults) { qari in
                        Text(qari.name).tag(qari.identifier)
                    }
                }
                .labelsHidden()
            }
        }
        .cardStyle(colorScheme)
        .accessibilityIdentifier("quranCard")
    }

    // MARK: - Prayer Times Card

    private var prayerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("Prayer Times", systemImage: "clock")

            rowDivider

            settingsPickerRow(
                label: "Calculation Method",
                systemImage: "function",
                accessibilityId: "calculationMethodPicker"
            ) {
                Picker("Calculation Method", selection: $settings.calculationMethod) {
                    ForEach(CalculationMethodOption.allCases, id: \.self) { method in
                        Text(method.displayName).tag(method)
                    }
                }
                .labelsHidden()
            }

            rowDivider

            settingsPickerRow(
                label: "Madhab",
                systemImage: "rays",
                accessibilityId: "madhabPicker"
            ) {
                Picker("Madhab", selection: $settings.madhab) {
                    ForEach(MadhabOption.allCases, id: \.self) { madhab in
                        Text(madhab.rawValue).tag(madhab)
                    }
                }
                .labelsHidden()
            }
        }
        .cardStyle(colorScheme)
        .accessibilityIdentifier("prayerCard")
    }

    // MARK: - Notifications Card

    private var notificationsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("Notifications", systemImage: "bell")

            rowDivider

            notificationToggle("Fajr", isOn: $settings.fajrNotification)
                .accessibilityIdentifier("fajrNotificationToggle")

            rowDivider

            notificationToggle("Sunrise", isOn: $settings.sunriseNotification)
                .accessibilityIdentifier("sunriseNotificationToggle")

            rowDivider

            notificationToggle("Dhuhr", isOn: $settings.dhuhrNotification)
                .accessibilityIdentifier("dhuhrNotificationToggle")

            rowDivider

            notificationToggle("Asr", isOn: $settings.asrNotification)
                .accessibilityIdentifier("asrNotificationToggle")

            rowDivider

            notificationToggle("Maghrib", isOn: $settings.maghribNotification)
                .accessibilityIdentifier("maghribNotificationToggle")

            rowDivider

            notificationToggle("Isha", isOn: $settings.ishaNotification)
                .accessibilityIdentifier("ishaNotificationToggle")

            rowDivider

            Button {
                NotificationService.shared.sendTestNotification()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "bell.badge")
                        .foregroundStyle(Color.adaptivePrimary(colorScheme))
                    Text("Send Test Notification")
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptivePrimary(colorScheme))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                }
            }
            .accessibilityLabel("Send Test Notification")
            .accessibilityIdentifier("sendTestNotificationButton")
        }
        .cardStyle(colorScheme)
        .accessibilityIdentifier("notificationsCard")
    }

    // MARK: - Location Card

    private var locationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("Location", systemImage: "location")

            rowDivider

            HStack {
                Image(systemName: "location.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptivePrimary(colorScheme))
                    .frame(width: 20)
                Toggle("Use GPS Location", isOn: $settings.useAutoLocation)
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .tint(Color.adaptivePrimary(colorScheme))
                    .accessibilityIdentifier("useGPSToggle")
            }

            if !settings.useAutoLocation {
                rowDivider

                HStack {
                    Image(systemName: "building.2")
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptivePrimary(colorScheme))
                        .frame(width: 20)
                    TextField("Enter city name", text: $settings.manualCity)
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .accessibilityIdentifier("manualCityField")
                }
            }

            rowDivider

            settingsPickerRow(
                label: "Distance Unit",
                systemImage: "ruler",
                accessibilityId: "distanceUnitPicker"
            ) {
                Picker("Distance Unit", selection: $settings.distanceUnit) {
                    ForEach(DistanceUnit.allCases, id: \.self) { unit in
                        Text(unit.displayName).tag(unit)
                    }
                }
                .labelsHidden()
            }
        }
        .cardStyle(colorScheme)
        .accessibilityIdentifier("locationCard")
    }

    // MARK: - About Card

    private var aboutCard: some View {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

        return VStack(alignment: .leading, spacing: 14) {
            sectionLabel("About", systemImage: "info.circle")

            rowDivider

            // App identity block
            HStack(spacing: 14) {
                Image("AppIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Kheir")
                        .font(.headline)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Text("Your daily Islamic companion")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                    Text("Version \(version) (\(build))")
                        .font(.caption2)
                        .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                        .accessibilityIdentifier("appVersionLabel")
                }
            }

            rowDivider

            // Rate on App Store
            Button {
                // Replace with actual App Store ID when available
                if let url = URL(string: "https://apps.apple.com/app/idYOUR_APP_ID") {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(Color.adaptivePrimary(colorScheme))
                    Text("Rate Kheir on the App Store")
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                }
            }
            .accessibilityIdentifier("rateAppButton")

            rowDivider

            // Privacy Policy
            Button {
                if let url = URL(string: "https://kheir.app/privacy") {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "lock.shield")
                        .foregroundStyle(Color.adaptivePrimary(colorScheme))
                    Text("Privacy Policy")
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                }
            }
            .accessibilityIdentifier("privacyPolicyButton")
        }
        .cardStyle(colorScheme)
        .accessibilityIdentifier("aboutCard")
    }

    // MARK: - Credits Card

    private var creditsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("Data Providers", systemImage: "server.rack")

            rowDivider

            creditRow(
                name: "Al-Quran Cloud",
                description: "Quran text & translations",
                url: "https://alquran.cloud",
                systemImage: "book.pages"
            )

            rowDivider

            creditRow(
                name: "Fawazahmed0 Hadith API",
                description: "Hadith collections & grades",
                url: "https://github.com/fawazahmed0/hadith-api",
                systemImage: "text.quote"
            )

            rowDivider

            creditRow(
                name: "Aladhan Prayer Times",
                description: "Prayer time calculations",
                url: "https://aladhan.com",
                systemImage: "clock.badge"
            )

            rowDivider

            creditRow(
                name: "Adhan Swift",
                description: "Prayer times library by Batoul Apps",
                url: "https://github.com/batoulapps/adhan-swift",
                systemImage: "waveform.path.ecg"
            )
        }
        .cardStyle(colorScheme)
        .accessibilityIdentifier("creditsCard")
    }

    // MARK: - Credit Row Helper

    private func creditRow(
        name: String,
        description: String,
        url: String,
        systemImage: String
    ) -> some View {
        Button {
            if let link = URL(string: url) {
                UIApplication.shared.open(link)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptivePrimary(colorScheme))
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.caption2)
                    .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
            }
        }
        .accessibilityLabel("\(name): \(description). Opens in browser.")
    }

    // MARK: - Settings Picker Row Helper

    @ViewBuilder
    private func settingsPickerRow<P: View>(
        label: String,
        systemImage: String,
        accessibilityId: String,
        @ViewBuilder picker: () -> P
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.subheadline)
                .foregroundStyle(Color.adaptivePrimary(colorScheme))
                .frame(width: 22)

            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.adaptiveText(colorScheme))

            Spacer()

            picker()
                .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                .accessibilityIdentifier(accessibilityId)
        }
    }

    // MARK: - Notification Toggle Helper

    /// Wraps a prayer notification toggle with contextual permission handling.
    /// - When flipping to true with `.notDetermined` status: requests permission first.
    /// - When flipping to true with `.denied` status: shows "Open Settings" alert.
    @ViewBuilder
    private func notificationToggle(_ label: String, isOn binding: Binding<Bool>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: binding.wrappedValue ? "bell.fill" : "bell")
                .font(.subheadline)
                .foregroundStyle(Color.adaptivePrimary(colorScheme))
                .frame(width: 22)
                .contentTransition(.symbolEffect(.replace))

            Toggle(label, isOn: Binding(
                get: { binding.wrappedValue },
                set: { newValue in
                    guard newValue else {
                        // Turning off — no permission check needed
                        binding.wrappedValue = false
                        return
                    }
                    // Turning on — check current authorization status
                    UNUserNotificationCenter.current().getNotificationSettings { settings in
                        DispatchQueue.main.async {
                            switch settings.authorizationStatus {
                            case .authorized, .provisional, .ephemeral:
                                binding.wrappedValue = true
                            case .notDetermined:
                                Task {
                                    let granted = await NotificationService.shared.requestPermission()
                                    binding.wrappedValue = granted
                                }
                            case .denied:
                                showPermissionDeniedAlert = true
                                // Leave binding as false; user must re-tap after fixing in Settings
                            @unknown default:
                                binding.wrappedValue = true
                            }
                        }
                    }
                }
            ))
            .font(.subheadline)
            .foregroundStyle(Color.adaptiveText(colorScheme))
            .tint(Color.adaptivePrimary(colorScheme))
        }
    }
}

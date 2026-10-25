import SwiftUI

/// Home: a paper sky diorama with the greeting and the next prayer, then the
/// day's cards on the table, ordered by what the user asked Kheir to help with.
struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @State private var prayerCountdownVM = PrayerCountdownViewModel()
    @State private var skyEngine = SkyEngine()
    @Environment(\.colorScheme) private var colorScheme
    @State private var showShareSheet = false
    @State private var shareText = ""
    @State private var shareCardData: ShareCardData?
    @State private var showArabicHadith = false
    @State private var entered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var settings: AppSettings { .shared }

    /// The order of the cards on the table.
    private enum Slot: Hashable {
        case date, journey, streak, intention(Intention), offline, ayah, hadith
    }

    var body: some View {
        GeometryReader { proxy in
            let topInset = proxy.safeAreaInsets.top
            ScrollView {
                VStack(spacing: 0) {
                    skyHeader(topInset: topInset)

                    VStack(spacing: DesignTokens.cardGap + 2) {
                        ForEach(Array(slots.enumerated()), id: \.element) { index, slot in
                            card(for: slot)
                                .homeEnter(index: index, entered: entered, reduceMotion: reduceMotion)
                        }
                    }
                    .padding(.horizontal, DesignTokens.spacingLG)
                    .padding(.top, -24)
                    .padding(.bottom, DesignTokens.spacingXXL)
                }
            }
            .ignoresSafeArea(edges: .top)
            .refreshable {
                await viewModel.refresh()
            }
        }
        .paperBackground()
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            viewModel.onAppear()
            viewModel.checkBookmarkStates()
            prayerCountdownVM.onAppear()
            entered = true
        }
        .onChange(of: viewModel.dailyAyah?.surahNumber) { _, _ in
            viewModel.checkBookmarkStates()
        }
        .onChange(of: viewModel.dailyHadith?.text) { _, _ in
            viewModel.checkBookmarkStates()
        }
        .onChange(of: prayerCountdownVM.todayPrayerTimes?.fajr) { _, _ in
            if let times = prayerCountdownVM.todayPrayerTimes {
                skyEngine.loadPrayerTimes(times.all.map { ($0.name, $0.time) })
            }
        }
        .onDisappear {
            viewModel.onDisappear()
            prayerCountdownVM.onDisappear()
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(text: shareText)
        }
        .sheet(item: $shareCardData) { cardData in
            ShareSheetView(data: cardData)
        }
    }

    // MARK: - Order

    private var slots: [Slot] {
        let all = Intention.allCases
        let picked = all.filter { settings.intentions.contains($0) }
        let rest = all.filter { !settings.intentions.contains($0) }
        var out: [Slot] = [.date]
        if hasJourneyCard { out.append(.journey) }
        if viewModel.streakData != nil { out.append(.streak) }
        out += picked.map(Slot.intention)
        if viewModel.ayahState == .offline || viewModel.hadithState == .offline { out.append(.offline) }
        out += [.ayah, .hadith]
        out += rest.map(Slot.intention)
        return out
    }

    private var hasJourneyCard: Bool {
        switch settings.journey {
        case .newToIslam: true
        case .deeper: viewModel.dailyAyah != nil
        default: false
        }
    }

    @ViewBuilder
    private func card(for slot: Slot) -> some View {
        switch slot {
        case .date:
            dateCard
        case .journey:
            if settings.journey == .newToIslam {
                StartHereCard()
            } else if let ayah = viewModel.dailyAyah {
                TafsirCard(ayah: ayah)
            }
        case .streak:
            if let streakData = viewModel.streakData {
                StreakCardView(streakData: streakData)
            }
        case .intention(let intention):
            intentionCard(intention)
        case .offline:
            offlineBanner
        case .ayah:
            ayahSection
        case .hadith:
            hadithSection
        }
    }

    @ViewBuilder
    private func intentionCard(_ intention: Intention) -> some View {
        switch intention {
        case .prayOnTime:
            NextPrayerCard(
                prayerName: prayerCountdownVM.nextPrayerName,
                prayerTime: prayerCountdownVM.nextPrayerTime,
                countdown: countdown
            )
        case .readQuran:
            QuranGoalCard(goal: settings.quranGoal, lastSurah: settings.lastReadSurah, lastAyah: settings.lastReadAyah)
        case .adhkar:
            RoutineCardView(
                routineType: viewModel.currentRoutineType,
                progress: viewModel.routineProgress
            )
            .task { await viewModel.refreshRoutineProgress() }
        case .journal:
            ReflectCard()
        case .masjids:
            MasjidCard()
        }
    }

    // MARK: - Sky header

    private func skyHeader(topInset: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            DynamicSkyView(skyState: skyEngine.currentState)

            VStack(spacing: 2) {
                Text(greeting.uppercased())
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .tracking(2)
                    .opacity(0.88)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if prayerCountdownVM.nextPrayerTime != nil {
                    Text(countdown)
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText(countsDown: true))
                }
                if !prayerCountdownVM.nextPrayerName.isEmpty {
                    Text(untilLine)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .opacity(0.82)
                }
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.28), radius: 0, x: 0, y: 1)
            .shadow(color: .black.opacity(0.35), radius: 4)
            .padding(.horizontal, 60)
            .padding(.bottom, 44)
            .accessibilityElement(children: .combine)
        }
        .frame(height: topInset + 210)
        .overlay(alignment: .topTrailing) {
            settingsButton
                .padding(.top, topInset + 4)
                .padding(.trailing, 16)
        }
    }

    private var settingsButton: some View {
        NavigationLink(destination: SettingsView()) {
            PaperIconView(.gear, size: 18)
                .padding(7)
                .paperPiece(Color.adaptiveCardSurface(colorScheme), material: .card, depth: 1.4, radius: 20, seed: 48, padding: nil)
                .rotationEffect(.degrees(6))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PaperPressStyle())
        .accessibilityLabel("Open Settings")
        .accessibilityIdentifier("openSettingsButton")
    }

    private var greeting: String {
        let name = settings.userName.trimmingCharacters(in: .whitespacesAndNewlines)
        let hello: String
        if settings.journey == .newToIslam {
            hello = "Welcome"
        } else {
            hello = Calendar.current.component(.hour, from: .now) < 12 ? "Sabāḥ al-khayr" : "Masāʾ al-khayr"
        }
        return name.isEmpty ? hello : "\(hello), \(name)"
    }

    /// Re-read every second because `countdownText` ticks on the view model's timer.
    private var countdown: String {
        _ = prayerCountdownVM.countdownText
        return HomeFormat.countdown(to: prayerCountdownVM.nextPrayerTime)
    }

    private var untilLine: String {
        let name = prayerCountdownVM.nextPrayerName
        guard let time = prayerCountdownVM.nextPrayerTime else { return "until \(name)" }
        return "until \(name) · \(HomeFormat.time(time))"
    }

    // MARK: - Date card

    private var dateCard: some View {
        let flower = DailyFlower.forDate(.now)
        return HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.gregorianDate)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Text(viewModel.hijriDate)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
            }
            Spacer(minLength: 8)
            VStack(spacing: -2) {
                DailyFlowerView(date: .now, size: 40)
                    .frame(width: 44, height: 48)
                Text(flower.species.name)
                    .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                    .tracking(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
            }
            .padding(.vertical, -10)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Today's flower: \(flower.species.name)")
        }
        .cardStyle(colorScheme, seed: 41)
        .rotationEffect(.degrees(-0.3))
    }

    // MARK: - Daily Ayah

    @ViewBuilder
    private var ayahSection: some View {
        switch viewModel.ayahState {
        case .loading:
            ayahSkeletonCard
        case .loaded, .offline:
            if let ayah = viewModel.dailyAyah {
                dailyAyahCard(ayah)
            }
        case .failed:
            ayahErrorCard
        }
    }

    private func dailyAyahCard(_ ayah: DailyAyah) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                PaperTag(text: "Daily Ayah", color: .islamicGold, ink: .lightBodyText, seed: 5)
                Spacer()
                Button {
                    withAnimation(.open(0.2)) {
                        viewModel.toggleAyahBookmark()
                    }
                } label: {
                    Image(systemName: viewModel.isAyahBookmarked ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.adaptivePrimary(colorScheme))
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PaperPressStyle())
                .accessibilityLabel(viewModel.isAyahBookmarked ? "Remove ayah bookmark" : "Bookmark ayah")

                Button {
                    shareCardData = ShareCardData(
                        content: ayah.translationText,
                        arabicText: ayah.arabicText,
                        reference: "\(ayah.surahEnglishName) (\(ayah.surahNumber):\(ayah.ayahNumber))",
                        template: .minimal,
                        type: .ayah
                    )
                } label: {
                    PaperIconView(.share, size: 18)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PaperPressStyle())
                .accessibilityLabel("Share ayah")
            }

            Text(ayah.arabicText)
                .arabicFont(size: CGFloat(settings.arabicFontSize))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(Color.adaptiveText(colorScheme))

            if !ayah.transliteration.isEmpty && settings.showTransliteration {
                Text(ayah.transliteration)
                    .font(.system(size: 13, design: .rounded))
                    .italic()
                    .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
            }

            Text(ayah.translationText)
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(Color.adaptiveText(colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            Text("\(ayah.surahEnglishName) (\(ayah.surahNumber):\(ayah.ayahNumber))")
                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
        }
        .featuredCardStyle(colorScheme, seed: 44)
        .accessibilityIdentifier("dailyAyahCard")
    }

    // MARK: - Daily Hadith

    @ViewBuilder
    private var hadithSection: some View {
        switch viewModel.hadithState {
        case .loading:
            hadithSkeletonCard
        case .loaded, .offline:
            if let hadith = viewModel.dailyHadith {
                dailyHadithCard(hadith)
            }
        case .failed:
            hadithErrorCard
        }
    }

    private func dailyHadithCard(_ hadith: DailyHadith) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                PaperTag(text: "Daily Hadith", color: .paperRose, ink: .lightBodyText, seed: 6)
                Spacer()
                Button {
                    showArabicHadith.toggle()
                } label: {
                    Image(systemName: showArabicHadith ? "character.paragraph" : "globe")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.adaptivePrimary(colorScheme))
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PaperPressStyle())
                .accessibilityLabel(showArabicHadith ? "Show English Hadith" : "Show Arabic Hadith")
                .accessibilityIdentifier("toggleHadithLanguageButton")
            }

            Group {
                if showArabicHadith, !hadith.arabicText.isEmpty {
                    Text(hadith.arabicText)
                        .arabicFont(size: CGFloat(settings.arabicFontSize))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .multilineTextAlignment(.trailing)
                } else {
                    Text(hadith.text)
                        .font(.system(size: 15, design: .rounded))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .foregroundStyle(Color.adaptiveText(colorScheme))

            VStack(alignment: .leading, spacing: 3) {
                Text(hadith.source)
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.adaptivePrimary(colorScheme))
                if !hadith.narrator.isEmpty {
                    Text("Narrated by \(hadith.narrator)")
                        .font(.system(size: 12.5, design: .rounded))
                        .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                }
            }

            HStack {
                PaperTag(text: "Grade: \(hadith.grade)", color: Color(hex: "#7FAE7A"), ink: .lightBodyText, seed: 7)
                Spacer()
                Button {
                    withAnimation(.open(0.2)) {
                        viewModel.toggleHadithBookmark()
                    }
                } label: {
                    Image(systemName: viewModel.isHadithBookmarked ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.adaptivePrimary(colorScheme))
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PaperPressStyle())
                .accessibilityLabel(viewModel.isHadithBookmarked ? "Remove hadith bookmark" : "Bookmark hadith")

                Button {
                    shareCardData = ShareCardData(
                        content: hadith.text,
                        arabicText: hadith.arabicText,
                        reference: hadith.source,
                        template: .minimal,
                        type: .hadith
                    )
                } label: {
                    PaperIconView(.share, size: 18)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PaperPressStyle())
                .accessibilityLabel("Share hadith")
            }
        }
        .cardStyle(colorScheme, seed: 45)
        .rotationEffect(.degrees(-0.4))
        .accessibilityIdentifier("dailyHadithCard")
    }

    // MARK: - Offline Banner

    private var offlineBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.caption)
            Text("Showing cached content — offline")
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
            Spacer(minLength: 0)
        }
        .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .paperPiece(Color.adaptiveCardElevated(colorScheme), material: .tissue, depth: 0.5, edge: .torn, radius: 4, seed: 46, padding: nil)
        .accessibilityIdentifier("offlineBanner")
    }

    // MARK: - Skeletons and errors

    private var ayahSkeletonCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            PaperTag(text: "Daily Ayah", color: .islamicGold, ink: .lightBodyText, seed: 5)

            Text("بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ — Loading verse — Arabic text placeholder")
                .arabicFont(size: CGFloat(settings.arabicFontSize))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(Color.adaptiveText(colorScheme))
                .redacted(reason: .placeholder)

            Text("Translation placeholder — the meaning of this verse will appear here once loaded.")
                .font(.body)
                .foregroundStyle(Color.adaptiveText(colorScheme))
                .redacted(reason: .placeholder)
        }
        .featuredCardStyle(colorScheme, seed: 44)
    }

    private var ayahErrorCard: some View {
        errorCard(message: "Couldn't load today's verse", identifier: "retryAyahButton", seed: 44) {
            await viewModel.retryAyah()
        }
    }

    private var hadithSkeletonCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            PaperTag(text: "Daily Hadith", color: .paperRose, ink: .lightBodyText, seed: 6)

            Text("Hadith text placeholder — the narration will appear here once the content has been loaded from the server.")
                .font(.body)
                .foregroundStyle(Color.adaptiveText(colorScheme))
                .redacted(reason: .placeholder)

            Text("Narrated by Narrator Name")
                .font(.caption)
                .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                .redacted(reason: .placeholder)
        }
        .cardStyle(colorScheme, seed: 45)
    }

    private var hadithErrorCard: some View {
        errorCard(message: "Couldn't load today's hadith", identifier: "retryHadithButton", seed: 45) {
            await viewModel.retryHadith()
        }
    }

    private func errorCard(message: String, identifier: String, seed: Int, retry: @escaping @MainActor () async -> Void) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle")
                Text(message)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Spacer()
            }
            .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))

            Button {
                Task { await retry() }
            } label: {
                Text("Retry")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.lightCardSurface)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 8)
                    .paperPiece(Color.adaptivePrimary(colorScheme), material: .construction, depth: 1, radius: 6, seed: seed + 100, padding: nil)
            }
            .buttonStyle(PaperPressStyle())
            .accessibilityIdentifier(identifier)
        }
        .cardStyle(colorScheme, seed: seed)
    }
}

// MARK: - Entrance

private extension View {
    /// A quick, light stagger: Home opens many times a day, so pieces only settle
    /// a few points onto the table (≈35 ms apart, 0.3 s each).
    func homeEnter(index: Int, entered: Bool, reduceMotion: Bool) -> some View {
        let lifted = !entered && !reduceMotion
        return self
            .opacity(lifted ? 0 : 1)
            .offset(y: lifted ? -6 : 0)
            .scaleEffect(lifted ? 1.015 : 1)
            .animation(reduceMotion ? nil : .open(0.3).delay(Double(min(index, 8)) * 0.035), value: entered)
    }
}

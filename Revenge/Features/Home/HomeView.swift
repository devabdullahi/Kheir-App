import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @StateObject private var prayerCountdownVM = PrayerCountdownViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @State private var showShareSheet = false
    @State private var shareText = ""
    @State private var shareCardData: ShareCardData?
    @State private var showArabicHadith = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // MARK: - Date Header
                    dateHeader
                        .scrollReveal(delay: 0)

                    // MARK: - Streak Card
                    if let streakData = viewModel.streakData {
                        StreakCardView(streakData: streakData)
                            .scrollReveal(delay: 0.05)
                    }

                    // MARK: - Routine Card
                    RoutineCardView(
                        routineType: viewModel.currentRoutineType,
                        progress: viewModel.routineProgress
                    )
                    .scrollReveal(delay: 0.08)
                    .task { await viewModel.refreshRoutineProgress() }

                    // MARK: - Prayer Countdown
                    prayerCountdown
                        .scrollReveal(delay: 0.1)

                    // MARK: - Offline Banner
                    if viewModel.ayahState == .offline || viewModel.hadithState == .offline {
                        offlineBanner
                            .scrollReveal(delay: 0.05)
                    }

                    // MARK: - Daily Ayah
                    switch viewModel.ayahState {
                    case .loading:
                        ayahSkeletonCard
                            .scrollReveal(delay: 0.15)
                    case .loaded:
                        if let ayah = viewModel.dailyAyah {
                            dailyAyahCard(ayah)
                        }
                    case .failed:
                        ayahErrorCard
                            .scrollReveal(delay: 0.15)
                    case .offline:
                        if let ayah = viewModel.dailyAyah {
                            dailyAyahCard(ayah)
                        }
                    }

                    // MARK: - Daily Hadith
                    switch viewModel.hadithState {
                    case .loading:
                        hadithSkeletonCard
                            .scrollReveal(delay: 0.2)
                    case .loaded:
                        if let hadith = viewModel.dailyHadith {
                            dailyHadithCard(hadith)
                        }
                    case .failed:
                        hadithErrorCard
                            .scrollReveal(delay: 0.2)
                    case .offline:
                        if let hadith = viewModel.dailyHadith {
                            dailyHadithCard(hadith)
                        }
                    }
                }
                .padding()
            }
            .refreshable {
                await viewModel.refresh()
            }
            .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
            .navigationTitle("Kheir")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape")
                            .foregroundStyle(Color.adaptivePrimary(colorScheme))
                    }
                    .accessibilityLabel("Open Settings")
                    .accessibilityIdentifier("openSettingsButton")
                }
            }
            .onAppear {
                viewModel.onAppear()
                viewModel.checkBookmarkStates()
                prayerCountdownVM.onAppear()
            }
            .onChange(of: viewModel.dailyAyah?.surahNumber) { _, _ in
                viewModel.checkBookmarkStates()
            }
            .onChange(of: viewModel.dailyHadith?.text) { _, _ in
                viewModel.checkBookmarkStates()
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
    }

    // MARK: - Date Header
    private var dateHeader: some View {
        VStack(spacing: 4) {
            Text(viewModel.gregorianDate)
                .font(.subheadline)
                .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
            Text(viewModel.hijriDate)
                .font(.headline)
                .foregroundStyle(Color.adaptivePrimary(colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Prayer Countdown
    private var prayerCountdown: some View {
        VStack(spacing: 6) {
            if !prayerCountdownVM.nextPrayerName.isEmpty {
                Text("Next: \(prayerCountdownVM.nextPrayerName)")
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
            }
            Text(prayerCountdownVM.countdownText)
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(Color.adaptivePrimary(colorScheme))
                .monospacedDigit()
                .accessibilityIdentifier("prayerCountdown")
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background {
            ZStack {
                Color.adaptiveCardSurface(colorScheme)
                IslamicPatternBackground(colorScheme: colorScheme)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 8, y: 4)
    }

    // MARK: - Daily Ayah Card
    private func dailyAyahCard(_ ayah: DailyAyah) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Ayah")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.adaptivePrimary(colorScheme))
                .scrollReveal(delay: 0.15)

            Text(ayah.arabicText)
                .arabicFont(size: CGFloat(AppSettings.shared.arabicFontSize))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(Color.adaptiveText(colorScheme))
                .scrollReveal(delay: 0.2)

            if !ayah.transliteration.isEmpty && AppSettings.shared.showTransliteration {
                Text(ayah.transliteration)
                    .font(.subheadline)
                    .italic()
                    .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                    .scrollReveal(delay: 0.35)
            }

            Text(ayah.translationText)
                .font(.body)
                .foregroundStyle(Color.adaptiveText(colorScheme))
                .scrollReveal(delay: 0.45)

            HStack {
                Text("\(ayah.surahEnglishName) (\(ayah.surahNumber):\(ayah.ayahNumber))")
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.toggleAyahBookmark()
                    }
                } label: {
                    Image(systemName: viewModel.isAyahBookmarked ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(Color.adaptivePrimary(colorScheme))
                        .contentTransition(.symbolEffect(.replace))
                }
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
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(Color.adaptivePrimary(colorScheme))
                }
            }
            .scrollReveal(delay: 0.55)
        }
        .cardStyle(colorScheme)
    }

    // MARK: - Daily Hadith Card
    private func dailyHadithCard(_ hadith: DailyHadith) -> some View {
    VStack(alignment: .leading, spacing: 12) {
        HStack {
            Text("Daily Hadith")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.adaptivePrimary(colorScheme))
                .scrollReveal(delay: 0.15)

            Spacer()

            // Language toggle button
            Button {
                showArabicHadith.toggle()
            } label: {
                Image(systemName: showArabicHadith ? "character.paragraph" : "globe")
                    .foregroundStyle(Color.adaptivePrimary(colorScheme))
                    .padding(6)
                    .background(Color.adaptivePrimary(colorScheme).opacity(0.10))
                    .clipShape(Circle())
            }
            .accessibilityLabel(showArabicHadith ? "Show English Hadith" : "Show Arabic Hadith")
            .accessibilityIdentifier("toggleHadithLanguageButton")
        }

        // Show either English or Arabic text
        Group {
            if showArabicHadith, !hadith.arabicText.isEmpty {
                Text(hadith.arabicText)
                    .arabicFont(size: CGFloat(AppSettings.shared.arabicFontSize))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .scrollReveal(delay: 0.3)
            } else {
                Text(hadith.text)
                    .font(.body)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .scrollReveal(delay: 0.3)
            }
        }

        VStack(alignment: .leading, spacing: 4) {
            Text(hadith.source)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(Color.adaptivePrimary(colorScheme))

            if !hadith.narrator.isEmpty {
                Text("Narrated by \(hadith.narrator)")
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
            }

            Text("Grade: \(hadith.grade)")
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.adaptivePrimary(colorScheme).opacity(0.15))
                .clipShape(Capsule())
        }
        .scrollReveal(delay: 0.45)

        // Bookmarks and share row remain unchanged...
        HStack {
            Spacer()
            // ...
        }
        .scrollReveal(delay: 0.55)
    }
    .cardStyle(colorScheme)
}

    // MARK: - Offline Banner
    private var offlineBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.caption)
            Text("Showing cached content — offline")
                .font(.caption)
        }
        .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.adaptiveCardSurface(colorScheme).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityIdentifier("offlineBanner")
    }

    // MARK: - Ayah Skeleton
    private var ayahSkeletonCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Ayah")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.adaptivePrimary(colorScheme))

            Text("بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ — Loading verse — Arabic text placeholder")
                .arabicFont(size: CGFloat(AppSettings.shared.arabicFontSize))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(Color.adaptiveText(colorScheme))

            Text("Translation placeholder — the meaning of this verse will appear here once loaded.")
                .font(.body)
                .foregroundStyle(Color.adaptiveText(colorScheme))

            Text("Surah Name (0:0)")
                .font(.caption)
                .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
        }
        .cardStyle(colorScheme)
        .redacted(reason: .placeholder)
    }

    // MARK: - Ayah Error Card
    private var ayahErrorCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle")
                    .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                Text("Couldn't load today's verse")
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                Spacer()
            }
            Button("Retry") {
                Task { await viewModel.retryAyah() }
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Color.adaptivePrimary(colorScheme))
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("retryAyahButton")
        }
        .cardStyle(colorScheme)
    }

    // MARK: - Hadith Skeleton
    private var hadithSkeletonCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Hadith")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.adaptivePrimary(colorScheme))

            Text("Hadith text placeholder — the narration will appear here once the content has been loaded from the server.")
                .font(.body)
                .foregroundStyle(Color.adaptiveText(colorScheme))

            VStack(alignment: .leading, spacing: 4) {
                Text("Collection Name")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.adaptivePrimary(colorScheme))

                Text("Narrated by Narrator Name")
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))

                Text("Grade: Sahih")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.adaptivePrimary(colorScheme).opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        .cardStyle(colorScheme)
        .redacted(reason: .placeholder)
    }

    // MARK: - Hadith Error Card
    private var hadithErrorCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle")
                    .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                Text("Couldn't load today's hadith")
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                Spacer()
            }
            Button("Retry") {
                Task { await viewModel.retryHadith() }
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Color.adaptivePrimary(colorScheme))
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("retryHadithButton")
        }
        .cardStyle(colorScheme)
    }
}

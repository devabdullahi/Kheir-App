import SwiftUI

struct ReadingView: View {
    @State private var viewModel: ReadingViewModel
    private var audioPlayer = AudioPlayerService.shared
    @Bindable private var settings = AppSettings.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showQariPicker = false
    @State private var copiedAyahID: Int?

    init(surahNumber: Int, scrollToAyah: Int? = nil) {
        _viewModel = State(wrappedValue: ReadingViewModel(surahNumber: surahNumber, scrollToAyah: scrollToAyah))
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 14) {
                    surahHeaderCard
                        .quickPlace(0)

                    ForEach(Array(viewModel.displayAyahs.enumerated()), id: \.element.id) { index, ayah in
                        ayahCard(ayah, index: index)
                            .id(ayah.numberInSurah)
                            .quickPlace(index < 8 ? index + 1 : 0)
                            .onAppear {
                                viewModel.saveReadingPosition(ayah: ayah.numberInSurah)
                            }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 110)
            }
            .onAppear {
                if let scrollTo = viewModel.scrollToAyah {
                    Task {
                        try? await Task.sleep(for: .milliseconds(500))
                        withAnimation(reduceMotion ? .none : .travel(0.4)) {
                            proxy.scrollTo(scrollTo, anchor: .top)
                        }
                    }
                }
            }
            .onChange(of: audioPlayer.currentAyahIndex) { _, newIndex in
                withAnimation(reduceMotion ? .none : .travel(0.35)) {
                    proxy.scrollTo(newIndex + 1, anchor: .center)
                }
            }
        }
        .paperBackground()
        .navigationTitle(viewModel.surahEnglishName)
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showQariPicker = true
                    } label: {
                        Label("Select Reciter", systemImage: "person.wave.2")
                    }

                    Toggle(isOn: $settings.showTransliteration) {
                        Label("Transliteration", systemImage: "character.textbox")
                    }
                } label: {
                    PaperIconView(.aa, size: 22)
                        .accessibilityLabel("Reading options")
                }
            }
        }
        .onAppear { viewModel.onAppear() }
        .overlay {
            if viewModel.isLoading && viewModel.displayAyahs.isEmpty {
                loadingOverlay
            } else if let error = viewModel.errorMessage, viewModel.displayAyahs.isEmpty {
                errorOverlay(error)
            }
        }
        .sheet(isPresented: $showQariPicker) {
            qariPickerSheet
        }
        // The felt player strip floats above the content without covering it.
        .safeAreaInset(edge: .bottom) {
            PlayerBar(totalAyahs: viewModel.displayAyahs.count)
                // The app's tab bar floats over the bottom ~110pt; sit above it.
                .padding(.bottom, audioPlayer.nowPlaying != nil ? 104 : 0)
                .animation(reduceMotion ? .none : .open(0.25), value: audioPlayer.nowPlaying != nil)
        }
    }

    // MARK: - Surah Header Card

    private var surahHeaderCard: some View {
        VStack(spacing: 8) {
            Text(viewModel.surahName)
                .arabicFont(size: 30)
                .foregroundStyle(Color.adaptivePrimary(colorScheme))
                .accessibilityLabel("Surah \(viewModel.surahEnglishName) in Arabic")

            if viewModel.surahNumber != 1 && viewModel.surahNumber != 9 {
                Text("بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ")
                    .arabicFont(size: 22)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .accessibilityLabel("Bismillah")
            }

            Text(viewModel.surahEnglishName)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .paperPiece(Color.adaptiveCardElevated(colorScheme), material: .card, depth: 0.7, edge: .torn, seed: 70)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Ayah Sheet

    private func ayahCard(_ ayah: DisplayAyah, index: Int) -> some View {
        let isActive = isPlaying(ayah)
        let isCopied = copiedAyahID == ayah.id
        let seed = 71 + ayah.numberInSurah

        return VStack(alignment: .leading, spacing: 12) {
            ayahActions(ayah, isCopied: isCopied, isPlaying: isActive)

            Text(ayah.arabicText)
                .arabicFont(size: CGFloat(settings.arabicFontSize))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(Color.adaptiveText(colorScheme))
                .lineSpacing(8)
                .accessibilityLabel(Text("Ayah \(ayah.numberInSurah)"))
                .accessibilityValue(Text(ayah.arabicText))

            if settings.showTransliteration && !ayah.transliteration.isEmpty {
                Text(ayah.transliteration)
                    .font(.system(size: 14, design: .rounded))
                    .italic()
                    .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel("Transliteration: \(ayah.transliteration)")
            }

            Text(ayah.translationText)
                .font(.system(size: 15.5, design: .serif))
                .foregroundStyle(Color.adaptiveText(colorScheme))
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineSpacing(4)
                .accessibilityLabel("Translation: \(ayah.translationText)")
        }
        .paperPiece(Color.adaptiveCardSurface(colorScheme), material: .card, depth: isActive ? 2.2 : 0.9, radius: 18, seed: seed, padding: 16)
        .rotationEffect(.degrees(isActive ? -0.6 : (seeded(seed, salt: 5) - 0.5) * 0.8))
        .scaleEffect(isActive ? 1.012 : 1)
        .animation(reduceMotion ? nil : .open(0.28), value: isActive)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Ayah \(ayah.numberInSurah)")
    }

    /// Whether this ayah is the one being recited right now.
    private func isPlaying(_ ayah: DisplayAyah) -> Bool {
        if let nowPlaying = audioPlayer.nowPlaying {
            return nowPlaying.surahNumber == viewModel.surahNumber
                && nowPlaying.ayahNumber == ayah.numberInSurah
                && audioPlayer.playerState == .playing
        }
        return audioPlayer.isPlaying && audioPlayer.currentAyahIndex == ayah.numberInSurah - 1
    }

    private func ayahActions(_ ayah: DisplayAyah, isCopied: Bool, isPlaying: Bool) -> some View {
        let isBookmarked = viewModel.isAyahBookmarked(ayah.numberInSurah)

        return HStack(spacing: 0) {
            StarBadge(
                number: ayah.numberInSurah,
                color: ayah.numberInSurah.isMultiple(of: 2) ? .paperRose : .islamicGold,
                size: 34,
                seed: 71 + ayah.numberInSurah
            )

            Spacer(minLength: 0)

            ayahPlayButton(ayah: ayah, isPlaying: isPlaying)

            iconButton(label: isBookmarked ? "Remove Bookmark" : "Bookmark") {
                withAnimation(.open(0.2)) { viewModel.toggleBookmark(ayah) }
            } icon: {
                PaperIconView(.bookmark, size: 19)
                    .opacity(isBookmarked ? 1 : 0.4)
                    .scaleEffect(isBookmarked ? 1.08 : 1)
            }

            iconButton(label: isCopied ? "Copied" : "Copy") {
                copyAyahText(ayah)
            } icon: {
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                    .contentTransition(.symbolEffect(.replace))
            }

            iconButton(label: "Share") {
                shareAyah(ayah)
            } icon: {
                PaperIconView(.share, size: 18)
            }
        }
    }

    private func ayahPlayButton(ayah: DisplayAyah, isPlaying: Bool) -> some View {
        let resolved = resolvedQari()
        return iconButton(label: isPlaying ? "Pause ayah \(ayah.numberInSurah)" : "Play ayah \(ayah.numberInSurah)") {
            if isPlaying {
                audioPlayer.pause()
            } else {
                Task {
                    await AudioPlayerService.shared.play(
                        surahNumber: viewModel.surahNumber,
                        ayahNumber: ayah.numberInSurah,
                        surahName: viewModel.surahEnglishName,
                        qari: resolved
                    )
                }
            }
        } icon: {
            PaperIconView(isPlaying ? .pause : .play, size: 19)
        }
    }

    private func iconButton<Icon: View>(label: String, action: @escaping () -> Void, @ViewBuilder icon: () -> Icon) -> some View {
        Button(action: action) {
            icon()
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(PaperPressStyle())
        .accessibilityLabel(label)
    }

    /// Resolves the user's currently selected `Qari` from AppSettings.
    /// Falls back to the first default entry if the stored identifier is not found.
    private func resolvedQari() -> Qari {
        Qari.defaults.first { $0.identifier == AppSettings.shared.selectedQari }
            ?? Qari.defaults[0]
    }

    // MARK: - Copy & Share

    private func copyAyahText(_ ayah: DisplayAyah) {
        let text = "\(ayah.arabicText)\n\(ayah.translationText)\n\n- \(viewModel.surahEnglishName) \(viewModel.surahNumber):\(ayah.numberInSurah)"
        UIPasteboard.general.setItems(
            [[UIPasteboard.typeAutomatic: text]],
            options: [.expirationDate: Date().addingTimeInterval(120)]
        )
        withAnimation(.open(0.2)) {
            copiedAyahID = ayah.id
        }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.open(0.2)) {
                if copiedAyahID == ayah.id {
                    copiedAyahID = nil
                }
            }
        }
    }

    private func shareAyah(_ ayah: DisplayAyah) {
        let text = viewModel.shareText(for: ayah)
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = topVC.view
                popover.sourceRect = CGRect(x: topVC.view.bounds.midX, y: topVC.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            topVC.present(activityVC, animated: true)
        }
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        VStack(spacing: 14) {
            PaperIconView(.book, size: 40)
            Text("Loading Surah...")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading surah, please wait")
    }

    // MARK: - Error Overlay

    private func errorOverlay(_ message: String) -> some View {
        VStack(spacing: 14) {
            PaperIconView(.book, size: 36)

            Text(message)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.adaptiveText(colorScheme))
                .multilineTextAlignment(.center)

            Button {
                viewModel.retry()
            } label: {
                Text("Retry")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.lightCardSurface)
                    .padding(.horizontal, 26)
                    .padding(.vertical, 10)
                    .paperPiece(.lightPrimary, material: .construction, depth: 1, radius: 12, seed: 79, padding: nil)
            }
            .buttonStyle(PaperPressStyle())
            .accessibilityLabel("Retry loading surah")
        }
        .paperPiece(Color.adaptiveCardSurface(colorScheme), material: .card, depth: 1.2, seed: 78)
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(message). Tap retry to try again.")
    }

    // MARK: - Qari Picker Sheet

    private var qariPickerSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(Array(Qari.defaults.enumerated()), id: \.element.id) { index, qari in
                        let isSelected = audioPlayer.selectedQari == qari.identifier
                        Button {
                            audioPlayer.setQari(qari.identifier)
                            showQariPicker = false
                        } label: {
                            HStack(spacing: 12) {
                                PaperIconView(isSelected ? .pause : .play, size: 22)
                                Text(qari.name)
                                    .font(.system(size: 16, weight: isSelected ? .heavy : .semibold, design: .rounded))
                                    .foregroundStyle(Color.adaptiveText(colorScheme))
                                Spacer()
                                if isSelected {
                                    PaperCheckbox(isOn: true, size: 22, seed: 500 + index)
                                        .accessibilityLabel("Currently selected")
                                }
                            }
                            .paperPiece(
                                isSelected ? Color.adaptiveCardSurface(colorScheme) : Color.adaptiveCardElevated(colorScheme),
                                material: .card,
                                depth: isSelected ? 1.6 : 0.5,
                                radius: 14,
                                seed: 500 + index,
                                padding: 14
                            )
                        }
                        .buttonStyle(PaperPressStyle())
                        .accessibilityLabel("\(qari.name)\(isSelected ? ", currently selected" : "")")
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                .padding(20)
            }
            .paperBackground()
            .navigationTitle("Select Reciter")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showQariPicker = false
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.adaptivePrimary(colorScheme))
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
    }
}

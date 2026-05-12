import SwiftUI

struct ReadingView: View {
    @StateObject private var viewModel: ReadingViewModel
    @ObservedObject private var audioPlayer = AudioPlayerService.shared
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showQariPicker = false
    @State private var copiedAyahID: Int?

    init(surahNumber: Int, scrollToAyah: Int? = nil) {
        _viewModel = StateObject(wrappedValue: ReadingViewModel(surahNumber: surahNumber, scrollToAyah: scrollToAyah))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Subtle Islamic geometric pattern background
            IslamicPatternBackground(colorScheme: colorScheme)
                .ignoresSafeArea()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        // Surah header card
                        surahHeaderCard
                            .scrollReveal(delay: reduceMotion ? 0 : 0.1)

                        ForEach(Array(viewModel.displayAyahs.enumerated()), id: \.element.id) { index, ayah in
                            ayahCard(ayah, index: index)
                                .id(ayah.numberInSurah)
                                .onAppear {
                                    viewModel.saveReadingPosition(ayah: ayah.numberInSurah)
                                }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
                .onAppear {
                    if let scrollTo = viewModel.scrollToAyah {
                        Task {
                            try? await Task.sleep(for: .milliseconds(500))
                            withAnimation(reduceMotion ? .none : .easeOut(duration: 0.4)) {
                                proxy.scrollTo(scrollTo, anchor: .top)
                            }
                        }
                    }
                }
                .onChange(of: audioPlayer.currentAyahIndex) { _, newIndex in
                    withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.35)) {
                        proxy.scrollTo(newIndex + 1, anchor: .center)
                    }
                }
            }

        }
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
        .navigationTitle(viewModel.surahEnglishName)
        .navigationBarTitleDisplayMode(.inline)
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
                    Image(systemName: "ellipsis.circle")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.adaptivePrimary(colorScheme))
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
        // PlayerBar floats above the tab bar / scroll content without overlapping
        .safeAreaInset(edge: .bottom) {
            PlayerBar()
                .animation(
                    reduceMotion ? .none : .easeInOut(duration: 0.25),
                    value: audioPlayer.nowPlaying != nil
                )
        }
    }

    // MARK: - Surah Header Card

    private var surahHeaderCard: some View {
        VStack(spacing: 8) {
            Text(viewModel.surahName)
                .arabicFont(size: 32)
                .foregroundStyle(Color.adaptivePrimary(colorScheme))
                .accessibilityLabel("Surah \(viewModel.surahEnglishName) in Arabic")

            Text(viewModel.surahEnglishName)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))

            // Decorative divider
            HStack(spacing: 12) {
                capsuleDivider
                Image(systemName: "star.fill")
                    .font(.caption2)
                    .foregroundStyle(Color.adaptivePrimary(colorScheme).opacity(0.6))
                    .accessibilityHidden(true)
                capsuleDivider
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .cardStyle(colorScheme)
        .accessibilityElement(children: .combine)
    }

    private var capsuleDivider: some View {
        Rectangle()
            .fill(Color.adaptivePrimary(colorScheme).opacity(0.2))
            .frame(height: 1)
    }

    // MARK: - Ayah Card

    private func ayahCard(_ ayah: DisplayAyah, index: Int) -> some View {
        let isHighlighted = audioPlayer.isPlaying && audioPlayer.currentAyahIndex == ayah.numberInSurah - 1
        let isCopied = copiedAyahID == ayah.id

        return VStack(alignment: .leading, spacing: 12) {
            // Ayah number badge
            HStack {
                Spacer()
                ayahBadge(ayah.numberInSurah)
            }

            // Arabic text
            Text(ayah.arabicText)
                .arabicFont(size: CGFloat(settings.arabicFontSize))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(Color.adaptiveText(colorScheme))
                .lineSpacing(8)
                .accessibilityLabel(Text("Ayah \(ayah.numberInSurah)"))
                .accessibilityValue(Text(ayah.arabicText))

            // Transliteration
            if settings.showTransliteration && !ayah.transliteration.isEmpty {
                Text(ayah.transliteration)
                    .font(.subheadline)
                    .italic()
                    .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel("Transliteration: \(ayah.transliteration)")
            }

            // Translation
            Text(ayah.translationText)
                .font(.body)
                .foregroundStyle(Color.adaptiveText(colorScheme))
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineSpacing(4)
                .accessibilityLabel("Translation: \(ayah.translationText)")

            // Action buttons row
            ayahActions(ayah, isCopied: isCopied)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isHighlighted
                      ? Color.adaptivePrimary(colorScheme).opacity(0.12)
                      : Color.adaptiveCardSurface(colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isHighlighted ? Color.adaptivePrimary(colorScheme).opacity(0.3) : .clear,
                    lineWidth: 1.5
                )
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.25 : 0.06), radius: 6, y: 3)
        .scrollReveal(delay: (reduceMotion || index >= 15) ? 0 : min(Double(index) * 0.03, 0.3))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Ayah \(ayah.numberInSurah)")
    }

    private func ayahBadge(_ number: Int) -> some View {
        Text("\(number)")
            .font(.caption.weight(.bold).monospacedDigit())
            .foregroundStyle(Color.adaptivePrimary(colorScheme))
            .frame(width: 32, height: 32)
            .background(
                Circle()
                    .fill(Color.adaptivePrimary(colorScheme).opacity(0.1))
            )
            .overlay(
                Circle()
                    .stroke(Color.adaptivePrimary(colorScheme).opacity(0.3), lineWidth: 1)
            )
            .accessibilityHidden(true)
    }

    private func ayahActions(_ ayah: DisplayAyah, isCopied: Bool) -> some View {
        let isBookmarked = viewModel.isAyahBookmarked(ayah.numberInSurah)

        // Determine whether this specific ayah is currently playing via Alpha's new API.
        // Falls back to the legacy isPlaying + currentAyahIndex check when nowPlaying is nil
        // (i.e., before Alpha's contract is merged).
        let isThisAyahPlaying: Bool = {
            if let nowPlaying = audioPlayer.nowPlaying {
                return nowPlaying.surahNumber == viewModel.surahNumber
                    && nowPlaying.ayahNumber == ayah.numberInSurah
                    && audioPlayer.playerState == .playing
            }
            // Legacy fallback
            return audioPlayer.isPlaying && audioPlayer.currentAyahIndex == ayah.numberInSurah - 1
        }()

        return HStack(spacing: 0) {
            actionButton(
                icon: isBookmarked ? "bookmark.fill" : "bookmark",
                label: isBookmarked ? "Remove Bookmark" : "Bookmark"
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.toggleBookmark(ayah)
                }
            }

            actionButton(
                icon: isCopied ? "checkmark" : "doc.on.doc",
                label: isCopied ? "Copied" : "Copy"
            ) {
                copyAyahText(ayah)
            }

            actionButton(
                icon: "square.and.arrow.up",
                label: "Share"
            ) {
                shareAyah(ayah)
            }

            // Per-ayah play button — uses Alpha's new async play(surahNumber:ayahNumber:surahName:qari:)
            // when available. Falls back to the existing synchronous viewModel.playFromAyah(_:).
            ayahPlayButton(ayah: ayah, isPlaying: isThisAyahPlaying)

            Spacer()
        }
        .padding(.top, 4)
    }

    private func ayahPlayButton(ayah: DisplayAyah, isPlaying: Bool) -> some View {
        let resolved = resolvedQari()
        return Button {
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
        } label: {
            Image(systemName: isPlaying ? "pause.circle" : "play.circle")
                .font(.caption)
                .foregroundStyle(
                    isPlaying
                        ? Color.adaptivePrimary(colorScheme)
                        : Color.adaptiveSecondaryText(colorScheme)
                )
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(isPlaying ? "Pause ayah \(ayah.numberInSurah)" : "Play ayah \(ayah.numberInSurah)")
        .buttonStyle(.plain)
    }

    /// Resolves the user's currently selected `Qari` from AppSettings.
    /// Falls back to the first default entry if the stored identifier is not found.
    private func resolvedQari() -> Qari {
        Qari.defaults.first { $0.identifier == AppSettings.shared.selectedQari }
            ?? Qari.defaults[0]
    }

    private func actionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(label)
        .buttonStyle(.plain)
    }

    // MARK: - Copy & Share

    private func copyAyahText(_ ayah: DisplayAyah) {
        let text = "\(ayah.arabicText)\n\(ayah.translationText)\n\n- \(viewModel.surahEnglishName) \(viewModel.surahNumber):\(ayah.numberInSurah)"
        UIPasteboard.general.setItems(
            [[UIPasteboard.typeAutomatic: text]],
            options: [.expirationDate: Date().addingTimeInterval(120)]
        )
        withAnimation {
            copiedAyahID = ayah.id
        }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation {
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
            // Find the topmost presented controller
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            // iPad popover support
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
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(Color.adaptivePrimary(colorScheme))
            Text("Loading Surah...")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.adaptiveBackground(colorScheme).opacity(0.9))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading surah, please wait")
    }

    // MARK: - Error Overlay

    private func errorOverlay(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))

            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                viewModel.retry()
            } label: {
                Text("Retry")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.adaptivePrimary(colorScheme))
                    .clipShape(Capsule())
            }
            .accessibilityLabel("Retry loading surah")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.adaptiveBackground(colorScheme).opacity(0.9))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(message). Tap retry to try again.")
    }

    // MARK: - Qari Picker Sheet

    private var qariPickerSheet: some View {
        NavigationStack {
            List(Qari.defaults) { qari in
                let isSelected = audioPlayer.selectedQari == qari.identifier

                Button {
                    audioPlayer.setQari(qari.identifier)
                    showQariPicker = false
                } label: {
                    HStack(spacing: 12) {
                        // Reciter avatar circle
                        Circle()
                            .fill(Color.adaptivePrimary(colorScheme).opacity(0.15))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.body)
                                    .foregroundStyle(Color.adaptivePrimary(colorScheme))
                            )

                        Text(qari.name)
                            .font(.body.weight(isSelected ? .semibold : .regular))
                            .foregroundStyle(Color.adaptiveText(colorScheme))

                        Spacer()

                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(Color.adaptivePrimary(colorScheme))
                                .accessibilityLabel("Currently selected")
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(
                    isSelected
                    ? Color.adaptivePrimary(colorScheme).opacity(0.08)
                    : Color.clear
                )
                .accessibilityLabel("\(qari.name)\(isSelected ? ", currently selected" : "")")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Select Reciter")
            .navigationBarTitleDisplayMode(.inline)
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

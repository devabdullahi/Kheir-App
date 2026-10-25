import SwiftUI

struct SurahListView: View {
    @State private var viewModel = SurahListViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @State private var showSearchPill = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if showSearchPill {
                    searchPill
                        .transition(.opacity.combined(with: .offset(y: -6)))
                }

                if viewModel.lastReadSurah > 0 && !showSearchPill {
                    continueReadingCard
                        .padding(.bottom, 6)
                        .quickPlace(0)
                }

                ForEach(Array(viewModel.filteredSurahs.enumerated()), id: \.element.id) { index, surah in
                    NavigationLink(destination: ReadingView(surahNumber: surah.number)) {
                        surahRow(surah)
                    }
                    .buttonStyle(PaperPressStyle())
                    .quickPlace(index < 10 ? index + 1 : 0)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .scrollDismissesKeyboard(.immediately)
        .paperBackground()
        .navigationTitle("Quran")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(.open(0.2)) { showSearchPill = true }
                    searchFocused = true
                } label: {
                    PaperIconView(.search, size: 22)
                }
                .accessibilityLabel("Search Surah")
            }
        }
        .onAppear { viewModel.onAppear() }
        .overlay {
            if viewModel.isLoading && viewModel.surahs.isEmpty {
                ProgressView()
                    .tint(Color.adaptivePrimary(colorScheme))
            }
        }
    }

    // MARK: - Continue reading (raised green bookmark)

    private var continueReadingCard: some View {
        let name = viewModel.surahs.first(where: { $0.number == viewModel.lastReadSurah })?.englishName
            ?? "Surah \(viewModel.lastReadSurah)"
        return NavigationLink(destination: ReadingView(surahNumber: viewModel.lastReadSurah, scrollToAyah: viewModel.lastReadAyah)) {
            HStack(spacing: 12) {
                PaperIconView(.book, size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Continue Reading")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .tracking(1.4)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.lightCardSurface.opacity(0.85))
                    Text("\(name) · Ayah \(viewModel.lastReadAyah)")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.lightCardSurface)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 4)
                BrassBrad(size: 9)
            }
            .paperPiece(.lightPrimary, material: .construction, depth: 1.6, seed: 51)
            .overlay(alignment: .topTrailing) { bookmarkNotch }
            .rotationEffect(.degrees(-0.8))
        }
        .buttonStyle(PaperPressStyle())
        .accessibilityLabel("Continue Reading, \(name), Ayah \(viewModel.lastReadAyah)")
    }

    /// The ribbon tail of the bookmark hanging off the top edge.
    private var bookmarkNotch: some View {
        Path { p in
            p.move(to: .zero)
            p.addLine(to: CGPoint(x: 16, y: 0))
            p.addLine(to: CGPoint(x: 16, y: 22))
            p.addLine(to: CGPoint(x: 8, y: 16))
            p.addLine(to: CGPoint(x: 0, y: 22))
            p.closeSubpath()
        }
        .fill(Color.islamicGold)
        .frame(width: 16, height: 22)
        .paperShadow(depth: 0.5)
        .offset(x: -44, y: -6)
        .accessibilityHidden(true)
    }

    // MARK: - Search

    private var searchPill: some View {
        HStack(spacing: 8) {
            PaperIconView(.search, size: 18)
            TextField("Search by name or number", text: $viewModel.searchText)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .focused($searchFocused)
                .submitLabel(.search)
            if !viewModel.searchText.isEmpty {
                Button { viewModel.searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.adaptiveSecondaryText(colorScheme).opacity(0.8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
            Button {
                withAnimation(.open(0.18)) { showSearchPill = false }
                viewModel.searchText = ""
                searchFocused = false
            } label: {
                Text("Cancel")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.adaptivePrimary(colorScheme))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .paperPiece(Color.adaptiveCardSurface(colorScheme), material: .card, depth: 0.6, radius: 14, seed: 52, padding: nil)
    }

    // MARK: - Row

    private func surahRow(_ surah: SurahInfo) -> some View {
        HStack(spacing: 12) {
            StarBadge(
                number: surah.number,
                color: surah.number.isMultiple(of: 2) ? .paperRose : .islamicGold,
                size: 38,
                seed: 60 + surah.number
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(surah.englishName)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Text("\(surah.englishNameTranslation) · \(surah.numberOfAyahs) verses")
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Text(surah.name)
                .arabicFont(size: 21)
                .foregroundStyle(Color.adaptiveText(colorScheme))
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .paperPiece(Color.adaptiveCardSurface(colorScheme), material: .card, depth: 0.8, radius: 16, seed: 60 + surah.number, padding: nil)
        .paperTilt(60 + surah.number, max: 0.6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(surah.number). \(surah.englishName), \(surah.englishNameTranslation), \(surah.numberOfAyahs) verses, \(surah.revelationType)")
    }
}

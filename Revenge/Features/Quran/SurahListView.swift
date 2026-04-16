import SwiftUI

struct SurahListView: View {
    @StateObject private var viewModel = SurahListViewModel()
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Continue Reading
                if viewModel.lastReadSurah > 0 {
                    NavigationLink(destination: ReadingView(surahNumber: viewModel.lastReadSurah, scrollToAyah: viewModel.lastReadAyah)) {
                        HStack {
                            Image(systemName: "book")
                            Text("Continue Reading")
                                .fontWeight(.medium)
                            Spacer()
                            Text("Surah \(viewModel.lastReadSurah), Ayah \(viewModel.lastReadAyah)")
                                .font(.caption)
                                .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                            Image(systemName: "chevron.right")
                                .font(.caption)
                        }
                        .padding()
                        .foregroundStyle(Color.adaptivePrimary(colorScheme))
                        .background(Color.adaptiveCardSurface(colorScheme))
                    }
                }

                // Surah List
                List(viewModel.filteredSurahs) { surah in
                    NavigationLink(destination: ReadingView(surahNumber: surah.number)) {
                        surahRow(surah)
                    }
                    .listRowBackground(Color.adaptiveCardSurface(colorScheme))
                }
                .listStyle(.plain)
                .searchable(text: $viewModel.searchText, prompt: "Search by name or number")
            }
            .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
            .navigationTitle("Quran")
            .onAppear { viewModel.onAppear() }
            .overlay {
                if viewModel.isLoading && viewModel.surahs.isEmpty {
                    ProgressView()
                }
            }
        }
    }

    private func surahRow(_ surah: SurahInfo) -> some View {
        HStack(spacing: 12) {
            // Surah number diamond
            ZStack {
                Image(systemName: "diamond")
                    .font(.title)
                    .foregroundStyle(Color.adaptivePrimary(colorScheme))
                Text("\(surah.number)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.adaptivePrimary(colorScheme))
            }
            .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(surah.englishName)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                HStack(spacing: 4) {
                    Text(surah.revelationType.uppercased())
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Color.adaptivePrimary(colorScheme).opacity(0.12))
                        .clipShape(Capsule())
                    Text("\(surah.numberOfAyahs) verses")
                        .font(.caption)
                }
                .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(surah.name)
                    .arabicFont(size: 20)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Text(surah.englishNameTranslation)
                    .font(.caption2)
                    .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
            }
        }
        .padding(.vertical, 4)
    }
}

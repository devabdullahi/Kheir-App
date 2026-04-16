import SwiftUI

struct BookmarksView: View {
    @StateObject private var viewModel = BookmarksViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @State private var showJournal = false
    @State private var shareText = ""
    @State private var showShareSheet = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                tabSelector

                TabView(selection: $viewModel.selectedTab) {
                    ayahsList
                        .tag(BookmarksViewModel.BookmarkTab.ayahs)
                    hadithsList
                        .tag(BookmarksViewModel.BookmarkTab.hadiths)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.25), value: viewModel.selectedTab)
            }
            .accessibilityIdentifier("bookmarksView")
            .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
            .navigationTitle("Bookmarks")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showJournal = true
                    } label: {
                        Image(systemName: "book.closed")
                            .foregroundStyle(Color.adaptivePrimary(colorScheme))
                    }
                    .accessibilityLabel("Open Journal")
                }
            }
            .onAppear { viewModel.onAppear() }
            .sheet(isPresented: $showJournal) {
                JournalView()
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(text: shareText)
            }
        }
    }

    // MARK: - Tab Selector
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(BookmarksViewModel.BookmarkTab.allCases, id: \.self) { tab in
                let isSelected = viewModel.selectedTab == tab
                let count = tab == .ayahs ? viewModel.ayahBookmarks.count : viewModel.hadithBookmarks.count

                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        viewModel.selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 6) {
                        HStack(spacing: 6) {
                            Text(tab.rawValue)
                                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                            if count > 0 {
                                Text("\(count)")
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        isSelected
                                        ? Color.adaptivePrimary(colorScheme)
                                        : Color.adaptiveSecondaryText(colorScheme).opacity(0.2)
                                    )
                                    .foregroundStyle(isSelected ? .white : Color.adaptiveSecondaryText(colorScheme))
                                    .clipShape(Capsule())
                            }
                        }

                        Rectangle()
                            .fill(isSelected ? Color.adaptivePrimary(colorScheme) : .clear)
                            .frame(height: 2)
                    }
                }
                .foregroundStyle(
                    isSelected
                    ? Color.adaptivePrimary(colorScheme)
                    : Color.adaptiveSecondaryText(colorScheme)
                )
                .frame(maxWidth: .infinity)
                .accessibilityLabel("\(tab.rawValue) tab, \(count) items")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Ayahs List
    private var ayahsList: some View {
        Group {
            if viewModel.ayahBookmarks.isEmpty {
                emptyState(
                    icon: "book",
                    title: "No Bookmarked Ayahs",
                    message: "Bookmark verses from the Quran reader to see them here."
                )
            } else {
                List {
                    ForEach(viewModel.ayahBookmarks) { bookmark in
                        NavigationLink(destination: ReadingView(surahNumber: bookmark.surahNumber, scrollToAyah: bookmark.ayahNumber)) {
                            ayahRow(bookmark)
                        }
                        .listRowBackground(Color.adaptiveCardSurface(colorScheme))
                        .listRowSeparatorTint(Color.adaptiveSecondaryText(colorScheme).opacity(0.15))
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                shareText = "\(bookmark.arabicText)\n\(bookmark.translationText)\n\n— \(bookmark.surahName) \(bookmark.surahNumber):\(bookmark.ayahNumber)"
                                showShareSheet = true
                            } label: {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            .tint(Color.adaptivePrimary(colorScheme))
                        }
                    }
                    .onDelete { viewModel.deleteAyahBookmark(at: $0) }
                }
                .listStyle(.plain)
            }
        }
    }

    private func ayahRow(_ bookmark: BookmarkedAyah) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(
                    "\(bookmark.surahName) \(bookmark.surahNumber):\(bookmark.ayahNumber)",
                    systemImage: "book"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.adaptivePrimary(colorScheme))

                Spacer()

                Text(bookmark.savedDate, style: .date)
                    .font(.caption2)
                    .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
            }

            Text(bookmark.arabicText)
                .arabicFont(size: 20)
                .lineLimit(2)
                .foregroundStyle(Color.adaptiveText(colorScheme))
                .accessibilityLabel("Arabic text")
                .accessibilityValue(bookmark.arabicText)

            Text(bookmark.translationText)
                .font(.subheadline)
                .lineLimit(2)
                .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Bookmarked ayah from \(bookmark.surahName), verse \(bookmark.ayahNumber)")
    }

    // MARK: - Hadiths List
    private var hadithsList: some View {
        Group {
            if viewModel.hadithBookmarks.isEmpty {
                emptyState(
                    icon: "text.book.closed",
                    title: "No Bookmarked Hadiths",
                    message: "Bookmark hadiths from the home screen to save them here."
                )
            } else {
                List {
                    ForEach(viewModel.hadithBookmarks) { bookmark in
                        hadithRow(bookmark)
                            .listRowBackground(Color.adaptiveCardSurface(colorScheme))
                            .listRowSeparatorTint(Color.adaptiveSecondaryText(colorScheme).opacity(0.15))
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    shareText = "\(bookmark.text)\n\n— \(bookmark.source)"
                                    if !bookmark.narrator.isEmpty {
                                        shareText += ", narrated by \(bookmark.narrator)"
                                    }
                                    showShareSheet = true
                                } label: {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                }
                                .tint(Color.adaptivePrimary(colorScheme))
                            }
                    }
                    .onDelete { viewModel.deleteHadithBookmark(at: $0) }
                }
                .listStyle(.plain)
            }
        }
    }

    private func hadithRow(_ bookmark: BookmarkedHadith) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(bookmark.source)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.adaptivePrimary(colorScheme))
                Spacer()
                Text(bookmark.savedDate, style: .date)
                    .font(.caption2)
                    .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
            }

            Text(bookmark.text)
                .font(.body)
                .lineLimit(3)
                .foregroundStyle(Color.adaptiveText(colorScheme))

            HStack(spacing: 8) {
                if !bookmark.narrator.isEmpty {
                    Text(bookmark.narrator)
                        .font(.caption2)
                        .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                }
                Text(bookmark.grade)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.adaptivePrimary(colorScheme).opacity(0.12))
                    .foregroundStyle(Color.adaptivePrimary(colorScheme))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Bookmarked hadith from \(bookmark.source)")
    }

    // MARK: - Empty State
    private func emptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(Color.adaptivePrimary(colorScheme).opacity(0.3))
                .accessibilityHidden(true)
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.adaptiveText(colorScheme))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("bookmarksEmptyState")
    }
}

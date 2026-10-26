import SwiftUI

struct BookmarksView: View {
    @State private var viewModel = BookmarksViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @State private var showJournal = false
    @State private var shareText = ""
    @State private var showShareSheet = false

    var body: some View {
        VStack(spacing: 0) {
            tabSelector

            TabView(selection: $viewModel.selectedTab) {
                ayahsList
                    .tag(BookmarksViewModel.BookmarkTab.ayahs)
                hadithsList
                    .tag(BookmarksViewModel.BookmarkTab.hadiths)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.travel(0.25), value: viewModel.selectedTab)
        }
        .accessibilityIdentifier("bookmarksView")
        .paperBackground()
        .navigationTitle("Bookmarks")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showJournal = true
                } label: {
                    PaperIconView(.pen, size: 22)
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

    // MARK: - Tab Selector (two paper tags; the selected one sits on top)

    private var tabSelector: some View {
        HStack(spacing: -4) {
            ForEach(Array(BookmarksViewModel.BookmarkTab.allCases.enumerated()), id: \.element) { index, tab in
                let isSelected = viewModel.selectedTab == tab
                let count = tab == .ayahs ? viewModel.ayahBookmarks.count : viewModel.hadithBookmarks.count

                Button {
                    withAnimation(.open(0.2)) {
                        viewModel.selectedTab = tab
                    }
                } label: {
                    Text("\(tab.rawValue) · \(count)")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .tracking(0.8)
                        .textCase(.uppercase)
                        .foregroundStyle(isSelected ? Color.lightBodyText : Color.adaptiveSecondaryText(colorScheme))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .paperPiece(
                            isSelected ? PaperInk.mustard : Color.adaptiveCardElevated(colorScheme),
                            material: .construction,
                            depth: isSelected ? 1.2 : 0.4,
                            edge: .torn,
                            radius: 3,
                            seed: 81 + index,
                            padding: nil
                        )
                        .rotationEffect(.degrees(index == 0 ? -2 : 1.5))
                }
                .buttonStyle(PaperPressStyle())
                .zIndex(isSelected ? 1 : 0)
                .accessibilityLabel("\(tab.rawValue) tab, \(count) items")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    // MARK: - Ayahs List

    private var ayahsList: some View {
        Group {
            if viewModel.ayahBookmarks.isEmpty {
                emptyState(
                    icon: .book,
                    title: "No Bookmarked Ayahs",
                    message: "Bookmark verses from the Quran reader to see them here."
                )
            } else {
                List {
                    ForEach(Array(viewModel.ayahBookmarks.enumerated()), id: \.element.id) { index, bookmark in
                        ZStack {
                            NavigationLink(destination: ReadingView(surahNumber: bookmark.surahNumber, scrollToAyah: bookmark.ayahNumber)) {
                                EmptyView()
                            }
                            .opacity(0)
                            ayahRow(bookmark, index: index)
                        }
                        .paperListRow()
                        .quickPlace(min(index, 8))
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
                .scrollContentBackground(.hidden)
                .contentMargins(.bottom, 100, for: .scrollContent)
            }
        }
    }

    /// An index card: reference and paper bookmark on top, Arabic, then meaning.
    private func ayahRow(_ bookmark: BookmarkedAyah, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(bookmark.surahName) \(bookmark.surahNumber):\(bookmark.ayahNumber)")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Spacer()
                Text(bookmark.savedDate, style: .date)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                PaperIconView(.bookmark, size: 20)
            }

            Text(bookmark.arabicText)
                .arabicFont(size: 21)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .foregroundStyle(Color.adaptiveText(colorScheme))
                .accessibilityLabel("Arabic text")
                .accessibilityValue(bookmark.arabicText)

            Text(bookmark.translationText)
                .font(.system(size: 14.5, design: .serif))
                .lineLimit(2)
                .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
        }
        .paperPiece(Color.adaptiveCardSurface(colorScheme), material: .card, depth: 1, radius: 16, seed: 83 + index, padding: 16)
        .paperTilt(83 + index, max: 0.8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Bookmarked ayah from \(bookmark.surahName), verse \(bookmark.ayahNumber)")
    }

    // MARK: - Hadiths List

    private var hadithsList: some View {
        Group {
            if viewModel.hadithBookmarks.isEmpty {
                emptyState(
                    icon: .beads,
                    title: "No Bookmarked Hadiths",
                    message: "Bookmark hadiths from the home screen to save them here."
                )
            } else {
                List {
                    ForEach(Array(viewModel.hadithBookmarks.enumerated()), id: \.element.id) { index, bookmark in
                        hadithRow(bookmark, index: index)
                            .paperListRow()
                            .quickPlace(min(index, 8))
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
                .scrollContentBackground(.hidden)
                .contentMargins(.bottom, 100, for: .scrollContent)
            }
        }
    }

    private func hadithRow(_ bookmark: BookmarkedHadith, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(bookmark.source)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Spacer()
                Text(bookmark.savedDate, style: .date)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                PaperIconView(.bookmark, size: 20)
            }

            Text(bookmark.text)
                .font(.system(size: 15, design: .serif))
                .lineLimit(3)
                .foregroundStyle(Color.adaptiveText(colorScheme))

            HStack(spacing: 8) {
                if !bookmark.narrator.isEmpty {
                    Text(bookmark.narrator)
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                }
                Spacer()
                if !bookmark.grade.isEmpty {
                    PaperTag(text: bookmark.grade, color: PaperInk.kraftLabel, ink: .lightBodyText, seed: 90 + index)
                }
            }
        }
        .paperPiece(Color.adaptiveCardSurface(colorScheme), material: .card, depth: 1, radius: 16, seed: 86 + index, padding: 16)
        .paperTilt(86 + index, max: 0.8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Bookmarked hadith from \(bookmark.source)")
    }

    // MARK: - Empty State

    private func emptyState(icon: PaperIcon, title: String, message: String) -> some View {
        VStack(spacing: 14) {
            Spacer()
            VStack(spacing: 12) {
                PaperIconView(icon, size: 44)
                Text(title)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Text(message)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .paperPiece(Color.adaptiveCardSurface(colorScheme), material: .card, depth: 1, seed: 89)
            .paperTilt(89)
            .padding(.horizontal, 32)
            .quickPlace(0)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("bookmarksEmptyState")
    }
}

private extension View {
    /// A List row that shows only the paper card: no system background or separator.
    func paperListRow() -> some View {
        self
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
    }
}

import SwiftUI

struct JournalView: View {
    @State private var viewModel = JournalViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var showCompose = false
    @State private var editingEntry: JournalEntry?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.entries.isEmpty {
                    emptyState
                } else {
                    journalList
                }
            }
            .paperBackground()
            .navigationTitle("Journal")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.adaptivePrimary(colorScheme))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCompose = true
                    } label: {
                        PaperIconView(.plus, size: 22)
                    }
                    .accessibilityLabel("New journal entry")
                }
            }
            .onAppear { viewModel.onAppear() }
            .sheet(isPresented: $showCompose) {
                JournalComposeView(viewModel: viewModel)
            }
            .sheet(item: $editingEntry) { entry in
                JournalComposeView(viewModel: viewModel, editingEntry: entry)
            }
        }
    }

    // MARK: - Journal List

    private var journalList: some View {
        List {
            ForEach(Array(viewModel.entriesByDate.enumerated()), id: \.element.0) { groupIndex, group in
                let (dateString, entries) = group
                Section {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        journalRow(entry, seed: 130 + groupIndex * 7 + index)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 14, leading: 20, bottom: 8, trailing: 20))
                            .quickPlace(min(groupIndex + index, 8))
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    viewModel.deleteEntry(entry)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    editingEntry = entry
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(Color.adaptivePrimary(colorScheme))
                            }
                    }
                } header: {
                    PaperSectionTag(title: dateString, seed: 140 + groupIndex)
                        .padding(.top, 6)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    /// A sheet of lined notepaper held to the table with washi tape. A linked
    /// ayah or hadith is a small kraft label clipped on at the bottom.
    private func journalRow(_ entry: JournalEntry, seed: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(entry.date, style: .time)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Color.adaptiveGold(colorScheme))
                .frame(height: 22, alignment: .bottom)

            Text(entry.text)
                .font(.system(size: 15, design: .serif))
                .lineSpacing(22 - 18)
                .foregroundStyle(Color.adaptiveText(colorScheme))
                .lineLimit(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 2)

            if entry.linkedAyah != nil || entry.linkedHadith != nil {
                HStack(spacing: 8) {
                    if let ayah = entry.linkedAyah {
                        linkedLabel(icon: .book, text: "\(ayah.surahName) \(ayah.surahNumber):\(ayah.ayahNumber)", seed: seed + 1)
                    }
                    if let hadith = entry.linkedHadith {
                        linkedLabel(icon: .beads, text: hadith.source, seed: seed + 2)
                    }
                }
                .padding(.top, 10)
            }
        }
        .padding(.leading, 22)
        .padding(DesignTokens.cardPadding)
        .background {
            NotepaperLines(lineHeight: 22, topInset: DesignTokens.cardPadding)
                .clipShape(CutShape(cornerRadius: 6, seed: seed))
        }
        .paperPiece(Color.adaptiveCardSurface(colorScheme), material: .card, depth: 1.1, radius: 6, seed: seed, padding: nil)
        .overlay(alignment: .top) {
            PaperTape(seed: seed).offset(y: -10)
        }
        .paperTilt(seed, max: 1)
        .contentShape(Rectangle())
        .onTapGesture {
            editingEntry = entry
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Journal entry")
        .accessibilityValue(entry.text)
        .accessibilityHint("Double tap to edit")
    }

    private func linkedLabel(icon: PaperIcon, text: String, seed: Int) -> some View {
        HStack(spacing: 5) {
            PaperIconView(icon, size: 14)
            Text(text)
                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                .foregroundStyle(Color.lightBodyText)
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .paperPiece(PaperInk.kraftLabel, material: .kraft, depth: 0.6, edge: .torn, radius: 3, seed: seed, padding: nil)
        .rotationEffect(.degrees((seeded(seed, salt: 9) - 0.5) * 4))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack {
            Spacer()
            VStack(spacing: 12) {
                PaperIconView(.pen, size: 40)
                Text("Your Journal is Empty")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Text("Capture your reflections, thoughts, and spiritual insights. Link them to specific Ayahs or Hadiths.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                    .multilineTextAlignment(.center)
                Button {
                    showCompose = true
                } label: {
                    PaperButtonLabel(title: "Start Writing", icon: .pen, seed: 136)
                }
                .buttonStyle(PaperPressStyle())
                .padding(.top, 6)
            }
            .frame(maxWidth: .infinity)
            .paperPiece(Color.adaptiveCardSurface(colorScheme), material: .card, depth: 1.1, radius: 8, seed: 135)
            .overlay(alignment: .top) { PaperTape(seed: 135).offset(y: -10) }
            .paperTilt(135)
            .padding(.horizontal, 28)
            .quickPlace(0)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

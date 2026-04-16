import SwiftUI

struct JournalView: View {
    @StateObject private var viewModel = JournalViewModel()
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
            .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
            .navigationTitle("Journal")
            .navigationBarTitleDisplayMode(.inline)
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
                        Image(systemName: "square.and.pencil")
                            .foregroundStyle(Color.adaptivePrimary(colorScheme))
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
            ForEach(viewModel.entriesByDate, id: \.0) { dateString, entries in
                Section {
                    ForEach(entries) { entry in
                        journalRow(entry)
                            .listRowBackground(Color.adaptiveCardSurface(colorScheme))
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
                    Text(dateString)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func journalRow(_ entry: JournalEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.date, style: .time)
                    .font(.caption2)
                    .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                Spacer()
                if entry.linkedAyah != nil {
                    Image(systemName: "book")
                        .font(.caption2)
                        .foregroundStyle(Color.adaptivePrimary(colorScheme))
                }
                if entry.linkedHadith != nil {
                    Image(systemName: "text.book.closed")
                        .font(.caption2)
                        .foregroundStyle(Color.adaptivePrimary(colorScheme))
                }
            }

            Text(entry.text)
                .font(.body)
                .foregroundStyle(Color.adaptiveText(colorScheme))
                .lineLimit(4)

            if let ayah = entry.linkedAyah {
                linkedAyahBadge(ayah)
            }

            if let hadith = entry.linkedHadith {
                linkedHadithBadge(hadith)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            editingEntry = entry
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Journal entry")
        .accessibilityValue(entry.text)
        .accessibilityHint("Double tap to edit")
    }

    private func linkedAyahBadge(_ ayah: LinkedAyah) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "book")
                .font(.caption2)
            Text("\(ayah.surahName) \(ayah.surahNumber):\(ayah.ayahNumber)")
                .font(.caption2.weight(.medium))
        }
        .foregroundStyle(Color.adaptivePrimary(colorScheme))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.adaptivePrimary(colorScheme).opacity(0.1))
        .clipShape(Capsule())
    }

    private func linkedHadithBadge(_ hadith: LinkedHadith) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "text.book.closed")
                .font(.caption2)
            Text(hadith.source)
                .font(.caption2.weight(.medium))
        }
        .foregroundStyle(Color.adaptivePrimary(colorScheme))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.adaptivePrimary(colorScheme).opacity(0.1))
        .clipShape(Capsule())
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "book.closed")
                .font(.system(size: 48))
                .foregroundStyle(Color.adaptivePrimary(colorScheme).opacity(0.3))
                .accessibilityHidden(true)
            Text("Your Journal is Empty")
                .font(.headline)
                .foregroundStyle(Color.adaptiveText(colorScheme))
            Text("Capture your reflections, thoughts, and spiritual insights. Link them to specific Ayahs or Hadiths.")
                .font(.subheadline)
                .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button {
                showCompose = true
            } label: {
                Text("Start Writing")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.adaptivePrimary(colorScheme))
                    .clipShape(Capsule())
            }
            .padding(.top, 8)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

import SwiftUI

struct JournalComposeView: View {
    var viewModel: JournalViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    let editingEntry: JournalEntry?

    @State private var text: String = ""
    @State private var selectedAyahIndex: Int?
    @State private var selectedHadithIndex: Int?
    @State private var showAyahPicker = false
    @State private var showHadithPicker = false
    @FocusState private var isTextFocused: Bool

    private var isEditing: Bool { editingEntry != nil }

    init(viewModel: JournalViewModel, editingEntry: JournalEntry? = nil) {
        self.viewModel = viewModel
        self.editingEntry = editingEntry
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    textEditor
                    linkedContentSection
                }
                .padding()
            }
            .paperBackground()
            .navigationTitle(isEditing ? "Edit Entry" : "New Entry")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditing ? "Save" : "Add") {
                        saveEntry()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.adaptivePrimary(colorScheme))
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if let entry = editingEntry {
                    text = entry.text
                    if let linkedAyah = entry.linkedAyah {
                        selectedAyahIndex = viewModel.ayahBookmarks.firstIndex(where: {
                            $0.surahNumber == linkedAyah.surahNumber && $0.ayahNumber == linkedAyah.ayahNumber
                        })
                    }
                    if let linkedHadith = entry.linkedHadith {
                        selectedHadithIndex = viewModel.hadithBookmarks.firstIndex(where: {
                            $0.text == linkedHadith.text && $0.source == linkedHadith.source
                        })
                    }
                }
                isTextFocused = true
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Text Editor
    private var textEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            PaperSectionTag(title: "Your Reflection", seed: 301)

            TextEditor(text: $text)
                .focused($isTextFocused)
                .font(.system(size: 16, design: .serif))
                .lineSpacing(5)
                .foregroundStyle(Color.adaptiveText(colorScheme))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 180)
                .padding(.leading, 28)
                .padding(.trailing, 12)
                .padding(.vertical, 12)
                .background {
                    NotepaperLines(lineHeight: 24, topInset: 8)
                        .clipShape(CutShape(cornerRadius: 6, seed: 302))
                }
                .paperPiece(Color.adaptiveCardSurface(colorScheme), material: .card, depth: 1.1, radius: 6, seed: 302, padding: nil)
                .overlay(alignment: .top) { PaperTape(seed: 302).offset(y: -10) }
                .padding(.top, 6)
                .accessibilityLabel("Journal entry text")
        }
    }

    // MARK: - Linked Content
    private var linkedContentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PaperSectionTag(title: "Link to Bookmark (Optional)", seed: 303)

            // Ayah Link
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    PaperIconView(.book, size: 18)
                    Text("Ayah")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Spacer()
                    if selectedAyahIndex != nil {
                        Button {
                            selectedAyahIndex = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                        }
                        .accessibilityLabel("Remove linked ayah")
                    }
                }

                if let index = selectedAyahIndex, index < viewModel.ayahBookmarks.count {
                    let ayah = viewModel.ayahBookmarks[index]
                    Text("\(ayah.surahName) \(ayah.surahNumber):\(ayah.ayahNumber)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.lightBodyText)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .paperPiece(PaperInk.kraftLabel, material: .kraft, depth: 0.6, edge: .torn, radius: 3, seed: 306, padding: nil)
                } else {
                    Button {
                        showAyahPicker = true
                    } label: {
                        Text(viewModel.ayahBookmarks.isEmpty ? "No bookmarked ayahs" : "Select an ayah")
                            .font(.caption)
                            .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                    }
                    .disabled(viewModel.ayahBookmarks.isEmpty)
                    .sheet(isPresented: $showAyahPicker) {
                        ayahPickerSheet
                    }
                }
            }
            .paperPiece(Color.adaptiveCardSurface(colorScheme), material: .card, depth: 0.9, radius: 14, seed: 304, padding: 14)

            // Hadith Link
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    PaperIconView(.beads, size: 18)
                    Text("Hadith")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Spacer()
                    if selectedHadithIndex != nil {
                        Button {
                            selectedHadithIndex = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                        }
                        .accessibilityLabel("Remove linked hadith")
                    }
                }

                if let index = selectedHadithIndex, index < viewModel.hadithBookmarks.count {
                    let hadith = viewModel.hadithBookmarks[index]
                    Text(hadith.source)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.lightBodyText)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .paperPiece(PaperInk.kraftLabel, material: .kraft, depth: 0.6, edge: .torn, radius: 3, seed: 306, padding: nil)
                } else {
                    Button {
                        showHadithPicker = true
                    } label: {
                        Text(viewModel.hadithBookmarks.isEmpty ? "No bookmarked hadiths" : "Select a hadith")
                            .font(.caption)
                            .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                    }
                    .disabled(viewModel.hadithBookmarks.isEmpty)
                    .sheet(isPresented: $showHadithPicker) {
                        hadithPickerSheet
                    }
                }
            }
            .paperPiece(Color.adaptiveCardSurface(colorScheme), material: .card, depth: 0.9, radius: 14, seed: 305, padding: 14)
        }
    }

    // MARK: - Ayah Picker
    private var ayahPickerSheet: some View {
        NavigationStack {
            List {
                ForEach(Array(viewModel.ayahBookmarks.enumerated()), id: \.element.id) { index, ayah in
                    Button {
                        selectedAyahIndex = index
                        showAyahPicker = false
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(ayah.surahName) \(ayah.surahNumber):\(ayah.ayahNumber)")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.adaptiveText(colorScheme))
                            Text(ayah.translationText)
                                .font(.caption)
                                .lineLimit(2)
                                .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Select Ayah")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { showAyahPicker = false }
                        .foregroundStyle(Color.adaptivePrimary(colorScheme))
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Hadith Picker
    private var hadithPickerSheet: some View {
        NavigationStack {
            List {
                ForEach(Array(viewModel.hadithBookmarks.enumerated()), id: \.element.id) { index, hadith in
                    Button {
                        selectedHadithIndex = index
                        showHadithPicker = false
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(hadith.source)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.adaptiveText(colorScheme))
                            Text(hadith.text)
                                .font(.caption)
                                .lineLimit(2)
                                .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Select Hadith")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { showHadithPicker = false }
                        .foregroundStyle(Color.adaptivePrimary(colorScheme))
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Save
    private func saveEntry() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let linkedAyah: LinkedAyah? = selectedAyahIndex.flatMap { index in
            guard index < viewModel.ayahBookmarks.count else { return nil }
            let a = viewModel.ayahBookmarks[index]
            return LinkedAyah(
                surahNumber: a.surahNumber,
                surahName: a.surahName,
                ayahNumber: a.ayahNumber,
                arabicText: a.arabicText,
                translationText: a.translationText
            )
        }

        let linkedHadith: LinkedHadith? = selectedHadithIndex.flatMap { index in
            guard index < viewModel.hadithBookmarks.count else { return nil }
            let h = viewModel.hadithBookmarks[index]
            return LinkedHadith(text: h.text, source: h.source)
        }

        if var existing = editingEntry {
            existing.text = trimmed
            existing.linkedAyah = linkedAyah
            existing.linkedHadith = linkedHadith
            viewModel.updateEntry(existing)
        } else {
            let entry = JournalEntry(text: trimmed, linkedAyah: linkedAyah, linkedHadith: linkedHadith)
            viewModel.addEntry(entry)
        }

        dismiss()
    }
}

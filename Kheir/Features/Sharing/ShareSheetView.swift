import SwiftUI
import UIKit

// MARK: - Share Sheet View

/// Full-screen modal that shows a preview of share card templates with
/// template picker, size toggle, share, and save-to-photos actions.
struct ShareSheetView: View {
    @State private var viewModel: ShareViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    init(data: ShareCardData) {
        _viewModel = State(wrappedValue: ShareViewModel(data: data))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // MARK: Preview
                    previewSection

                    // MARK: Size Toggle
                    sizeToggle

                    // MARK: Template Picker
                    templatePicker

                    // MARK: Action Buttons
                    actionButtons
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .paperBackground()
            .navigationTitle("Share")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.adaptivePrimary(colorScheme))
                }
            }
            .task {
                await viewModel.renderCard()
            }
            .sheet(isPresented: $viewModel.showActivitySheet) {
                if let image = viewModel.renderedImage {
                    ActivityShareSheet(items: [image])
                }
            }
        }
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        ZStack {
            if viewModel.isRendering {
                renderingPlaceholder
            } else if let image = viewModel.renderedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(CutShape(cornerRadius: 10, seed: 190))
                    .paperShadow(depth: 2)
                    .rotationEffect(.degrees(-1))
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    .animation(.open(0.25), value: viewModel.renderedImage != nil)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: viewModel.selectedSize == .story ? 400 : 320)
        .padding(.top, 8)
    }

    private var renderingPlaceholder: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(Color.adaptivePrimary(colorScheme))
            Text("Cutting paper…")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
        }
        .frame(width: viewModel.selectedSize == .story ? 225 : 320, height: viewModel.selectedSize == .story ? 400 : 320)
        .paperPiece(Color.adaptiveCardSurface(colorScheme), material: .card, depth: 1, radius: 10, seed: 190, padding: nil)
    }

    // MARK: - Size Toggle

    private var sizeToggle: some View {
        VStack(alignment: .leading, spacing: 10) {
            PaperSectionTag(title: "Size", seed: 199)

            HStack(spacing: 10) {
                ForEach(Array(ShareCardSize.allCases.enumerated()), id: \.element) { index, size in
                    let selected = viewModel.selectedSize == size
                    Button {
                        viewModel.selectSize(size)
                    } label: {
                        Text(size.rawValue)
                            .font(.system(size: 13.5, weight: .bold, design: .rounded))
                            .foregroundStyle(selected ? Color.lightBodyText : Color.adaptiveSecondaryText(colorScheme))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .paperPiece(
                                selected ? PaperInk.mustard : Color.adaptiveCardElevated(colorScheme),
                                material: .construction,
                                depth: selected ? 1.2 : 0.4,
                                edge: .torn,
                                radius: 3,
                                seed: 200 + index,
                                padding: nil
                            )
                    }
                    .buttonStyle(PaperPressStyle())
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Template Picker

    private var templatePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            PaperSectionTag(title: "Template", seed: 198)

            HStack(spacing: 12) {
                ForEach(Array(ShareTemplate.allCases.enumerated()), id: \.element.id) { index, template in
                    templateCard(template, index: index)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
        }
    }

    private func swatch(for template: ShareTemplate) -> Color {
        switch template {
        case .minimal: return .lightCardSurface
        case .geometric: return .paperTerracotta
        case .calligraphy: return .darkBackground
        case .nature: return .lightPrimary
        }
    }

    private func templateCard(_ template: ShareTemplate, index: Int) -> some View {
        let isSelected = viewModel.selectedTemplate == template
        return Button {
            viewModel.selectTemplate(template)
        } label: {
            VStack(spacing: 8) {
                Color.clear
                    .frame(width: 58, height: 72)
                    .paperPiece(swatch(for: template), material: .construction, depth: isSelected ? 1.8 : 0.6, radius: 8, seed: 195 + index, padding: nil)
                    .overlay {
                        if isSelected { BrassBrad(size: 8).offset(y: -26) }
                    }
                    .rotationEffect(.degrees((seeded(index, salt: 1) - 0.5) * 4))
                    .scaleEffect(isSelected ? 1.04 : 1)

                Text(template.displayName)
                    .font(.system(size: 12, weight: isSelected ? .heavy : .medium, design: .rounded))
                    .foregroundStyle(isSelected ? Color.adaptiveText(colorScheme) : Color.adaptiveSecondaryText(colorScheme))
            }
        }
        .buttonStyle(PaperPressStyle())
        .animation(.open(0.2), value: isSelected)
        .accessibilityLabel("\(template.displayName) template")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Share button
            Button {
                viewModel.shareImage()
            } label: {
                PaperButtonLabel(title: "Share", icon: .share, seed: 205)
            }
            .buttonStyle(PaperPressStyle())
            .disabled(viewModel.isRendering || viewModel.renderedImage == nil)
            .opacity(viewModel.isRendering || viewModel.renderedImage == nil ? 0.5 : 1)

            // Save to Photos button
            Button {
                Task { await viewModel.saveToPhotos() }
            } label: {
                HStack(spacing: 8) {
                    saveToPhotosIcon
                    saveToPhotosLabel
                }
                .foregroundStyle(Color.adaptivePrimary(colorScheme))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .paperPiece(Color.adaptiveCardSurface(colorScheme), material: .card, depth: 0.8, radius: 14, seed: 206, padding: nil)
            }
            .buttonStyle(PaperPressStyle())
            .disabled(viewModel.isRendering || viewModel.renderedImage == nil || isSaving)
            .opacity(viewModel.isRendering || viewModel.renderedImage == nil ? 0.5 : 1)
            .animation(.open(0.2), value: viewModel.saveToPhotosState.description)
        }
    }

    private var isSaving: Bool {
        if case .saving = viewModel.saveToPhotosState { return true }
        return false
    }

    @ViewBuilder
    private var saveToPhotosIcon: some View {
        switch viewModel.saveToPhotosState {
        case .saving:
            ProgressView()
                .tint(Color.adaptivePrimary(colorScheme))
                .scaleEffect(0.8)
        case .saved:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .medium))
        case .denied:
            Image(systemName: "lock.fill")
                .font(.system(size: 16, weight: .medium))
        case .failed:
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 16, weight: .medium))
        case .idle:
            Image(systemName: "photo.badge.arrow.down")
                .font(.system(size: 16, weight: .medium))
        }
    }

    @ViewBuilder
    private var saveToPhotosLabel: some View {
        switch viewModel.saveToPhotosState {
        case .saving:
            Text("Saving...")
                .font(.headline)
        case .saved:
            Text("Saved to Photos")
                .font(.headline)
        case .denied:
            Text("Photos Access Denied")
                .font(.headline)
        case .failed(let message):
            Text("Failed: \(message)")
                .font(.headline)
                .lineLimit(1)
        case .idle:
            Text("Save to Photos")
                .font(.headline)
        }
    }
}

// MARK: - Save State Description (for animation value)

extension ShareViewModel.SaveState {
    var description: String {
        switch self {
        case .idle:         return "idle"
        case .saving:       return "saving"
        case .saved:        return "saved"
        case .denied:       return "denied"
        case .failed(let m): return "failed:\(m)"
        }
    }
}

// MARK: - Activity Share Sheet Wrapper

/// UIViewControllerRepresentable wrapping UIActivityViewController for image sharing.
struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

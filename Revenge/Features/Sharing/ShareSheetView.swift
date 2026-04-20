import SwiftUI
import UIKit

// MARK: - Share Sheet View

/// Full-screen modal that shows a preview of share card templates with
/// template picker, size toggle, share, and save-to-photos actions.
struct ShareSheetView: View {
    @StateObject private var viewModel: ShareViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    init(data: ShareCardData) {
        _viewModel = StateObject(wrappedValue: ShareViewModel(data: data))
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
            .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
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
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.4 : 0.12),
                            radius: 16, y: 6)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    .animation(.easeOut(duration: 0.25), value: viewModel.renderedImage != nil)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: viewModel.selectedSize == .story ? 400 : 320)
        .padding(.top, 8)
    }

    private var renderingPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.adaptiveCardSurface(colorScheme))
                .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
            VStack(spacing: 12) {
                ProgressView()
                    .tint(Color.adaptivePrimary(colorScheme))
                Text("Rendering...")
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
            }
        }
        .frame(height: viewModel.selectedSize == .story ? 400 : 320)
    }

    // MARK: - Size Toggle

    private var sizeToggle: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Size")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))

            HStack(spacing: 12) {
                ForEach(ShareCardSize.allCases, id: \.self) { size in
                    Button {
                        viewModel.selectSize(size)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: size == .story ? "iphone" : "square")
                                .font(.system(size: 14))
                            Text(size.rawValue)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(
                            viewModel.selectedSize == size
                                ? Color.adaptiveCardSurface(colorScheme)
                                : Color.adaptivePrimary(colorScheme)
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(
                                    viewModel.selectedSize == size
                                        ? Color.adaptivePrimary(colorScheme)
                                        : Color.adaptivePrimary(colorScheme).opacity(0.1)
                                )
                        )
                    }
                    .animation(.easeInOut(duration: 0.15), value: viewModel.selectedSize)
                }
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Template Picker

    private var templatePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Template")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ShareTemplate.allCases) { template in
                        templateCard(template)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
            }
        }
    }

    private func templateCard(_ template: ShareTemplate) -> some View {
        let isSelected = viewModel.selectedTemplate == template
        return Button {
            viewModel.selectTemplate(template)
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.adaptiveCardSurface(colorScheme))
                        .frame(width: 80, height: 80)
                        .shadow(
                            color: .black.opacity(isSelected ? 0.2 : 0.06),
                            radius: isSelected ? 8 : 4,
                            y: 2
                        )

                    Image(systemName: template.symbolName)
                        .font(.system(size: 28))
                        .foregroundStyle(
                            isSelected
                                ? Color.adaptivePrimary(colorScheme)
                                : Color.adaptiveSecondaryText(colorScheme)
                        )

                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.adaptivePrimary(colorScheme), lineWidth: 2.5)
                            .frame(width: 80, height: 80)
                    }
                }

                Text(template.displayName)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(
                        isSelected
                            ? Color.adaptivePrimary(colorScheme)
                            : Color.adaptiveSecondaryText(colorScheme)
                    )
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Share button
            Button {
                viewModel.shareImage()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .medium))
                    Text("Share")
                        .font(.headline)
                }
                .foregroundStyle(Color.adaptiveCardSurface(colorScheme))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.adaptivePrimary(colorScheme))
                )
            }
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
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.adaptivePrimary(colorScheme).opacity(0.1))
                )
            }
            .disabled(viewModel.isRendering || viewModel.renderedImage == nil || isSaving)
            .opacity(viewModel.isRendering || viewModel.renderedImage == nil ? 0.5 : 1)
            .animation(.easeInOut(duration: 0.2), value: viewModel.saveToPhotosState.description)
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

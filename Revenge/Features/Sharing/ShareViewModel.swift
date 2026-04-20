import Combine
import SwiftUI
import Photos
import UIKit

// MARK: - Share View Model

@MainActor
final class ShareViewModel: ObservableObject {

    // MARK: - Published State

    @Published var selectedTemplate: ShareTemplate = .minimal
    @Published var selectedSize: ShareCardSize = .story
    @Published var renderedImage: UIImage?
    @Published var isRendering: Bool = false
    @Published var saveToPhotosState: SaveState = .idle
    @Published var showActivitySheet: Bool = false

    // MARK: - Types

    enum SaveState {
        case idle
        case saving
        case saved
        case denied
        case failed(String)
    }

    // MARK: - Private

    private let renderer: ShareCardRenderer
    private var baseData: ShareCardData

    // MARK: - Init

    init(data: ShareCardData, renderer: ShareCardRenderer = .shared) {
        self.baseData = data
        self.renderer = renderer
        self.selectedTemplate = data.template
    }

    // MARK: - Computed

    var currentCardData: ShareCardData {
        baseData.withTemplate(selectedTemplate)
    }

    // MARK: - Template Selection

    func selectTemplate(_ template: ShareTemplate) {
        guard template != selectedTemplate else { return }
        selectedTemplate = template
        Task { await renderCard() }
    }

    func selectSize(_ size: ShareCardSize) {
        guard size != selectedSize else { return }
        selectedSize = size
        Task { await renderCard() }
    }

    // MARK: - Rendering

    func renderCard() async {
        isRendering = true
        renderedImage = nil

        // Yield to let the UI update before the synchronous render work
        await Task.yield()

        let data = currentCardData
        let size = selectedSize.cgSize
        let image = renderer.renderShareCard(data: data, size: size)
        renderedImage = image
        isRendering = false
    }

    // MARK: - Share

    func shareImage() {
        guard renderedImage != nil else { return }
        showActivitySheet = true
    }

    // MARK: - Save to Photos

    func saveToPhotos() async {
        guard let image = renderedImage else { return }
        saveToPhotosState = .saving

        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            saveToPhotosState = .denied
            return
        }

        do {
            try await performSave(image: image)
            saveToPhotosState = .saved
            // Reset after 2 seconds
            try? await Task.sleep(for: .seconds(2))
            saveToPhotosState = .idle
        } catch {
            saveToPhotosState = .failed(error.localizedDescription)
        }
    }

    private func performSave(image: UIImage) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: error ?? ShareError.saveFailed)
                }
            }
        }
    }
}

// MARK: - Share Error

private enum ShareError: LocalizedError {
    case saveFailed

    var errorDescription: String? {
        "Failed to save image to Photos."
    }
}

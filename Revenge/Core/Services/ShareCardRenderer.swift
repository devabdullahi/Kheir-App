import SwiftUI
import UIKit

// MARK: - Share Card Renderer

/// Renders SwiftUI share card views into UIImage using ImageRenderer (iOS 16+).
@MainActor
final class ShareCardRenderer {

    nonisolated static let shared = ShareCardRenderer()

    private init() {}

    // MARK: - Public API

    /// Renders a share card for the given data at the specified size.
    /// - Parameters:
    ///   - data: The content and template configuration for the card.
    ///   - size: The pixel dimensions of the output image.
    ///   - colorScheme: The color scheme to apply (defaults to light for export).
    /// - Returns: A rendered UIImage, or a fallback blank image if rendering fails.
    func renderShareCard(
        data: ShareCardData,
        size: CGSize,
        colorScheme: ColorScheme = .light
    ) -> UIImage {
        let view = shareCardView(for: data, size: size, colorScheme: colorScheme)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1.0
        renderer.proposedSize = ProposedViewSize(size)
        if let image = renderer.uiImage {
            return image
        }
        return makeFallbackImage(size: size)
    }

    /// Renders both Story (1080×1920) and Square (1080×1080) sizes.
    func renderAllSizes(data: ShareCardData, colorScheme: ColorScheme = .light) -> [ShareCardSize: UIImage] {
        var result: [ShareCardSize: UIImage] = [:]
        for cardSize in ShareCardSize.allCases {
            result[cardSize] = renderShareCard(data: data, size: cardSize.cgSize, colorScheme: colorScheme)
        }
        return result
    }

    // MARK: - Private Helpers

    @ViewBuilder
    private func shareCardView(
        for data: ShareCardData,
        size: CGSize,
        colorScheme: ColorScheme
    ) -> some View {
        let frameSize = size
        Group {
            switch data.template {
            case .minimal:
                MinimalShareCard(data: data, colorScheme: colorScheme)
                    .frame(width: frameSize.width, height: frameSize.height)
            case .geometric:
                GeometricShareCard(data: data, colorScheme: colorScheme)
                    .frame(width: frameSize.width, height: frameSize.height)
            case .calligraphy:
                CalligraphyShareCard(data: data, colorScheme: colorScheme)
                    .frame(width: frameSize.width, height: frameSize.height)
            case .nature:
                NatureShareCard(data: data, colorScheme: colorScheme)
                    .frame(width: frameSize.width, height: frameSize.height)
            }
        }
    }

    private func makeFallbackImage(size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.systemBackground.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }
}

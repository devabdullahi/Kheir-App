import Testing
import SwiftUI
import UIKit
@testable import Revenge

// MARK: - ShareCardData Tests

@Suite("ShareCardData")
struct ShareCardDataTests {

    @Test("initializes with all required fields")
    func testInitialization() {
        let data = ShareCardData(
            content: "In the name of Allah",
            arabicText: "بِسْمِ اللَّهِ",
            reference: "Al-Faatiha (1:1)",
            template: .minimal,
            type: .ayah
        )

        #expect(data.content == "In the name of Allah")
        #expect(data.arabicText == "بِسْمِ اللَّهِ")
        #expect(data.reference == "Al-Faatiha (1:1)")
        #expect(data.template == .minimal)
        #expect(data.type == .ayah)
    }

    @Test("id is unique per instance")
    func testIdUniqueness() {
        let a = ShareCardData(content: "A", reference: "Ref", template: .minimal, type: .ayah)
        let b = ShareCardData(content: "A", reference: "Ref", template: .minimal, type: .ayah)
        #expect(a.id != b.id)
    }

    @Test("withTemplate creates new card with same id but new template")
    func testWithTemplate() {
        let original = ShareCardData(
            content: "Test content",
            arabicText: nil,
            reference: "Source",
            template: .minimal,
            type: .hadith
        )
        let updated = original.withTemplate(.nature)

        #expect(updated.id == original.id)
        #expect(updated.template == .nature)
        #expect(updated.content == original.content)
        #expect(updated.reference == original.reference)
        #expect(updated.type == original.type)
    }

    @Test("arabicText can be nil for hadith cards")
    func testNilArabicText() {
        let data = ShareCardData(
            content: "Actions are judged by intentions.",
            arabicText: nil,
            reference: "Sahih al-Bukhari",
            template: .geometric,
            type: .hadith
        )
        #expect(data.arabicText == nil)
    }

    @Test("conforms to Identifiable via id property")
    func testIdentifiable() {
        let data = ShareCardData(content: "Test", reference: "Ref", template: .calligraphy, type: .ayah)
        // Identifiable requires id — compile-time check; confirm type
        let id: UUID = data.id
        #expect(id == data.id)
    }
}

// MARK: - ShareTemplate Tests

@Suite("ShareTemplate")
struct ShareTemplateTests {

    @Test("all cases have unique display names")
    func testUniqueDisplayNames() {
        let names = ShareTemplate.allCases.map(\.displayName)
        let unique = Set(names)
        #expect(names.count == unique.count)
    }

    @Test("all cases have non-empty symbol names")
    func testSymbolNames() {
        for template in ShareTemplate.allCases {
            #expect(!template.symbolName.isEmpty)
        }
    }

    @Test("rawValue round trips correctly")
    func testRawValues() {
        #expect(ShareTemplate(rawValue: "minimal") == .minimal)
        #expect(ShareTemplate(rawValue: "geometric") == .geometric)
        #expect(ShareTemplate(rawValue: "calligraphy") == .calligraphy)
        #expect(ShareTemplate(rawValue: "nature") == .nature)
    }

    @Test("template selection via withTemplate")
    func testTemplateSelection() {
        var current: ShareTemplate = .minimal
        let templates = ShareTemplate.allCases

        for template in templates {
            let data = ShareCardData(
                content: "Test",
                reference: "Ref",
                template: current,
                type: .ayah
            )
            let updated = data.withTemplate(template)
            current = updated.template
            #expect(current == template)
        }
    }
}

// MARK: - ShareCardRenderer Tests

@Suite("ShareCardRenderer")
struct ShareCardRendererTests {

    private func makeSampleData(template: ShareTemplate = .minimal, type: ShareContentType = .ayah) -> ShareCardData {
        ShareCardData(
            content: "In the name of Allah, the Entirely Merciful, the Especially Merciful.",
            arabicText: "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ",
            reference: "Al-Faatiha (1:1)",
            template: template,
            type: type
        )
    }

    @Test("render returns non-nil UIImage for story size")
    @MainActor
    func testRenderStorySize() async {
        let renderer = ShareCardRenderer.shared
        let data = makeSampleData()
        let image = renderer.renderShareCard(data: data, size: ShareCardSize.story.cgSize)
        #expect(image.size.width > 0)
        #expect(image.size.height > 0)
    }

    @Test("render returns non-nil UIImage for square size")
    @MainActor
    func testRenderSquareSize() async {
        let renderer = ShareCardRenderer.shared
        let data = makeSampleData()
        let image = renderer.renderShareCard(data: data, size: ShareCardSize.square.cgSize)
        #expect(image.size.width > 0)
        #expect(image.size.height > 0)
    }

    @Test("all 4 templates render without crash - ayah")
    @MainActor
    func testAllTemplatesRenderAyah() async {
        let renderer = ShareCardRenderer.shared
        for template in ShareTemplate.allCases {
            let data = makeSampleData(template: template, type: .ayah)
            let image = renderer.renderShareCard(data: data, size: ShareCardSize.story.cgSize)
            #expect(image.size.width > 0, "Template \(template.displayName) returned empty image")
        }
    }

    @Test("all 4 templates render without crash - hadith")
    @MainActor
    func testAllTemplatesRenderHadith() async {
        let renderer = ShareCardRenderer.shared
        let hadithData = ShareCardData(
            content: "Actions are judged by intentions.",
            arabicText: nil,
            reference: "Sahih al-Bukhari",
            template: .minimal,
            type: .hadith
        )
        for template in ShareTemplate.allCases {
            let data = hadithData.withTemplate(template)
            let image = renderer.renderShareCard(data: data, size: ShareCardSize.square.cgSize)
            #expect(image.size.width > 0, "Hadith template \(template.displayName) returned empty image")
        }
    }

    @Test("both sizes render correctly with correct aspect ratios")
    @MainActor
    func testBothSizesRender() async {
        let renderer = ShareCardRenderer.shared
        let data = makeSampleData()

        let storyImage = renderer.renderShareCard(data: data, size: ShareCardSize.story.cgSize)
        let squareImage = renderer.renderShareCard(data: data, size: ShareCardSize.square.cgSize)

        // Story is portrait: height > width
        #expect(storyImage.size.height > storyImage.size.width)
        // Square has equal dimensions
        #expect(squareImage.size.width == squareImage.size.height)
    }

    @Test("renderAllSizes returns images for all ShareCardSize cases")
    @MainActor
    func testRenderAllSizes() async {
        let renderer = ShareCardRenderer.shared
        let data = makeSampleData()
        let results = renderer.renderAllSizes(data: data)

        #expect(results.count == ShareCardSize.allCases.count)
        for size in ShareCardSize.allCases {
            #expect(results[size] != nil, "Missing rendered image for size \(size.rawValue)")
        }
    }
}

// MARK: - ShareCardSize Tests

@Suite("ShareCardSize")
struct ShareCardSizeTests {

    @Test("story size is 1080x1920")
    func testStoryCGSize() {
        let size = ShareCardSize.story.cgSize
        #expect(size.width == 1080)
        #expect(size.height == 1920)
    }

    @Test("square size is 1080x1080")
    func testSquareCGSize() {
        let size = ShareCardSize.square.cgSize
        #expect(size.width == 1080)
        #expect(size.height == 1080)
    }
}

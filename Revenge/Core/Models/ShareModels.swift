import Foundation

// MARK: - Share Template

enum ShareTemplate: String, CaseIterable, Identifiable {
    case minimal
    case geometric
    case calligraphy
    case nature

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .minimal:      return "Minimal"
        case .geometric:    return "Geometric"
        case .calligraphy:  return "Calligraphy"
        case .nature:       return "Nature"
        }
    }

    var symbolName: String {
        switch self {
        case .minimal:      return "square"
        case .geometric:    return "hexagon"
        case .calligraphy:  return "scribble"
        case .nature:       return "leaf"
        }
    }
}

// MARK: - Share Content Type

enum ShareContentType {
    case ayah
    case hadith
}

// MARK: - Share Card Size

enum ShareCardSize: String, CaseIterable {
    case story  = "Story (9:16)"
    case square = "Square (1:1)"

    var cgSize: CGSize {
        switch self {
        case .story:  return CGSize(width: 1080, height: 1920)
        case .square: return CGSize(width: 1080, height: 1080)
        }
    }
}

// MARK: - Share Card Data

struct ShareCardData: Identifiable {
    let id: UUID
    let content: String
    let arabicText: String?
    let reference: String
    let template: ShareTemplate
    let type: ShareContentType

    init(
        id: UUID = UUID(),
        content: String,
        arabicText: String? = nil,
        reference: String,
        template: ShareTemplate = .minimal,
        type: ShareContentType
    ) {
        self.id = id
        self.content = content
        self.arabicText = arabicText
        self.reference = reference
        self.template = template
        self.type = type
    }

    func withTemplate(_ newTemplate: ShareTemplate) -> ShareCardData {
        ShareCardData(
            id: id,
            content: content,
            arabicText: arabicText,
            reference: reference,
            template: newTemplate,
            type: type
        )
    }
}

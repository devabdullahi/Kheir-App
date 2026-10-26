import Foundation

extension String {
    var isArabic: Bool {
        let arabicRange = Unicode.Scalar("\u{0600}")...Unicode.Scalar("\u{06FF}")
        return unicodeScalars.contains { arabicRange.contains($0) }
    }

    func truncated(to length: Int) -> String {
        if count <= length { return self }
        return String(prefix(length)) + "..."
    }
}

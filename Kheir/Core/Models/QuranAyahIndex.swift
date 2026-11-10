import Foundation

// MARK: - Quran Ayah Global Index

/// Maps (surah, ayahInSurah) → global ayah number (1...6236) using the canonical
/// 114-surah ayah count table. Used by cdn.islamic.network audio URL construction.
enum QuranAyahIndex {
    /// Number of ayahs in each surah, index 0 = Surah 1 (Al-Fatiha).
    static let ayahCounts: [Int] = [
        7, 286, 200, 176, 120, 165, 206, 75, 129, 109,
        123, 111, 43, 52, 99, 128, 111, 110, 98, 135,
        112, 78, 118, 64, 77, 227, 93, 88, 69, 60,
        34, 30, 73, 54, 45, 83, 182, 88, 75, 85,
        54, 53, 89, 59, 37, 35, 38, 29, 18, 45,
        60, 49, 62, 55, 78, 96, 29, 22, 24, 13,
        14, 11, 11, 18, 12, 12, 30, 52, 52, 44,
        28, 28, 20, 56, 40, 31, 50, 40, 46, 42,
        29, 19, 36, 25, 22, 17, 19, 26, 30, 20,
        15, 21, 11, 8, 8, 19, 5, 8, 8, 11,
        11, 8, 3, 9, 5, 4, 7, 3, 6, 3,
        5, 4, 5, 6
    ]

    /// Prefix sums over `ayahCounts` so that `prefixSums[i]` is the total number
    /// of ayahs before surah `i + 1` (0-indexed). Computed once at app launch; each
    /// lookup is then O(1) instead of O(n).
    static let prefixSums: [Int] = {
        var sums = [Int](repeating: 0, count: ayahCounts.count)
        var running = 0
        for i in ayahCounts.indices {
            sums[i] = running
            running += ayahCounts[i]
        }
        return sums
    }()

    /// Returns the 1-based global ayah number for a given surah (1-114) and
    /// ayah-within-surah (1-based). Returns nil if either value is out of range.
    /// Complexity: O(1) via precomputed prefix sums.
    static func globalIndex(surah: Int, ayahInSurah: Int) -> Int? {
        guard surah >= 1, surah <= 114 else { return nil }
        let count = ayahCounts[surah - 1]
        guard ayahInSurah >= 1, ayahInSurah <= count else { return nil }
        return prefixSums[surah - 1] + ayahInSurah
    }
}

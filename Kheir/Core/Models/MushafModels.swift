import Foundation

// MARK: - Mushaf (15-line Madani page)

/// One page of the 604-page Madani mushaf, laid out line by line exactly as printed.
struct MushafPage: Codable, Sendable, Equatable {
    static let count = 604

    let number: Int
    let juz: Int
    let hizb: Int
    /// The surah the page opens in, for the header.
    let surah: Int
    let lines: [MushafLine]
}

struct MushafLine: Codable, Sendable, Equatable, Identifiable {
    enum Kind: String, Codable, Sendable { case text, banner, bismillah, blank }

    let id: Int
    let kind: Kind
    /// For banners: the surah that starts here.
    var surah: Int = 0
    var words: [MushafWord] = []
}

struct MushafWord: Codable, Sendable, Equatable {
    let text: String
    let surah: Int
    let ayah: Int
    /// The ayah-end marker (its number, in Arabic-Indic digits).
    let isAyahEnd: Bool
}

/// Where each surah starts in the Madani mushaf, with its Arabic and simple names.
enum MushafIndex {
    static func startPage(ofSurah surah: Int) -> Int {
        surahs[max(0, min(113, surah - 1))].page
    }

    static func arabicName(_ surah: Int) -> String {
        surahs[max(0, min(113, surah - 1))].arabic
    }

    static func name(_ surah: Int) -> String {
        surahs[max(0, min(113, surah - 1))].name
    }

    /// The last surah starting on or before `page`.
    static func surah(onPage page: Int) -> Int {
        (surahs.lastIndex { $0.page <= page } ?? 0) + 1
    }

    static let surahs: [(page: Int, arabic: String, name: String)] = [
        (1, "الفاتحة", "Al-Fatihah"),
        (2, "البقرة", "Al-Baqarah"),
        (50, "آل عمران", "Ali 'Imran"),
        (77, "النساء", "An-Nisa"),
        (106, "المائدة", "Al-Ma'idah"),
        (128, "الأنعام", "Al-An'am"),
        (151, "الأعراف", "Al-A'raf"),
        (177, "الأنفال", "Al-Anfal"),
        (187, "التوبة", "At-Tawbah"),
        (208, "يونس", "Yunus"),
        (221, "هود", "Hud"),
        (235, "يوسف", "Yusuf"),
        (249, "الرعد", "Ar-Ra'd"),
        (255, "ابراهيم", "Ibrahim"),
        (262, "الحجر", "Al-Hijr"),
        (267, "النحل", "An-Nahl"),
        (282, "الإسراء", "Al-Isra"),
        (293, "الكهف", "Al-Kahf"),
        (305, "مريم", "Maryam"),
        (312, "طه", "Taha"),
        (322, "الأنبياء", "Al-Anbya"),
        (332, "الحج", "Al-Hajj"),
        (342, "المؤمنون", "Al-Mu'minun"),
        (350, "النور", "An-Nur"),
        (359, "الفرقان", "Al-Furqan"),
        (367, "الشعراء", "Ash-Shu'ara"),
        (377, "النمل", "An-Naml"),
        (385, "القصص", "Al-Qasas"),
        (396, "العنكبوت", "Al-'Ankabut"),
        (404, "الروم", "Ar-Rum"),
        (411, "لقمان", "Luqman"),
        (415, "السجدة", "As-Sajdah"),
        (418, "الأحزاب", "Al-Ahzab"),
        (428, "سبإ", "Saba"),
        (434, "فاطر", "Fatir"),
        (440, "يس", "Ya-Sin"),
        (446, "الصافات", "As-Saffat"),
        (453, "ص", "Sad"),
        (458, "الزمر", "Az-Zumar"),
        (467, "غافر", "Ghafir"),
        (477, "فصلت", "Fussilat"),
        (483, "الشورى", "Ash-Shuraa"),
        (489, "الزخرف", "Az-Zukhruf"),
        (496, "الدخان", "Ad-Dukhan"),
        (499, "الجاثية", "Al-Jathiyah"),
        (502, "الأحقاف", "Al-Ahqaf"),
        (507, "محمد", "Muhammad"),
        (511, "الفتح", "Al-Fath"),
        (515, "الحجرات", "Al-Hujurat"),
        (518, "ق", "Qaf"),
        (520, "الذاريات", "Adh-Dhariyat"),
        (523, "الطور", "At-Tur"),
        (526, "النجم", "An-Najm"),
        (528, "القمر", "Al-Qamar"),
        (531, "الرحمن", "Ar-Rahman"),
        (534, "الواقعة", "Al-Waqi'ah"),
        (537, "الحديد", "Al-Hadid"),
        (542, "المجادلة", "Al-Mujadila"),
        (545, "الحشر", "Al-Hashr"),
        (549, "الممتحنة", "Al-Mumtahanah"),
        (551, "الصف", "As-Saf"),
        (553, "الجمعة", "Al-Jumu'ah"),
        (554, "المنافقون", "Al-Munafiqun"),
        (556, "التغابن", "At-Taghabun"),
        (558, "الطلاق", "At-Talaq"),
        (560, "التحريم", "At-Tahrim"),
        (562, "الملك", "Al-Mulk"),
        (564, "القلم", "Al-Qalam"),
        (566, "الحاقة", "Al-Haqqah"),
        (568, "المعارج", "Al-Ma'arij"),
        (570, "نوح", "Nuh"),
        (572, "الجن", "Al-Jinn"),
        (574, "المزمل", "Al-Muzzammil"),
        (575, "المدثر", "Al-Muddaththir"),
        (577, "القيامة", "Al-Qiyamah"),
        (578, "الانسان", "Al-Insan"),
        (580, "المرسلات", "Al-Mursalat"),
        (582, "النبإ", "An-Naba"),
        (583, "النازعات", "An-Nazi'at"),
        (585, "عبس", "'Abasa"),
        (586, "التكوير", "At-Takwir"),
        (587, "الإنفطار", "Al-Infitar"),
        (587, "المطففين", "Al-Mutaffifin"),
        (589, "الإنشقاق", "Al-Inshiqaq"),
        (590, "البروج", "Al-Buruj"),
        (591, "الطارق", "At-Tariq"),
        (591, "الأعلى", "Al-A'la"),
        (592, "الغاشية", "Al-Ghashiyah"),
        (593, "الفجر", "Al-Fajr"),
        (594, "البلد", "Al-Balad"),
        (595, "الشمس", "Ash-Shams"),
        (595, "الليل", "Al-Layl"),
        (596, "الضحى", "Ad-Duhaa"),
        (596, "الشرح", "Ash-Sharh"),
        (597, "التين", "At-Tin"),
        (597, "العلق", "Al-'Alaq"),
        (598, "القدر", "Al-Qadr"),
        (598, "البينة", "Al-Bayyinah"),
        (599, "الزلزلة", "Az-Zalzalah"),
        (599, "العاديات", "Al-'Adiyat"),
        (600, "القارعة", "Al-Qari'ah"),
        (600, "التكاثر", "At-Takathur"),
        (601, "العصر", "Al-'Asr"),
        (601, "الهمزة", "Al-Humazah"),
        (601, "الفيل", "Al-Fil"),
        (602, "قريش", "Quraysh"),
        (602, "الماعون", "Al-Ma'un"),
        (602, "الكوثر", "Al-Kawthar"),
        (603, "الكافرون", "Al-Kafirun"),
        (603, "النصر", "An-Nasr"),
        (603, "المسد", "Al-Masad"),
        (604, "الإخلاص", "Al-Ikhlas"),
        (604, "الفلق", "Al-Falaq"),
        (604, "الناس", "An-Nas"),
    ]
}

import Foundation

// MARK: - RoutineService

/// Generates and persists personalised morning and evening spiritual routines.
///
/// Design decisions:
///   - All Islamic content (duas, adhkar) is hardcoded with both Arabic and English text
///     so the feature works fully offline without any network dependency.
///   - The daily ayah and hadith content strings are deterministic placeholders keyed to
///     the date — they are seeded from a fixed pool to give variety across the week without
///     requiring a live API call from within the routine itself.
///   - `cache` is injected at init so unit tests can supply `MockCacheManager` without
///     touching the file system.
///   - The service is a plain `final class` (not an actor) to match the pattern established
///     by `StreakService` and to conform to `RoutineProviding: AnyObject` without boxing.
final class RoutineService {

    // MARK: - Shared Instance

    static let shared = RoutineService()

    // MARK: - Private State

    private let cache: any CacheManaging

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        return f
    }()

    // MARK: - Initialisation

    private convenience init() {
        self.init(cache: CacheManager.shared)
    }

    init(cache: any CacheManaging) {
        self.cache = cache
    }
}

// MARK: - RoutineProviding

extension RoutineService {

    func loadRoutine(type: RoutineType, for date: String) -> DailyRoutine? {
        cache.loadRoutine(type: type, for: date)
    }

    func saveRoutineProgress(_ routine: DailyRoutine) {
        cache.saveRoutine(routine)
    }

    func generateRoutine(type: RoutineType, for date: String) -> DailyRoutine {
        // If a routine already exists for this type+date, return it so progress is preserved.
        if let existing = cache.loadRoutine(type: type, for: date) {
            return existing
        }

        let steps: [RoutineStep]
        switch type {
        case .morning:
            steps = makeMorningSteps(for: date)
        case .evening:
            steps = makeEveningSteps(for: date)
        }

        let routine = DailyRoutine(
            type: type,
            dateString: date,
            steps: steps
        )
        cache.saveRoutine(routine)
        return routine
    }
}

// MARK: - Step Generation

private extension RoutineService {

    /// Derives a stable integer index from the date string so content rotates daily.
    func dayIndex(for date: String) -> Int {
        guard let d = dateFormatter.date(from: date) else { return 0 }
        return Calendar.current.ordinality(of: .day, in: .year, for: d) ?? 0
    }

    // MARK: Morning Steps

    func makeMorningSteps(for date: String) -> [RoutineStep] {
        let idx = dayIndex(for: date)

        return [
            // 1. Morning Dua
            RoutineStep(
                type: .dua,
                title: "Morning Dua",
                content: "We have reached the morning, and at this morning the sovereignty belongs to Allah, Lord of the worlds. O Allah, I ask You for the good of this day, its triumphs and its victories, its light and its blessings, and its guidance.",
                arabicText: "أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ وَالْحَمْدُ لِلَّهِ، وَلَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ",
                reference: "Abu Dawud 5084"
            ),

            // 2. Daily Ayah (rotates through a curated pool)
            morningAyahStep(for: idx),

            // 3–5. Morning Adhkar
            RoutineStep(
                type: .dhikr,
                title: "Morning Adhkar — Tasbeeh",
                content: "Glory be to Allah (33×), All praise is due to Allah (33×), Allah is the Greatest (33×)",
                arabicText: "سُبْحَانَ اللَّهِ وَبِحَمْدِهِ",
                reference: "Sahih Muslim 2691"
            ),
            RoutineStep(
                type: .dhikr,
                title: "Morning Adhkar — Ayat al-Kursi",
                content: "Allah — there is no deity except Him, the Ever-Living, the Sustainer of existence. Neither drowsiness overtakes Him nor sleep. To Him belongs whatever is in the heavens and whatever is on the earth.",
                arabicText: "اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ ۚ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ",
                reference: "Al-Baqarah 2:255"
            ),
            RoutineStep(
                type: .dhikr,
                title: "Morning Adhkar — Protection",
                content: "O Allah, by Your leave we have reached the morning and by Your leave we reach the evening, by Your leave we live, by Your leave we die, and to You is the return.",
                arabicText: "اللَّهُمَّ بِكَ أَصْبَحْنَا وَبِكَ أَمْسَيْنَا وَبِكَ نَحْيَا وَبِكَ نَمُوتُ وَإِلَيْكَ النُّشُورُ",
                reference: "Abu Dawud 5068"
            ),

            // 6. Morning reflection prompt
            RoutineStep(
                type: .reflection,
                title: "Morning Intention",
                content: morningReflection(for: idx),
                arabicText: nil,
                reference: "Daily Reflection"
            )
        ]
    }

    // MARK: Evening Steps

    func makeEveningSteps(for date: String) -> [RoutineStep] {
        let idx = dayIndex(for: date)

        return [
            // 1. Evening Dua
            RoutineStep(
                type: .dua,
                title: "Evening Dua",
                content: "We have reached the evening, and at this evening the sovereignty belongs to Allah, Lord of the worlds. O Allah, I ask You for the good of this night, its light, its help, and its blessings.",
                arabicText: "أَمْسَيْنَا وَأَمْسَى الْمُلْكُ لِلَّهِ وَالْحَمْدُ لِلَّهِ، وَلَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ",
                reference: "Abu Dawud 5084"
            ),

            // 2. Daily Hadith (rotates through a curated pool)
            eveningHadithStep(for: idx),

            // 3–5. Evening Adhkar
            RoutineStep(
                type: .dhikr,
                title: "Evening Adhkar — Seeking Forgiveness",
                content: "I seek the forgiveness of Allah (100×). O Allah, You are my Lord, there is none worthy of worship but You. You created me and I am Your servant, and I am faithful to my covenant and my promise as much as I can.",
                arabicText: "أَسْتَغْفِرُ اللَّهَ الْعَظِيمَ وَأَتُوبُ إِلَيْهِ",
                reference: "Sahih al-Bukhari 6307"
            ),
            RoutineStep(
                type: .dhikr,
                title: "Evening Adhkar — Sayyid al-Istighfar",
                content: "O Allah, You are my Lord, none has the right to be worshipped except You. You created me and I am Your slave, and I am faithful to my covenant and my promise as best I can.",
                arabicText: "اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ",
                reference: "Sahih al-Bukhari 6306"
            ),
            RoutineStep(
                type: .dhikr,
                title: "Evening Adhkar — Surat al-Ikhlas & Mu'awwidhatain",
                content: "Recite Surat al-Ikhlas, al-Falaq, and an-Nas three times each. They are sufficient for protection throughout the night.",
                arabicText: "قُلْ هُوَ اللَّهُ أَحَدٌ ۝ اللَّهُ الصَّمَدُ ۝ لَمْ يَلِدْ وَلَمْ يُولَدْ ۝ وَلَمْ يَكُن لَّهُ كُفُوًا أَحَدٌ",
                reference: "Abu Dawud 5082"
            ),

            // 6. Gratitude prompt
            RoutineStep(
                type: .reflection,
                title: "Evening Gratitude",
                content: eveningReflection(for: idx),
                arabicText: nil,
                reference: "Daily Reflection"
            )
        ]
    }

    // MARK: Ayah Pool (morning)

    func morningAyahStep(for idx: Int) -> RoutineStep {
        let pool: [(arabic: String, english: String, ref: String)] = [
            (
                "وَاسْتَعِينُوا بِالصَّبْرِ وَالصَّلَاةِ ۚ وَإِنَّهَا لَكَبِيرَةٌ إِلَّا عَلَى الْخَاشِعِينَ",
                "And seek help through patience and prayer. And indeed, it is difficult except for the humbly submissive [to Allah].",
                "Al-Baqarah 2:45"
            ),
            (
                "فَاذْكُرُونِي أَذْكُرْكُمْ وَاشْكُرُوا لِي وَلَا تَكْفُرُونِ",
                "So remember Me; I will remember you. And be grateful to Me and do not deny Me.",
                "Al-Baqarah 2:152"
            ),
            (
                "إِنَّ اللَّهَ مَعَ الَّذِينَ اتَّقَوا وَّالَّذِينَ هُم مُّحْسِنُونَ",
                "Indeed, Allah is with those who fear Him and those who are doers of good.",
                "An-Nahl 16:128"
            ),
            (
                "وَتَوَكَّلْ عَلَى اللَّهِ ۚ وَكَفَىٰ بِاللَّهِ وَكِيلًا",
                "And rely upon Allah; and sufficient is Allah as Disposer of affairs.",
                "Al-Ahzab 33:3"
            ),
            (
                "رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ",
                "Our Lord, give us in this world [that which is] good and in the Hereafter [that which is] good and protect us from the punishment of the Fire.",
                "Al-Baqarah 2:201"
            ),
            (
                "إِنَّمَا يُوَفَّى الصَّابِرُونَ أَجْرَهُم بِغَيْرِ حِسَابٍ",
                "Indeed, the patient will be given their reward without account.",
                "Az-Zumar 39:10"
            ),
            (
                "وَلَا تَيْأَسُوا مِن رَّوْحِ اللَّهِ ۖ إِنَّهُ لَا يَيْأَسُ مِن رَّوْحِ اللَّهِ إِلَّا الْقَوْمُ الْكَافِرُونَ",
                "Do not despair of relief from Allah. Indeed, no one despairs of relief from Allah except the disbelieving people.",
                "Yusuf 12:87"
            )
        ]
        let item = pool[idx % pool.count]
        return RoutineStep(
            type: .ayah,
            title: "Morning Ayah",
            content: item.english,
            arabicText: item.arabic,
            reference: item.ref
        )
    }

    // MARK: Hadith Pool (evening)

    func eveningHadithStep(for idx: Int) -> RoutineStep {
        let pool: [(text: String, ref: String)] = [
            (
                "The best among you are those who have the best manners and character.",
                "Sahih al-Bukhari 3559"
            ),
            (
                "None of you truly believes until he loves for his brother what he loves for himself.",
                "Sahih al-Bukhari 13"
            ),
            (
                "The strong man is not the one who can overpower others. Rather, the strong man is the one who controls himself when he is angry.",
                "Sahih al-Bukhari 6114"
            ),
            (
                "Whoever believes in Allah and the Last Day, let him speak good or remain silent.",
                "Sahih al-Bukhari 6018"
            ),
            (
                "Make things easy and do not make them difficult, cheer the people up and do not put them off.",
                "Sahih al-Bukhari 69"
            ),
            (
                "Every act of kindness is a charity.",
                "Sahih al-Bukhari 2989"
            ),
            (
                "A good word is a form of charity.",
                "Sahih al-Bukhari 2989"
            )
        ]
        let item = pool[idx % pool.count]
        return RoutineStep(
            type: .hadith,
            title: "Evening Hadith",
            content: item.text,
            arabicText: nil,
            reference: item.ref
        )
    }

    // MARK: Reflection Prompts

    func morningReflection(for idx: Int) -> String {
        let prompts = [
            "Set one intention for today that brings you closer to Allah. How will you act with ihsan (excellence) in your daily interactions?",
            "What is one quality of Allah (one of the 99 Names) you want to reflect in your actions today?",
            "Think of one person in your life who needs your kindness today. How can you be a source of good for them?",
            "What distraction has been pulling you away from remembrance of Allah? What small step can you take to reduce it today?",
            "Reflect on a blessing you often overlook. How can you show gratitude for it through your actions today?",
            "What deed from yesterday are you most hopeful Allah will accept? How can you build on it today?",
            "Begin this day with bismillah — in the name of Allah. How does starting with His name change your approach to your tasks?"
        ]
        return prompts[idx % prompts.count]
    }

    func eveningReflection(for idx: Int) -> String {
        let prompts = [
            "Name three specific blessings from today — small or large. How did they come to you through Allah's mercy?",
            "Was there a moment today when you chose patience over anger or irritation? Praise Allah for the strength He gave you.",
            "Where did you fall short today? Turn to Allah in sincere repentance (tawbah) and trust in His endless forgiveness.",
            "Think of one good deed you performed today, even if it seemed small. The Prophet ﷺ said: do not belittle any good deed.",
            "Who among your family or friends are you most grateful for tonight? Make dua for them by name.",
            "What worried you today that is now in the past? Reflect on how Allah provides relief after difficulty.",
            "How did you remember Allah today — in prayer, dhikr, or by acting with taqwa? Ask Him to increase you in remembrance."
        ]
        return prompts[idx % prompts.count]
    }
}

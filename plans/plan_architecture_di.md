# Architecture & Dependency Injection Implementation Plan
## Kheir iOS App

**Date:** April 26, 2026  
**Status:** Ready for implementation  
**Sprint Estimate:** 3-4 weeks (P0 + P1 items)

---

## Department Overview

The Architecture & Dependency Injection department is responsible for ensuring:
- **Testability** — All ViewModels and Services injectable, unit-testable
- **Separation of Concerns** — Single-responsibility protocols, no god objects
- **Code Organization** — Proper layering (Models, Services, ViewModels, Views)
- **Maintainability** — Clear dependencies, minimal coupling

**Current State:** Mixed compliance. HomeViewModel is properly injectable (good pattern), but 6+ ViewModels hardcode singletons. CacheManaging protocol is oversized. Prayer countdown logic is duplicated. PrayerTimesService internally hardcodes dependencies.

**Target State:** 100% DI compliance. All ViewModels protocol-injected. Services composable and testable. Code organized by domain responsibility.

---

## Priority Order

1. **AD-01**: Refactor CacheManaging into focused protocols — ✅ Done (Apr 29, added JournalManaging + SurahCaching sub-protocols during CS-01 actor conversion)
2. **AD-02**: Fix ReadingViewModel singleton hardcoding — ✅ Partial (Apr 29, uses protocol-typed `any CacheManaging` but not yet constructor-injected)
3. **AD-03**: Fix BookmarksViewModel, JournalViewModel, SurahListViewModel singleton hardcoding — ✅ Partial (Apr 29, BookmarksVM + JournalVM constructor-injected; SurahListVM uses protocol type but not yet injected)
4. **AD-04**: Fix PrayerTimesViewModel singleton hardcoding + LocationService protocol abstraction
5. **AD-05**: Extract PrayerCountdownManager (eliminate duplication between Home and PrayerTimes)
6. **AD-06**: Extract BookmarkInteractor (thin HomeViewModel responsibility)
7. **AD-07**: Make PrayerTimesService injectable (currently hardcodes APIService.shared)
8. **AD-08**: Move QuranAyahIndex to domain layer (remove from APIService)
9. **AD-09**: Move response types to Models layer (remove from APIService)
10. **AD-10**: Move ContentLoadState enum to shared location (remove from HomeViewModel)
11. **AD-11**: Move ShareSheet to shared Components (remove from HomeView)
12. **AD-12**: Remove dead SettingsViewModel, refactor SettingsView to use protocol
13. **AD-13**: Remove commented code, update internal documentation

---

## Detailed Task Specifications

### AD-01: Refactor CacheManaging into Focused Protocols
**Priority:** P0  
**Files:**
- `Revenge/Core/Services/ServiceProtocols.swift` (refactor)
- `Revenge/Core/Services/CacheManager.swift` (add conformances)
- `RevengeTests/Mocks/ServiceMocks.swift` (update mocks)

**Current Behavior:**
```swift
protocol CacheManaging: AnyObject {
    // Daily content (2 methods)
    func cacheDailyAyah(_ ayah: DailyAyah)
    func loadDailyAyah(for date: String) -> DailyAyah?
    
    // Ayah bookmarks (5 methods)
    func saveAyahBookmark(_ bookmark: BookmarkedAyah)
    // ...
    
    // Hadith bookmarks (5 methods)
    func saveHadithBookmark(_ bookmark: BookmarkedHadith)
    // ...
    
    // Streak persistence (2 methods)
    func saveStreak(_ data: StreakData)
    // ...
    
    // Routine persistence (2 methods)
    func saveRoutine(_ routine: DailyRoutine)
    // ...
    
    // Surah cache (2 methods)
    // Journal (4 methods)
}
```
**Problem:** 23 methods in single protocol. Mock setup requires implementing all 23 even when testing code that uses only 2.

**Target Behavior:**
Split into 6 focused protocols:
- `DailyContentCaching` (2 methods: cacheDailyAyah, loadDailyAyah, similar for hadith)
- `AyahBookmarkManaging` (5 methods: saveAyahBookmark, removeAyahBookmark, isAyahBookmarked, loadAyahBookmarks)
- `HadithBookmarkManaging` (5 methods)
- `StreakPersisting` (2 methods)
- `RoutinePersisting` (2 methods)
- `SurahCaching` (2 methods)
- `JournalPersisting` (4 methods)
- `CacheManaging` (composition protocol: extends all 7 above, kept for backward compat)

**Step-by-Step Instructions:**
1. Open `ServiceProtocols.swift`
2. Keep existing `CacheManaging` protocol definition but mark as `// MARK: - DEPRECATED, use focused protocols`
3. Above the old `CacheManaging`, define new focused protocols:
   - `protocol DailyContentCaching: AnyObject` with methods:
     - `cacheDailyAyah(_ ayah: DailyAyah)`
     - `loadDailyAyah(for date: String) -> DailyAyah?`
     - `cacheDailyHadith(_ hadith: DailyHadith)`
     - `loadDailyHadith(for date: String) -> DailyHadith?`
   - `protocol AyahBookmarkManaging: AnyObject` with bookmark ayah methods
   - `protocol HadithBookmarkManaging: AnyObject` with bookmark hadith methods
   - `protocol StreakPersisting: AnyObject` with streak methods
   - `protocol RoutinePersisting: AnyObject` with routine methods
   - `protocol SurahCaching: AnyObject` with surah cache methods
   - `protocol JournalPersisting: AnyObject` with journal methods
4. Redefine `CacheManaging` as composition:
   ```swift
   protocol CacheManaging: 
       DailyContentCaching, 
       AyahBookmarkManaging, 
       HadithBookmarkManaging, 
       StreakPersisting, 
       RoutinePersisting, 
       SurahCaching, 
       JournalPersisting,
       AnyObject {}
   ```
5. Update `CacheManager` conformance line to:
   ```swift
   extension CacheManager: CacheManaging {}
   ```
6. In `ServiceMocks.swift`, create focused mocks:
   - `MockDailyContentCache`, `MockAyahBookmarks`, etc.
   - Keep `MockCacheManager` that conforms to all
7. Run tests to verify no breaking changes.

**Verification:**
- [ ] `ServiceProtocols.swift` compiles without errors
- [ ] All 7 focused protocols defined and documented
- [ ] `CacheManaging` composes all 7
- [ ] `CacheManager` still conforms to `CacheManaging`
- [ ] All existing conformance still works
- [ ] Mocks simplified (minimal boilerplate for each focused use case)
- [ ] Unit tests pass

**Dependencies:**
- None (pure refactoring, no API changes)

**Risk/Rollback:**
- **Risk:** Low. This is purely internal refactoring; public API unchanged.
- **Rollback:** Revert file to previous commit.

---

### AD-02: Fix ReadingViewModel Singleton Hardcoding
**Priority:** P0  
**Files:**
- `Revenge/Features/Quran/ReadingViewModel.swift`

**Current Behavior:**
```swift
private let cache = CacheManager.shared      // ❌ Concrete, not protocol
private let api = APIService.shared          // ❌ Concrete, not protocol
let audioPlayer = AudioPlayerService.shared
```
Cannot unit-test without real file system and network.

**Target Behavior:**
```swift
private let cache: any SurahCaching         // ✅ Protocol-injected
private let api: any (AyahFetching & SurahFetching)  // ✅ Composed protocol
private let audioPlayer: any AudioPlayerManaging      // ✅ Protocol (once abstracted)
```

**Step-by-Step Instructions:**
1. Define missing protocols in `ServiceProtocols.swift`:
   - `protocol SurahFetching: Sendable` with methods:
     - `fetchSurahList() async throws -> [SurahInfo]`
     - `fetchSurah(number: Int, edition: String) async throws -> SurahDetail`
     - `fetchSurahTranslation(number: Int, edition: String) async throws -> SurahDetail`
   - Add `extension APIService: SurahFetching {}`
   
2. In `ReadingViewModel.swift`:
   - Add parameters to `init()`:
     ```swift
     init(
         surahNumber: Int,
         scrollToAyah: Int? = nil,
         cache: any SurahCaching = CacheManager.shared,
         api: any (AyahFetching & SurahFetching) = APIService.shared,
         audioPlayer: any AudioPlayerManaging = AudioPlayerService.shared
     )
     ```
   - Replace property declarations:
     ```swift
     private let cache: any SurahCaching
     private let api: any (AyahFetching & SurahFetching)
     private let audioPlayer: any AudioPlayerManaging
     ```
   - Assign in init body
   
3. Update `onAppear()` to use injected services only (already done in code review)

4. Create `AudioPlayerManaging` protocol in `ServiceProtocols.swift` if not exists:
   ```swift
   protocol AudioPlayerManaging: AnyObject {
       var currentAyahIndex: Int { get set }
       func configure(surah: Int, totalAyahs: Int)
       func play(surah: Int, ayah: Int)
   }
   ```
   Add `extension AudioPlayerService: AudioPlayerManaging {}`

**Verification:**
- [ ] `init()` accepts protocol-typed parameters with defaults
- [ ] All private properties typed as protocols, not concrete classes
- [ ] `ReadingViewModel` can be instantiated with mock objects
- [ ] Existing call sites unaffected (defaults ensure backward compatibility)
- [ ] Unit tests can inject mocks for `cache` and `api`

**Dependencies:**
- Requires `SurahFetching` protocol definition (part of AD-01 refinement)
- Requires `AudioPlayerManaging` protocol definition

**Risk/Rollback:**
- **Risk:** Low. Backward-compatible via default parameters.
- **Rollback:** Revert file and update callers if needed.

---

### AD-03: Fix Bookmark and Journal ViewModel Singleton Hardcoding
**Priority:** P0  
**Files:**
- `Revenge/Features/Bookmarks/BookmarksViewModel.swift`
- `Revenge/Features/Journal/JournalViewModel.swift`
- `Revenge/Features/Quran/SurahListViewModel.swift`
- `Revenge/Core/Services/ServiceProtocols.swift` (add missing protocols)

**Current Behavior:**
```swift
// BookmarksViewModel.swift:16
private let cache = CacheManager.shared

// JournalViewModel.swift:11
private let cache = CacheManager.shared

// SurahListViewModel.swift:11
private let cache = CacheManager.shared
```

**Target Behavior:**
```swift
private let cache: any (AyahBookmarkManaging & HadithBookmarkManaging & SurahCaching & JournalPersisting)
```
Constructor injection with protocol types.

**Step-by-Step Instructions:**

1. **BookmarksViewModel:**
   - Add init with injected cache:
     ```swift
     init(
         cache: any (AyahBookmarkManaging & HadithBookmarkManaging) = CacheManager.shared
     ) {
         self.cache = cache
     }
     ```
   - Replace property `private let cache = CacheManager.shared` with `private let cache: any (AyahBookmarkManaging & HadithBookmarkManaging)`

2. **JournalViewModel:**
   - Add init with injected cache:
     ```swift
     init(
         cache: any (JournalPersisting & AyahBookmarkManaging & HadithBookmarkManaging) = CacheManager.shared
     ) {
         self.cache = cache
     }
     ```
   - Replace property declaration

3. **SurahListViewModel:**
   - Current code uses `APIService.shared.fetchSurahList()` directly at line 38
   - Add `api` parameter and inject:
     ```swift
     init(
         cache: any SurahCaching = CacheManager.shared,
         api: any SurahFetching = APIService.shared
     ) {
         self.cache = cache
         self.api = api
         setupSearch()
     }
     ```
   - Add property: `private let api: any SurahFetching`
   - Replace `APIService.shared.fetchSurahList()` with `self.api.fetchSurahList()`
   - Move searchCancellable setup out of init into separate `setupSearch()` method (call from init)

**Verification:**
- [ ] All three ViewModels have `init()` with protocol-typed cache parameter
- [ ] SurahListViewModel has API parameter
- [ ] No references to `.shared` within ViewModels
- [ ] All existing call sites still work (backward compatible)
- [ ] Mocks can be injected in unit tests

**Dependencies:**
- AD-01 (focused protocols must exist)
- SurahFetching protocol (defined in AD-02)

**Risk/Rollback:**
- **Risk:** Low. Defaults ensure compatibility.
- **Rollback:** Revert files.

---

### AD-04: Fix PrayerTimesViewModel Singleton Hardcoding & LocationService Abstraction
**Priority:** P0  
**Files:**
- `Revenge/Features/PrayerTimes/PrayerTimesViewModel.swift`
- `Revenge/Core/Services/ServiceProtocols.swift` (add LocationManaging protocol)
- `Revenge/Core/Services/LocationService.swift` (add conformance)

**Current Behavior:**
```swift
private let locationService = LocationService.shared  // ❌ Concrete
// Line 57: PrayerTimesService.shared.fetchPrayerTimes()  // ❌ Hardcoded
```

**Target Behavior:**
```swift
private let locationService: any LocationManaging
private let prayerTimesService: any PrayerTimesFetching
```

**Step-by-Step Instructions:**

1. In `ServiceProtocols.swift`, define `LocationManaging` protocol:
   ```swift
   protocol LocationManaging: AnyObject {
       var currentLocation: CLLocationCoordinate2D? { get }
       func requestPermission()
       func startUpdating()
       func geocodeCity(_ cityName: String) async -> CLLocationCoordinate2D?
       var $currentLocation: Published<CLLocationCoordinate2D?>.Publisher { get }
   }
   ```
   Note: Published property publisher is tricky; see guidance below.

2. In `LocationService.swift`, add conformance:
   ```swift
   extension LocationService: LocationManaging {}
   ```

3. In `PrayerTimesViewModel.swift`:
   - Update init:
     ```swift
     init(
         locationService: any LocationManaging = LocationService.shared,
         prayerTimesService: any PrayerTimesFetching = PrayerTimesService.shared
     ) {
         self.locationService = locationService
         self.prayerTimesService = prayerTimesService
         // ... rest of init
     }
     ```
   - Add properties:
     ```swift
     private let locationService: any LocationManaging
     private let prayerTimesService: any PrayerTimesFetching
     ```
   - Replace `LocationService.shared` with `locationService`
   - Replace `PrayerTimesService.shared` with `prayerTimesService` (line 57, 81)

4. Handle the Published<> property:
   - LocationService has `@Published var currentLocation`
   - For mocks, use manual subject:
     ```swift
     class MockLocationService: LocationManaging {
         @Published var currentLocation: CLLocationCoordinate2D?
         var $currentLocation: Published<CLLocationCoordinate2D?>.Publisher { $currentLocation }
         // ...
     }
     ```

**Verification:**
- [ ] `LocationManaging` protocol defined with all required methods/properties
- [ ] `LocationService` conforms to `LocationManaging`
- [ ] `PrayerTimesViewModel` init accepts both injected services
- [ ] All calls to `.shared` replaced with injected properties
- [ ] Backward compatible (defaults provided)
- [ ] Unit tests can inject mocks

**Dependencies:**
- `PrayerTimesFetching` protocol must be non-Sendable (or conform when PrayerTimesService is refactored in AD-07)

**Risk/Rollback:**
- **Risk:** Medium. Published property bridging can be tricky.
- **Mitigation:** Test with mock immediately. If complex, create helper extension on LocationManaging.
- **Rollback:** Revert file.

---

### AD-05: Extract PrayerCountdownManager (Eliminate Duplication)
**Priority:** P1  
**Files:**
- `Revenge/Core/Services/PrayerCountdownManager.swift` (new file)
- `Revenge/Core/Services/ServiceProtocols.swift` (add protocol)
- `Revenge/Features/Home/HomeViewModel.swift` (refactor)
- `Revenge/Features/PrayerTimes/PrayerTimesViewModel.swift` (refactor)

**Current Behavior:**
Prayer countdown logic duplicated:
- `HomeViewModel.swift:237-282` — Timer, countdown text formatting, next prayer logic
- `PrayerTimesViewModel.swift:53-107` — Same timer, same countdown logic

**Target Behavior:**
Single `PrayerCountdownManager` service handles:
- Fetching prayer times from `PrayerTimesService`
- Computing next prayer
- Managing countdown timer
- Formatting countdown text
- Notifying listeners of updates

**Step-by-Step Instructions:**

1. Create `Revenge/Core/Services/PrayerCountdownManager.swift`:
   ```swift
   import Foundation
   import CoreLocation
   import Combine
   
   @MainActor
   protocol PrayerCountdownManaging {
       var nextPrayerName: CurrentValueSubject<String, Never> { get }
       var nextPrayerTime: CurrentValueSubject<Date?, Never> { get }
       var countdownText: CurrentValueSubject<String, Never> { get }
       
       func startCountdown(location: CLLocationCoordinate2D, settings: AppSettings) async
       func stopCountdown()
   }
   
   @MainActor
   final class PrayerCountdownManager: PrayerCountdownManaging {
       let nextPrayerName = CurrentValueSubject<String, Never>("")
       let nextPrayerTime = CurrentValueSubject<Date?, Never>(nil)
       let countdownText = CurrentValueSubject<String, Never>("--:--:--")
       
       private let prayerTimesService: any PrayerTimesFetching
       private var timer: Timer?
       
       init(prayerTimesService: any PrayerTimesFetching = PrayerTimesService.shared) {
           self.prayerTimesService = prayerTimesService
       }
       
       func startCountdown(location: CLLocationCoordinate2D, settings: AppSettings) async {
           let times = await prayerTimesService.fetchPrayerTimes(
               coordinate: location,
               method: settings.calculationMethod,
               madhab: settings.madhab
           )
           guard let times = times else { return }
           
           let now = Date()
           if let next = times.all.first(where: { $0.time > now }) {
               nextPrayerName.send(next.name)
               nextPrayerTime.send(next.time)
           } else {
               nextPrayerName.send("Fajr")
               nextPrayerTime.send(Calendar.current.date(byAdding: .day, value: 1, to: times.fajr))
           }
           
           startTimer()
       }
       
       func stopCountdown() {
           timer?.invalidate()
           timer = nil
       }
       
       private func startTimer() {
           timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
               Task { @MainActor [weak self] in
                   guard let self = self, let target = self.nextPrayerTime.value else { return }
                   self.countdownText.send(Date().timeRemaining(to: target))
                   if target <= Date() {
                       await self.startCountdown(location: CLLocationCoordinate2D(...), settings: AppSettings.shared)
                   }
               }
           }
       }
       
       deinit {
           stopCountdown()
       }
   }
   ```

2. In `ServiceProtocols.swift`, add:
   ```swift
   protocol PrayerCountdownManaging: AnyObject {
       var nextPrayerName: CurrentValueSubject<String, Never> { get }
       var nextPrayerTime: CurrentValueSubject<Date?, Never> { get }
       var countdownText: CurrentValueSubject<String, Never> { get }
       
       func startCountdown(location: CLLocationCoordinate2D, settings: AppSettings) async
       func stopCountdown()
   }
   ```

3. Refactor `HomeViewModel`:
   - Remove `@Published var nextPrayerName`, `nextPrayerTime`, `countdownText`
   - Remove `private func loadPrayerCountdown()`, `updateNextPrayer()`, `startCountdownTimer()`
   - Add property: `private let countdownManager: any PrayerCountdownManaging`
   - In init, inject countdownManager
   - Bind countdown properties:
     ```swift
     func onAppear() {
         Task { 
             guard let location = locationService.currentLocation else { return }
             await countdownManager.startCountdown(location: location, settings: settings)
         }
         
         countdownManager.nextPrayerName
             .sink { [weak self] name in self?.nextPrayerName = name }
             .store(in: &cancellables)
         // Similar for nextPrayerTime, countdownText
     }
     ```
   - In `onDisappear()`: call `countdownManager.stopCountdown()`

4. Refactor `PrayerTimesViewModel` similarly

**Verification:**
- [ ] `PrayerCountdownManager` compiles and can be instantiated
- [ ] Both HomeViewModel and PrayerTimesViewModel inject manager
- [ ] No remaining Timer logic in ViewModels
- [ ] UI still shows countdown correctly
- [ ] Timer cleanup happens on disappear
- [ ] Tests can mock the manager

**Dependencies:**
- AD-04 (PrayerTimesViewModel DI setup)
- PrayerTimesFetching protocol (must accept location: CLLocationCoordinate2D)

**Risk/Rollback:**
- **Risk:** Medium. Timer logic changes require careful testing.
- **Mitigation:** Test countdown timer manually. Verify cleanup on dismiss.
- **Rollback:** Revert file, restore original countdown logic.

---

### AD-06: Extract BookmarkInteractor (Thin HomeViewModel)
**Priority:** P1  
**Files:**
- `Revenge/Core/Services/BookmarkInteractor.swift` (new file)
- `Revenge/Core/Services/ServiceProtocols.swift` (add protocol)
- `Revenge/Features/Home/HomeViewModel.swift` (refactor)

**Current Behavior:**
HomeViewModel has bookmarking responsibility (6 methods):
```swift
@Published var isAyahBookmarked = false
@Published var isHadithBookmarked = false

func checkBookmarkStates()
func toggleAyahBookmark()
func toggleHadithBookmark()
func shareAyahText()   // ← also responsibility creep
func shareHadithText()
```

**Target Behavior:**
New `BookmarkInteractor` manages:
- Checking bookmark state
- Toggling bookmarks
- Sharing text formatting

HomeViewModel delegates to it, stays thin.

**Step-by-Step Instructions:**

1. Create `Revenge/Core/Services/BookmarkInteractor.swift`:
   ```swift
   import Foundation
   import Combine
   
   @MainActor
   protocol BookmarkInteracting {
       func checkAyahBookmark(surah: Int, ayah: Int) -> Bool
       func toggleAyahBookmark(_ ayah: DailyAyah, cache: any AyahBookmarkManaging)
       func checkHadithBookmark(text: String, source: String) -> Bool
       func toggleHadithBookmark(_ hadith: DailyHadith, cache: any HadithBookmarkManaging)
       func shareAyahText(_ ayah: DailyAyah) -> String
       func shareHadithText(_ hadith: DailyHadith) -> String
   }
   
   @MainActor
   final class BookmarkInteractor: BookmarkInteracting {
       func checkAyahBookmark(surah: Int, ayah: Int) -> Bool {
           // delegate to cache
       }
       
       func toggleAyahBookmark(_ ayah: DailyAyah, cache: any AyahBookmarkManaging) {
           if cache.isAyahBookmarked(surah: ayah.surahNumber, ayah: ayah.ayahNumber) {
               cache.removeAyahBookmark(surah: ayah.surahNumber, ayah: ayah.ayahNumber)
           } else {
               let bookmark = BookmarkedAyah(...)
               cache.saveAyahBookmark(bookmark)
           }
       }
       
       func shareAyahText(_ ayah: DailyAyah) -> String {
           """
           \(ayah.arabicText)
           ...
           """
       }
       
       // Similar for hadith
   }
   ```

2. In `ServiceProtocols.swift`, add:
   ```swift
   protocol BookmarkInteracting {
       func checkAyahBookmark(surah: Int, ayah: Int) -> Bool
       // ...
   }
   ```

3. In `HomeViewModel`:
   - Remove `checkBookmarkStates()`, `toggleAyahBookmark()`, `toggleHadithBookmark()`, `shareAyahText()`, `shareHadithText()`
   - Remove `@Published var isAyahBookmarked`, `isHadithBookmarked`
   - Add: `private let bookmarkInteractor: any BookmarkInteracting`
   - Add to init parameter
   - Add to injected defaults
   - Move the logic into corresponding methods that delegate to interactor

**Verification:**
- [ ] `BookmarkInteractor` extracted and functional
- [ ] HomeViewModel delegates bookmark operations to interactor
- [ ] HomeViewModel still has @Published properties for UI binding (but not responsible for logic)
- [ ] Tests can mock BookmarkInteractor

**Dependencies:**
- AD-01 (bookmark protocols)
- AD-06 must follow AD-03 (ViewModel DI)

**Risk/Rollback:**
- **Risk:** Low. Extracting responsibility is safe refactor.
- **Rollback:** Revert file, restore methods to HomeViewModel.

---

### AD-07: Make PrayerTimesService Injectable
**Priority:** P1  
**Files:**
- `Revenge/Core/Services/PrayerTimesService.swift`
- `Revenge/Core/Services/ServiceProtocols.swift`

**Current Behavior:**
```swift
// PrayerTimesService.swift:36
let data = try await APIService.shared.fetchPrayerTimes(...)
```
PrayerTimesService hardcodes APIService.shared internally. Not testable.

**Target Behavior:**
PrayerTimesService accepts PrayerTimesFetching protocol:
```swift
final class PrayerTimesService {
    private let api: any PrayerTimesFetching
    
    init(api: any PrayerTimesFetching = APIService.shared) {
        self.api = api
    }
    
    func fetchPrayerTimes(...) async -> DayPrayerTimes? {
        let data = try await api.fetchPrayerTimes(...)
    }
}
```

**Step-by-Step Instructions:**

1. Open `ServiceProtocols.swift`
2. Verify `PrayerTimesFetching` protocol exists (should from AD-01 scope):
   ```swift
   protocol PrayerTimesFetching: Sendable {
       func fetchPrayerTimes(latitude: Double, longitude: Double, method: Int) async throws -> AladhanData
   }
   ```

3. In `PrayerTimesService.swift`:
   - Add property: `private let api: any PrayerTimesFetching`
   - Add init:
     ```swift
     private let shared = PrayerTimesService()  // Singleton still available
     
     private init(api: any PrayerTimesFetching = APIService.shared) {
         self.api = api
     }
     
     // For testing
     init(api: any PrayerTimesFetching) {
         self.api = api
     }
     ```
   - Replace `APIService.shared.fetchPrayerTimes(...)` with `api.fetchPrayerTimes(...)`

**Verification:**
- [ ] PrayerTimesService accepts injected API service
- [ ] Singleton still works for production
- [ ] Mocks can be injected in tests
- [ ] No breaking changes to public API

**Dependencies:**
- PrayerTimesFetching protocol must exist

**Risk/Rollback:**
- **Risk:** Low. Backward compatible via private init.
- **Rollback:** Revert file.

---

### AD-08: Move QuranAyahIndex to Domain Layer
**Priority:** P2  
**Files:**
- `Revenge/Core/Models/QuranAyahIndex.swift` (new file)
- `Revenge/Core/Services/APIService.swift` (remove lines 137-180, import from Models)

**Current Behavior:**
```swift
// APIService.swift:137-180
enum QuranAyahIndex {
    static let ayahCounts: [Int] = [...]
    static let prefixSums: [Int] = [...]
    static func globalIndex(surah: Int, ayahInSurah: Int) -> Int?
}
```

**Problem:** Domain logic (static lookup table) in a service file. Should be in Models.

**Target Behavior:**
Separate file: `Revenge/Core/Models/QuranAyahIndex.swift`

**Step-by-Step Instructions:**

1. Create `Revenge/Core/Models/QuranAyahIndex.swift`:
   - Copy entire `enum QuranAyahIndex` block from APIService (lines 137-180)

2. In `APIService.swift`:
   - Delete lines 137-180 (enum QuranAyahIndex definition)
   - Add import at top: `import QuranAyahIndex` (or rely on same module)
   - Keep usage of `QuranAyahIndex.globalIndex()` — it still works (same module)

3. Update file organization comments in APIService

**Verification:**
- [ ] QuranAyahIndex.swift created and compiles
- [ ] APIService still compiles (no import needed, same module)
- [ ] `audioURL()` still works (QuranAyahIndex still accessible)
- [ ] Logic unchanged

**Dependencies:**
- None

**Risk/Rollback:**
- **Risk:** Very low. Pure file move.
- **Rollback:** Revert both files.

---

### AD-09: Move Response Types to Models Layer
**Priority:** P2  
**Files:**
- `Revenge/Core/Models/APIResponseTypes.swift` (new file)
- `Revenge/Core/Services/APIService.swift` (remove, import)

**Current Behavior:**
```swift
// APIService.swift:198-230
struct AyahResponse: Codable { ... }
struct AyahDetailResponse: Codable { ... }
struct HijriConvertResponse: Codable { ... }
// etc.
```

**Problem:** Response decodables are models, not service code. Belong in Models layer.

**Target Behavior:**
New file `Revenge/Core/Models/APIResponseTypes.swift` containing all response structs.

**Step-by-Step Instructions:**

1. Create `Revenge/Core/Models/APIResponseTypes.swift`:
   - Copy lines 198-230 from APIService.swift

2. In `APIService.swift`:
   - Delete lines 198-230
   - File will still compile (models in same module target)

3. If needed, update imports in files using these types (should be transparent)

**Verification:**
- [ ] APIResponseTypes.swift created
- [ ] All response types defined and compile
- [ ] APIService.swift compiles (no explicit import needed)
- [ ] Tests still reference correct types

**Dependencies:**
- None

**Risk/Rollback:**
- **Risk:** Very low. Pure file move.
- **Rollback:** Revert files.

---

### AD-10: Move ContentLoadState to Shared Location
**Priority:** P2  
**Files:**
- `Revenge/Core/Models/LoadState.swift` (new file)
- `Revenge/Features/Home/HomeViewModel.swift` (remove lines 10-15, import)

**Current Behavior:**
```swift
// HomeViewModel.swift:10-15
enum ContentLoadState {
    case loading
    case loaded
    case failed
    case offline
}
```

**Problem:** Reusable enum buried in specific ViewModel. Should be shared.

**Target Behavior:**
```
// Revenge/Core/Models/LoadState.swift
enum ContentLoadState {
    case loading
    case loaded
    case failed
    case offline
}
```

HomeViewModel imports and uses it.

**Step-by-Step Instructions:**

1. Create `Revenge/Core/Models/LoadState.swift`:
   ```swift
   import Foundation
   
   enum ContentLoadState {
       case loading
       case loaded
       case failed
       case offline
   }
   ```

2. In `HomeViewModel.swift`:
   - Delete lines 10-15 (enum definition)
   - No import needed (same module)

3. Consider renaming to `LoadState` or `ContentState` (more generic, reusable)

**Verification:**
- [ ] LoadState.swift created
- [ ] HomeViewModel still compiles
- [ ] Other ViewModels can now use same enum if desired
- [ ] No functional changes

**Dependencies:**
- None

**Risk/Rollback:**
- **Risk:** Very low. Pure file move.
- **Rollback:** Revert files.

---

### AD-11: Move ShareSheet to Shared Components
**Priority:** P2  
**Files:**
- `Revenge/Core/UI/Components/ShareSheet.swift` (new file)
- `Revenge/Features/Home/HomeView.swift` (remove lines 418-426, import)

**Current Behavior:**
```swift
// HomeView.swift:418-426
struct ShareSheet: UIViewControllerRepresentable {
    let text: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
```

**Problem:** General-purpose component in feature-specific view file.

**Target Behavior:**
Shared `Revenge/Core/UI/Components/ShareSheet.swift` importable by any view.

**Step-by-Step Instructions:**

1. Create `Revenge/Core/UI/Components/ShareSheet.swift`:
   - Copy struct definition from HomeView

2. In `HomeView.swift`:
   - Delete lines 418-426
   - Add import if in different module (or same module, no import needed)

3. Verify HomeView still uses ShareSheet correctly

**Verification:**
- [ ] ShareSheet.swift created and compiles
- [ ] HomeView imports/references ShareSheet correctly
- [ ] ShareSheet still used in HomeView
- [ ] Other views can now reuse ShareSheet

**Dependencies:**
- None

**Risk/Rollback:**
- **Risk:** Very low. Pure file move.
- **Rollback:** Revert files.

---

### AD-12: Remove Dead SettingsViewModel, Refactor SettingsView
**Priority:** P2  
**Files:**
- `Revenge/Features/Settings/SettingsViewModel.swift` (delete)
- `Revenge/Features/Settings/SettingsView.swift` (refactor)

**Current Behavior:**
```swift
// SettingsViewModel.swift
final class SettingsViewModel: ObservableObject {
    @Published var settings = AppSettings.shared
    // ...
}

// SettingsView uses AppSettings.shared directly, ignoring the ViewModel
```

**Problem:** SettingsViewModel defined but unused. SettingsView uses AppSettings.shared directly.

**Target Behavior:**
- Delete unused SettingsViewModel
- SettingsView uses AppSettings directly (current de facto pattern)
- OR: Define protocol for AppSettings if needed elsewhere

**Step-by-Step Instructions:**

1. Search for imports/references to `SettingsViewModel`:
   ```bash
   grep -r "SettingsViewModel" Revenge/Features/Settings/
   ```

2. If no references found, delete `SettingsViewModel.swift`

3. Update `SettingsView.swift`:
   - Verify it directly accesses `AppSettings.shared` (correct pattern)
   - If needed, create protocol `AppSettings` or `SettingsManaging` to make it injectable later

4. Confirm SettingsView compiles and functions correctly

**Verification:**
- [ ] SettingsViewModel.swift deleted
- [ ] SettingsView still compiles
- [ ] No compile errors in codebase
- [ ] Settings UI works as before

**Dependencies:**
- None

**Risk/Rollback:**
- **Risk:** Low. Only removing dead code.
- **Rollback:** Restore SettingsViewModel.swift if needed.

---

### AD-13: Code Cleanup - Remove Commented Code & Update Documentation
**Priority:** P2  
**Files:**
- `Revenge/Features/Settings/SettingsView.swift` (remove commented lines 161-163)
- `Revenge/Core/Services/ServiceProtocols.swift` (add header documentation)
- `Revenge/Features/Home/HomeViewModel.swift` (add class documentation)

**Current Behavior:**
```swift
// SettingsView.swift:161-163
// Toggle(isOn: $settings.showTransliteration) {
//     Text("Show Transliteration")
// }
```

**Target Behavior:**
- Remove commented code
- Add clear documentation headers to each protocol
- Document assumptions and thread safety for protocols

**Step-by-Step Instructions:**

1. In `SettingsView.swift`:
   - Search for all `//` commented lines (not documentation)
   - Remove any debug/WIP comments
   - Keep MARK comments

2. In `ServiceProtocols.swift`:
   - Add header to file:
     ```swift
     /// Service protocol definitions for dependency injection.
     /// All protocols are `Sendable` to support actor-isolated ViewModels.
     /// 
     /// Protocol hierarchy:
     /// - Content fetching: AyahFetching, HadithFetching, SurahFetching
     /// - Caching (split by responsibility): DailyContentCaching, BookmarkManaging*, StreakPersisting, etc.
     /// - Prayer times: PrayerTimesFetching, PrayerCountdownManaging
     /// - Others: LocationManaging, SettingsManaging, etc.
     ```
   - Add documentation to each protocol explaining what it abstracts and which ViewModels/Services use it

3. In `HomeViewModel.swift`:
   - Add class header:
     ```swift
     /// Coordinator ViewModel for the home screen.
     /// 
     /// Responsibilities:
     /// - Daily Ayah & Hadith fetching and display
     /// - Prayer time countdown timer management
     /// - Streak tracking and routine progress
     /// - Bookmark state management (delegated to BookmarkInteractor)
     /// 
     /// Dependencies injected via init() for testability.
     ```

4. Run SwiftLint (if available) to flag remaining issues

**Verification:**
- [ ] All commented code removed
- [ ] Protocol documentation added
- [ ] ViewModel class documentation clear
- [ ] Code still compiles and functions correctly

**Dependencies:**
- None (documentation-only)

**Risk/Rollback:**
- **Risk:** Very low. No logic changes.
- **Rollback:** Revert files.

---

## Execution Timeline

### Phase 1: Protocol Refactoring (Week 1)
| Task | Day | Est. Hours | Owner |
|------|-----|-----------|-------|
| AD-01: CacheManaging split | Mon-Tue | 4 | Architecture Lead |
| AD-10: LoadState extraction | Wed | 1 | Any |
| AD-08: QuranAyahIndex move | Wed | 1 | Any |
| AD-09: APIResponseTypes move | Thu | 1 | Any |
| Testing & integration | Fri | 2 | QA |
| **Phase 1 Total** | **Week 1** | **9** | — |

### Phase 2: ViewModel DI Fixes (Week 1-2)
| Task | Day | Est. Hours | Owner |
|------|-----|-----------|-------|
| AD-02: ReadingViewModel | Mon-Tue | 3 | Feature Owner |
| AD-03: Bookmarks/Journal/Surah VMs | Tue-Wed | 5 | Feature Owner |
| AD-04: PrayerTimesViewModel + LocationService | Thu-Fri | 6 | Prayer Times Owner |
| Testing & integration | Fri-Mon | 3 | QA |
| **Phase 2 Total** | **Week 1-2** | **17** | — |

### Phase 3: Service Extraction (Week 2-3)
| Task | Day | Est. Hours | Owner |
|------|-----|-----------|-------|
| AD-05: PrayerCountdownManager | Mon-Tue | 8 | Services Lead |
| AD-06: BookmarkInteractor | Wed-Thu | 4 | Services Lead |
| AD-07: PrayerTimesService DI | Thu | 2 | Services Lead |
| Testing & integration | Fri | 4 | QA |
| **Phase 3 Total** | **Week 2-3** | **18** | — |

### Phase 4: Cleanup (Week 3-4)
| Task | Day | Est. Hours | Owner |
|------|-----|-----------|-------|
| AD-11: ShareSheet component | Mon | 1 | UI Lead |
| AD-12: SettingsViewModel cleanup | Mon | 1 | Feature Owner |
| AD-13: Documentation & code cleanup | Tue-Wed | 3 | Tech Lead |
| Final testing & QA | Thu-Fri | 4 | QA |
| **Phase 4 Total** | **Week 3-4** | **9** | — |

**Total Estimate:** 3-4 weeks, ~53 hours engineering effort

---

## Success Criteria

### Metrics to Track
- **Testability:** 100% of ViewModels injectable via init() with protocol parameters
- **Test Coverage:** 80%+ unit test coverage for ViewModels and extracted services
- **Singleton References:** 0 hardcoded `.shared` calls within ViewModels
- **Protocol Compliance:** All services conform to at least one protocol
- **Duplication:** 0 instances of duplicated countdown/bookmark logic

### Verification Checklist
- [ ] All 13 tasks completed
- [ ] Codebase compiles without errors/warnings
- [ ] Unit tests pass (80%+ coverage)
- [ ] Integration tests pass
- [ ] Manual QA on all affected screens
- [ ] No regressions in HomeView, PrayerTimes, Bookmarks, Settings, Quran screens
- [ ] Code review approval from Architecture Lead
- [ ] Documentation updated (inline comments, README if applicable)

---

## Risk Assessment & Mitigations

| Risk | Severity | Mitigation |
|------|----------|-----------|
| Timer cleanup on ViewDisappear fails | Medium | Manual testing. Unit test timer lifecycle. |
| Published property bridging for mocks | Medium | Create helper extensions. Test mocks early. |
| Backward compatibility breaks | Medium | Provide default parameters. Test existing call sites. |
| Test mock boilerplate explodes | Low | Use protocol composition. Create mock factories. |
| Duplicate code remains | Low | Code review focus. Lint rules if possible. |

---

## Post-Implementation

### Maintenance
- **Code review checklist:** Always use protocol injection for new ViewModels.
- **Linting:** Consider SwiftLint rule to flag `.shared` usage in ViewModels.
- **Testing:** Require unit tests for all new ViewModels with mock injection.

### Future Enhancements
1. **Phase 2 (future sprint):**
   - Extract RoutineService DI (currently hardcoded in HomeViewModel)
   - Create NotificationService protocol abstraction
   - Add AppSettings protocol (currently uses AppSettings.shared directly)

2. **Phase 3 (future):**
   - Consider dependency injection container (DIContainer or similar) to reduce init boilerplate
   - Implement service locator pattern if needed for deep dependency graphs

3. **Phase 4 (future):**
   - Performance audit: Ensure protocol dispatch overhead is negligible
   - Memory audit: Ensure weak captures prevent retain cycles in async services

---

## File Paths Summary

### New Files to Create
- `/Users/abdul/Documents/project_swift/Revenge/Revenge/Core/Services/PrayerCountdownManager.swift`
- `/Users/abdul/Documents/project_swift/Revenge/Revenge/Core/Services/BookmarkInteractor.swift`
- `/Users/abdul/Documents/project_swift/Revenge/Revenge/Core/Models/QuranAyahIndex.swift`
- `/Users/abdul/Documents/project_swift/Revenge/Revenge/Core/Models/APIResponseTypes.swift`
- `/Users/abdul/Documents/project_swift/Revenge/Revenge/Core/Models/LoadState.swift`
- `/Users/abdul/Documents/project_swift/Revenge/Revenge/Core/UI/Components/ShareSheet.swift`

### Files to Modify
- `/Users/abdul/Documents/project_swift/Revenge/Revenge/Core/Services/ServiceProtocols.swift` (refactor, add protocols)
- `/Users/abdul/Documents/project_swift/Revenge/Revenge/Core/Services/APIService.swift` (remove lines, restructure)
- `/Users/abdul/Documents/project_swift/Revenge/Revenge/Core/Services/CacheManager.swift` (update conformances)
- `/Users/abdul/Documents/project_swift/Revenge/Revenge/Core/Services/PrayerTimesService.swift` (add DI)
- `/Users/abdul/Documents/project_swift/Revenge/Revenge/Core/Services/LocationService.swift` (add conformance)
- `/Users/abdul/Documents/project_swift/Revenge/Revenge/Features/Home/HomeViewModel.swift` (DI, extract logic)
- `/Users/abdul/Documents/project_swift/Revenge/Revenge/Features/Home/HomeView.swift` (remove ShareSheet)
- `/Users/abdul/Documents/project_swift/Revenge/Revenge/Features/Quran/ReadingViewModel.swift` (add DI)
- `/Users/abdul/Documents/project_swift/Revenge/Revenge/Features/Bookmarks/BookmarksViewModel.swift` (add DI)
- `/Users/abdul/Documents/project_swift/Revenge/Revenge/Features/Journal/JournalViewModel.swift` (add DI)
- `/Users/abdul/Documents/project_swift/Revenge/Revenge/Features/Quran/SurahListViewModel.swift` (add DI)
- `/Users/abdul/Documents/project_swift/Revenge/Revenge/Features/PrayerTimes/PrayerTimesViewModel.swift` (add DI, extract logic)
- `/Users/abdul/Documents/project_swift/Revenge/Revenge/Features/Settings/SettingsView.swift` (remove comments)
- `/Users/abdul/Documents/project_swift/Revenge/RevengeTests/Mocks/ServiceMocks.swift` (update mocks)

### Files to Delete
- `/Users/abdul/Documents/project_swift/Revenge/Revenge/Features/Settings/SettingsViewModel.swift`

---

## Appendix: Protocol Hierarchy Diagram

```
┌─ Fetching Protocols ──────────────────────────┐
│ - AyahFetching                                │
│ - HadithFetching                              │
│ - SurahFetching                               │
│ - PrayerTimesFetching                         │
└───────────────────────────────────────────────┘
           ↓ Implemented by
    APIService

┌─ Caching Protocols (Segregated) ──────────────┐
│ - DailyContentCaching                         │
│ - AyahBookmarkManaging                        │
│ - HadithBookmarkManaging                      │
│ - StreakPersisting                            │
│ - RoutinePersisting                           │
│ - SurahCaching                                │
│ - JournalPersisting                           │
│                                               │
│ - CacheManaging (composition of all 7)        │
└───────────────────────────────────────────────┘
           ↓ Implemented by
    CacheManager

┌─ Service Protocols ───────────────────────────┐
│ - LocationManaging                            │
│ - PrayerCountdownManaging                     │
│ - BookmarkInteracting                         │
│ - StreakTracking                              │
│ - RoutineProviding                            │
└───────────────────────────────────────────────┘
           ↓ Implemented by
    LocationService, PrayerCountdownManager, etc.
```

---

## Approval Sign-Off

- **Architecture Lead:** _________________ Date: _______
- **Engineering Lead:** _________________ Date: _______
- **QA Lead:** _________________ Date: _______
- **Product Manager:** _________________ Date: _______

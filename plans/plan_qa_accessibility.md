# QA & Accessibility Implementation Plan

**Department:** QA & Accessibility  
**Project:** Kheir (Revenge iOS App)  
**Created:** April 26, 2026  
**Status:** Ready for Engineering Team

---

## Department Overview

The QA & Accessibility department is responsible for ensuring the Kheir app meets quality standards across testing infrastructure, accessibility compliance (WCAG 2.1 Level AA), and user experience robustness. This plan addresses 13 identified issues spanning UI testing failures, mock synchronization problems, accessibility gaps, API deprecations, dead code, and error logging practices.

**Key Objectives:**
- Fix 4 failing UI tests and prevent future UI test flakiness
- Eliminate shared state interference in unit tests  
- Bring mock test objects to thread-safety standards
- Add accessibility labels to all interactive elements
- Replace deprecated MapKit APIs
- Remove dead state variables and clean up dead code
- Implement structured logging across the application
- Ensure VoiceOver users have full context for all interactive elements

---

## Priority Order

1. **QA-01** — Fix 4 failing UI tests (HIGH) — *blocks release*
2. **QA-02** — Fix CacheManagerTests flaky shared state (HIGH) — *blocks CI/CD*
3. **QA-03** — Fix MockAPIService @unchecked Sendable synchronization (HIGH) — *thread-safety issue*
4. **QA-04** — Add accessibility labels to HomeView ayah/hadith card buttons (MEDIUM)
5. **QA-05** — Fix PrayerTime.id instability in SwiftUI ForEach (MEDIUM)
6. **QA-06** — Replace deprecated Map API in MasjidFinderView (MEDIUM)
7. **QA-07** — Remove duplicate selectedMasjid state (MEDIUM)
8. **QA-08** — Remove dead isNavigating variable in RoutineCardView (MEDIUM)
9. **QA-09** — Add input validation for manual city geocoding (MEDIUM)
10. **QA-10** — Replace print() statements with os.Logger (LOW)
11. **QA-11** — Add reduceMotion check to ScrollRevealModifier (LOW)
12. **QA-12** — Refactor shareAyah UIKit presentation (LOW)
13. **QA-13** — Replace DispatchQueue.main.asyncAfter with Task.sleep (LOW)

---

## Task Details

### QA-01: Fix 4 Failing UI Tests

**Priority:** P0 (HIGH — blocks release)  
**Assigned Files:**
- `RevengeUITests/RevengeUITests.swift` (Lines 31, 52, 115, 155)

**Current Behavior:**
- 4 UI test failures in the test suite including:
  - `testThemePickerExistsInSettings` — segmented control not found
  - Possible failures in `testSplashTransitionsToHomeTab`, `testHomeDisplaysCountdown`, `testNavigateToBookmarksTab`
- Tests fail intermittently due to timing issues, accessibility identifier mismatches, or state management

**Target Behavior:**
- All 7 UI tests pass consistently on every run
- Tests accurately identify UI elements by accessibility identifier, not fragile description matching
- Tests have appropriate timeouts aligned with actual animation/network delays

**Step-by-Step Instructions:**

1. **Run the full UI test suite locally** to identify which specific tests are failing:
   ```
   xcodebuild test -scheme RevengeUITests
   ```
   Document which tests fail and the failure messages.

2. **For each failing test:**
   - Open the test in Xcode and run it in isolation with verbose logging enabled
   - Use `XCUIApplication().launchArguments` to ensure `--uitesting` flag is set
   - Check if the failure is due to:
     - Missing or incorrect accessibility identifier (element not found)
     - Timeout too short for app state transitions
     - Navigation flow issue (previous test's state pollution)
     - Accessibility element hidden or not rendered

3. **For `testThemePickerExistsInSettings`:**
   - Verify that `SettingsView` renders a segmented control with identifier `themePicker`
   - If the identifier exists, increase the timeout from 5 to 8 seconds (splash delay ~2.5s + navigation ~1s + scroll ~0.5s)
   - If the identifier is missing, add `.accessibilityIdentifier("themePicker")` to the Picker in SettingsView

4. **For `testSplashTransitionsToHomeTab`:**
   - Verify `SplashScreenView` marks the splash container with `accessibilityIdentifier("splashScreen")`
   - Verify `HomeView` marks the tab bar with correct identifiers
   - Ensure splash delay (2.5s) is respected by timeout (8s currently OK)

5. **For `testHomeDisplaysCountdown`:**
   - Verify `prayerCountdown` label exists and is set on the countdown Text
   - Check that countdown updates when location becomes available
   - If location permission denied, countdown shows "--:--:--" as fallback

6. **For `testNavigateToBookmarksTab`:**
   - Verify the `BookmarksView` renders `bookmarksView` container identifier
   - Verify either empty state or list renders (currently accepts both)
   - Check tab navigation works after splash

7. **Update `navigateToSettings()` helper:**
   - The helper already tries multiple candidates (good)
   - Ensure it always succeeds by catching timeout and providing better error message
   - Consider adding a fallback to match by toolbar position (rightmost button) if all candidates fail

8. **Add `continueAfterFailure = true` for intermediate assertions:**
   - Change to `continueAfterFailure = false` only for critical path assertions
   - This allows tests to proceed and gather more debugging info on subsequent failures

**Verification:**
- Run full UI test suite 3 times in a row — all 7 tests pass consistently
- Run individual tests in any order — all pass
- UI test suite passes on both iPhone 16 Pro simulator and any generic iOS device target

**Dependencies:**
- None (standalone tests)

**Risk/Rollback:**
- Low risk: changes are additive (accessibility identifiers, timeout increases)
- If a test still fails after fixing identifiers, the issue is likely in the feature implementation, not the test
- Rollback: revert to previous test suite version and document which identifiers/timeouts are missing

---

### QA-02: Fix CacheManagerTests Shared State Causing Flaky Tests

**Priority:** P0 (HIGH — blocks CI/CD)  
**Assigned Files:**
- `RevengeTests/CacheManagerTests.swift` (Lines 82–89 in `removeHadithBookmarkByTextSource`)

**Current Behavior:**
- `CacheManager.shared` is a singleton used by all test suites
- Test `removeHadithBookmarkByTextSource` fails intermittently because:
  - Another suite's `defer { cache.removeHadithBookmark(id: bookmark.id) }` races with this suite's assertion
  - Cleanup order is non-deterministic across test runs
  - `@Suite(..., .serialized)` enforces serial execution within a suite but NOT across suites

**Target Behavior:**
- All CacheManager tests pass consistently regardless of execution order
- No cross-suite state pollution
- Test cleanup is deterministic and doesn't affect other tests

**Step-by-Step Instructions:**

1. **Analyze the problem structure:**
   - Three test suites exist: `CacheManagerAyahTests`, `CacheManagerHadithTests`, `CacheManagerJournalTests`
   - All reference `CacheManager.shared` (line 7, 53, 95)
   - Each test uses `defer { cache.remove...() }` for cleanup
   - The `.serialized` parameter only serializes tests *within* a suite

2. **Implement isolated cache per test suite:**
   - Instead of `let cache = CacheManager.shared`, use a fresh instance or a seeded test double
   - Option A: Create a test-specific `CacheManager` instance (if it supports non-shared initialization)
   - Option B: Wrap `CacheManager.shared` in a test helper that saves/restores state

3. **If CacheManager is a pure singleton with no non-shared variant:**
   - Add a new `static func resetForTesting()` method to `CacheManager`
   - This method clears all in-memory or UserDefaults storage
   - Call `CacheManager.resetForTesting()` in a `setUp()` method that runs before each test

4. **Add explicit setup/teardown for each test:**
   ```
   init {
       // Save initial state
       initialBookmarks = cache.loadHadithBookmarks()
   }
   
   deinit {
       // Restore initial state (or clear)
       cache.removeAllHadithBookmarks() // if this method exists
   }
   ```

5. **Or use the `MockCacheManager` in tests:**
   - Instead of `CacheManager.shared`, inject `MockCacheManager()` (which has in-memory storage)
   - This is the cleanest approach: mocks are already isolated per test instance

6. **If using real `CacheManager.shared` is mandatory:**
   - Ensure all `defer` blocks run **synchronously** (they already do)
   - Add explicit barriers between tests: e.g., run `CacheManager.resetForTesting()` after each test
   - Use `@Suite(..., .serialized)` for **all** cache test suites (already done, verify this)

7. **Update CacheManagerTests file:**
   - Change line 7 to use `MockCacheManager()` or a test-isolated variant
   - Change lines 53 and 95 similarly
   - Verify no references to `CacheManager.shared` remain in these test suites

**Verification:**
- Run `RevengeTests` 10 times consecutively without failure
- Run tests in reverse order (CacheManagerJournalTests first, then Hadith, then Ayah) — all pass
- Run only `CacheManagerHadithTests` in isolation — all pass
- Run test `removeHadithBookmarkByTextSource` 20 times — 100% pass rate

**Dependencies:**
- Requires understanding of whether `CacheManager` can be instantiated non-shared
- May require adding a `resetForTesting()` or similar method to `CacheManager`

**Risk/Rollback:**
- Medium risk: changes to test setup/teardown
- If using `MockCacheManager`, verify it implements all `CacheManaging` methods correctly
- If tests still flake, log the state of cache before/after each test assertion to identify the race

---

### QA-03: Fix MockAPIService @unchecked Sendable Thread Safety

**Priority:** P0 (HIGH — thread-safety)  
**Assigned Files:**
- `RevengeTests/Mocks/ServiceMocks.swift` (Lines 6–84)

**Current Behavior:**
- `MockAPIService` declares `@unchecked Sendable` but contains mutable `var` properties:
  - `var ayahResult` (line 9)
  - `var ayahTranslationResult` (line 13)
  - `var hadithResult` (line 26)
  - `var hadithSectionResult` (line 65)
  - `private(set) var fetchAyahCallCount` (line 42)
  - `private(set) var fetchAyahTranslationCallCount` (line 43)
  - `private(set) var fetchHadithCallCount` (line 44)
- No synchronization mechanism (locks, actors) protects concurrent access
- Swift 6 strict concurrency will reject this pattern

**Target Behavior:**
- `MockAPIService` is truly thread-safe for concurrent reads/writes
- All mutable properties are guarded by a lock or wrapped in an actor
- `@unchecked Sendable` is removed or properly justified with a `nonisolated` marker

**Step-by-Step Instructions:**

1. **Add a synchronization mechanism:**

   Option A: Use a lock (simplest for mocks):
   ```swift
   final class MockAPIService: AyahFetching, HadithFetching, Sendable {
       private let lock = NSLock()
       
       private var _ayahResult: Result<Ayah, Error> = .success(...)
       var ayahResult: Result<Ayah, Error> {
           get {
               lock.lock()
               defer { lock.unlock() }
               return _ayahResult
           }
           set {
               lock.lock()
               defer { lock.unlock() }
               _ayahResult = newValue
           }
       }
   }
   ```

   Option B: Use a nonisolated MainActor (if all test code runs on main thread):
   ```swift
   final class MockAPIService: AyahFetching, HadithFetching, @MainActor {
       var ayahResult: Result<Ayah, Error> = .success(...)
       // all properties are now main-thread-only
   }
   ```

   Option C: Convert to an Actor (modern approach):
   ```swift
   actor MockAPIService: AyahFetching, HadithFetching {
       var ayahResult: Result<Ayah, Error> = .success(...)
       
       nonisolated func fetchAyahTranslation(...) async throws -> AyahDetailData {
           // async version
       }
   }
   ```

2. **Choose the approach based on test usage:**
   - If tests always run on the main thread: use `@MainActor`
   - If tests use async/await with Task.detached: use Actor or lock
   - For mocks, Option A (lock) is safest and clearest

3. **Protect all mutable properties:**
   - `ayahResult` → wrap in lock or mark `@MainActor`
   - `ayahTranslationResult` → wrap in lock or mark `@MainActor`
   - `hadithResult` → wrap in lock or mark `@MainActor`
   - `hadithSectionResult` → wrap in lock or mark `@MainActor`
   - Call count properties → either make immutable or wrap in lock

4. **Remove `@unchecked Sendable` or replace with proper conformance:**
   - If using lock: keep `final class MockAPIService: AyahFetching, HadithFetching, Sendable`
   - If using `@MainActor`: replace with `@MainActor final class MockAPIService: AyahFetching, HadithFetching, Sendable`
   - If using Actor: replace with `actor MockAPIService: AyahFetching, HadithFetching` (Actor is implicitly Sendable)

5. **Update test code to handle async access if using Actor:**
   - If converting to an actor, async methods require `await`
   - E.g., `let result = await mockAPI.ayahResult` instead of `let result = mockAPI.ayahResult`
   - This is a breaking change for all tests using this mock — review carefully

6. **Recommendation: Use Option A (NSLock) for minimal disruption:**
   - Tests are synchronous, mocks are used serially
   - Lock is cheap and allows property access to remain synchronous
   - Minimal changes to test code

7. **Do the same for `MockCacheManager` and `MockRoutineService` if they also use `@unchecked Sendable`:**
   - Check lines 88 and 207 of ServiceMocks.swift
   - Apply the same pattern

**Verification:**
- Run tests with `-Xswiftc -suppress-warnings=false` to enable concurrency warnings
- Swift compiler shows no "Sendable" warnings for MockAPIService
- Tests compile and run without runtime thread-safety errors
- Tests pass in both debug and release mode

**Dependencies:**
- Requires understanding of Swift Concurrency patterns (Sendable, Actor, MainActor)
- May require updating test code if converting to async/await

**Risk/Rollback:**
- Medium risk: changes to mock implementation
- If tests break after changes, revert to the previous version and use the lock approach
- Lock approach is safest for synchronous test code

---

### QA-04: Add Accessibility Labels to HomeView Interactive Elements

**Priority:** P1 (MEDIUM)  
**Assigned Files:**
- `Revenge/Features/Home/HomeView.swift` (Lines 212–215, 286–290)

**Current Behavior:**
- Share button on ayah card (line 212–215) has no `.accessibilityLabel`
- Bookmark button on ayah card (line 192–200) HAS a label ✓
- Hadith card buttons (lines 286–290) have no or incomplete labels
- VoiceOver users hear "button" with no context about what the button does

**Target Behavior:**
- All interactive elements have descriptive accessibility labels
- VoiceOver users understand what each button does without seeing the visual icon
- Labels follow WCAG naming conventions (action-oriented, specific)

**Step-by-Step Instructions:**

1. **Locate the share button in dailyAyahCard (line 212–215):**
   ```swift
   Button {
       shareCardData = ShareCardData(...)
   } label: {
       Image(systemName: "square.and.arrow.up")
   }
   ```

2. **Add an accessibility label:**
   ```swift
   Button {
       shareCardData = ShareCardData(...)
   } label: {
       Image(systemName: "square.and.arrow.up")
   }
   .accessibilityLabel("Share ayah")
   ```

3. **Check hadith card buttons (lines 286–290):**
   - The section is incomplete in the current code (shows `HStack { Spacer() }`)
   - Locate the actual hadith card button implementations (should be similar to ayah card)
   - Verify they have labels for: bookmark, copy, share buttons

4. **Add labels to hadith card buttons (if missing):**
   - Bookmark button: `.accessibilityLabel(viewModel.isHadithBookmarked ? "Remove hadith bookmark" : "Bookmark hadith")`
   - Copy button: `.accessibilityLabel(isCopied ? "Copied" : "Copy hadith")`
   - Share button: `.accessibilityLabel("Share hadith")`

5. **Verify language toggle button on hadith card (line 234–244):**
   - Already has label: `.accessibilityLabel(showArabicHadith ? "Show English Hadith" : "Show Arabic Hadith")` ✓

6. **Check if hadith card actions row is incomplete:**
   - Lines 286–290 show only `HStack { Spacer() }` with a comment "Bookmarks and share row remain unchanged..."
   - This suggests the actual implementation is missing from the provided code
   - Complete the implementation by mirroring the ayah card actions row

7. **Test with VoiceOver:**
   - Enable VoiceOver in Simulator (Settings > Accessibility > VoiceOver)
   - Tap each button and listen to the label spoken by VoiceOver
   - Verify the label matches the button's action

**Verification:**
- Enable VoiceOver in Simulator
- Navigate to Home tab
- Swipe through all interactive elements on ayah card — VoiceOver speaks descriptive labels
- Swipe through all interactive elements on hadith card — VoiceOver speaks descriptive labels
- No VoiceOver element is labeled just "button" without additional context

**Dependencies:**
- None (purely additive changes)

**Risk/Rollback:**
- Low risk: labels are read-only properties
- Rollback: remove the `.accessibilityLabel()` modifier

---

### QA-05: Fix PrayerTime.id Instability in SwiftUI ForEach

**Priority:** P1 (MEDIUM)  
**Assigned Files:**
- `Revenge/Core/Models/PrayerModels.swift` (Lines 3–15)

**Current Behavior:**
- `PrayerTime` has `let id = UUID()` which generates a new UUID on **each initialization**
- `DayPrayerTimes.all` computed property creates new `PrayerTime` instances every time it's accessed
- SwiftUI `ForEach` treats all PrayerTime items as new (different IDs) on every state change
- This causes unnecessary re-renders, animation jank, and list item refresh on every update

**Target Behavior:**
- Each prayer (Fajr, Sunrise, Dhuhr, etc.) has a **stable, unique identifier**
- The ID remains the same across multiple computations of `DayPrayerTimes.all`
- SwiftUI ForEach recognizes that a prayer at the same index is still the "same" prayer, avoiding unnecessary re-renders

**Step-by-Step Instructions:**

1. **Identify the root cause:**
   - `PrayerTime` struct with `let id = UUID()` is problematic because structs are value types
   - Every time `PrayerTime(name: "Fajr", ...)` is instantiated, a new UUID is created
   - `DayPrayerTimes.all` creates these instances fresh on each access

2. **Option A: Use a stable string identifier based on prayer name:**
   ```swift
   struct PrayerTime: Identifiable {
       let id: String  // Change from UUID to String
       let name: String
       let time: Date
       let icon: String
       var isNext: Bool = false
       
       init(name: String, time: Date, icon: String, isNext: Bool = false) {
           self.name = name
           self.time = time
           self.icon = icon
           self.isNext = isNext
           self.id = name  // Use prayer name as ID (Fajr, Sunrise, etc. are always unique)
       }
   }
   ```

3. **Option B: Use a computed property that generates a stable hash:**
   ```swift
   struct PrayerTime: Identifiable {
       let name: String
       let time: Date
       let icon: String
       var isNext: Bool = false
       
       var id: String {
           name  // Stable ID based on prayer name
       }
   }
   ```

4. **Option C: Refactor DayPrayerTimes to cache PrayerTime instances:**
   ```swift
   struct DayPrayerTimes {
       let fajr: Date
       // ... other times ...
       
       private let _prayerCache: [PrayerTime] = [] // Cache computed once
       
       var all: [PrayerTime] {
           if _prayerCache.isEmpty {
               _prayerCache = [
                   PrayerTime(name: "Fajr", time: fajr, icon: "sunrise", id: "fajr"),
                   // ...
               ]
           }
           return _prayerCache
       }
   }
   ```
   (Note: This requires struct mutation, so this approach is less ideal)

5. **Recommendation: Use Option B (computed property):**
   - Simplest and cleanest approach
   - No need to change initialization
   - ID is derived from the prayer name, which is stable
   - Update `PrayerTime` struct definition

6. **Update PrayerTime initialization in DayPrayerTimes.all:**
   - Remove the `id` assignment from the initializer (it's now computed)
   - Verify all usages still work

7. **Verify ForEach usage:**
   - Search for `ForEach` loops that iterate over `DayPrayerTimes.all` or similar
   - Ensure they use `PrayerTime` as the identifier (they should, since it conforms to `Identifiable`)

**Verification:**
- Build and run the app
- Navigate to a screen that displays prayer times (e.g., Prayer Times view)
- Observe prayer times list
- Perform a state update (e.g., toggle a setting, refresh data)
- Verify that prayer time rows do NOT flash/re-render unnecessarily
- Compare with a baseline: temporarily revert the fix and observe the jank, then re-apply the fix

**Dependencies:**
- May require checking all code that instantiates `PrayerTime` directly
- Verify that the ID is truly stable (using prayer name as ID is stable if prayer names don't change)

**Risk/Rollback:**
- Low risk: changes to ID generation strategy, not to functional behavior
- Rollback: revert to `let id = UUID()` approach

---

### QA-06: Replace Deprecated Map API in MasjidFinderView

**Priority:** P1 (MEDIUM)  
**Assigned Files:**
- `Revenge/Features/Masjid/MasjidFinderView.swift` (Line 57)

**Current Behavior:**
- Uses deprecated `Map(coordinateRegion:annotationItems:)` API
- This API is deprecated in iOS 17+ and will be removed in a future OS
- App will fail to compile or crash on newer iOS versions if not updated

**Target Behavior:**
- Use the modern `Map(_:)` API with `MapContentBuilder`
- App supports iOS 17+ MapKit syntax
- Code is future-proof and follows current Apple best practices

**Step-by-Step Instructions:**

1. **Identify the deprecated call (line 57):**
   ```swift
   Map(coordinateRegion: .constant(viewModel.region), annotationItems: viewModel.masjids) { masjid in
       MapAnnotation(coordinate: masjid.coordinate) {
           Image(systemName: "building.columns.fill")
       }
   }
   ```

2. **Understand the new MapKit API:**
   - iOS 17+ uses `Map(_:) { }` with a `MapContentBuilder` closure
   - Camera position is controlled with `@State private var position: MapCameraPosition`
   - Annotations are added inside the builder with `Marker` or `MapAnnotation`

3. **Replace with new API:**
   ```swift
   @State private var position: MapCameraPosition = .region(
       MKCoordinateRegion(
           center: CLLocationCoordinate2D(latitude: 21.4225, longitude: 39.8262),
           span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
       )
   )
   
   var body: some View {
       Map(position: $position) {
           ForEach(viewModel.masjids) { masjid in
               Marker("", coordinate: masjid.coordinate) {
                   Image(systemName: "building.columns.fill")
                       .foregroundStyle(Color.adaptivePrimary(colorScheme))
               }
           }
       }
   }
   ```

4. **Update ViewModel to publish camera position instead of region:**
   - Change `@Published var region: MKCoordinateRegion` to `@Published var position: MapCameraPosition`
   - Update all code that modifies `region` to modify `position` instead

5. **Handle region updates from user interaction:**
   - The old API used `.constant(viewModel.region)` for read-only map
   - The new API uses `$position` binding for interactive map
   - If the map should update when `viewModel.region` changes, bind to the position

6. **Test on iOS 17+ devices/simulators:**
   - Build and run on iPhone 16 Pro simulator (iOS 18)
   - Verify map displays correctly
   - Verify annotations appear at correct coordinates
   - Verify tapping annotation shows masjid detail sheet (line 43)

7. **Check Xcode deprecation warnings:**
   - After applying changes, Xcode should no longer show deprecation warnings for Map
   - Build with strict warnings enabled to catch any remaining issues

**Verification:**
- Xcode compilation: no deprecation warnings for MapKit
- Runtime: map displays masjids correctly
- User interaction: tapping a masjid annotation opens the detail sheet
- Test on multiple iOS versions if available (iOS 17, 18)

**Dependencies:**
- Requires iOS 17+ target (check project deployment target)
- May require updating `MasjidFinderViewModel` to use `MapCameraPosition` instead of `MKCoordinateRegion`

**Risk/Rollback:**
- Low risk: API replacement is straightforward
- If the new API doesn't work as expected, revert and check MapKit documentation for the correct syntax
- Rollback: revert to deprecated `Map(coordinateRegion:)` and handle deprecation warning

---

### QA-07: Remove Duplicate selectedMasjid State

**Priority:** P1 (MEDIUM)  
**Assigned Files:**
- `Revenge/Features/Masjid/MasjidFinderViewModel.swift` (Line 13)
- `Revenge/Features/Masjid/MasjidFinderView.swift` (Line 7)

**Current Behavior:**
- `selectedMasjid` is declared in both places:
  - ViewModel: `@Published var selectedMasjid: MasjidItem?` (line 13)
  - View: `@State private var selectedMasjid: MasjidItem?` (line 7)
- Only the View's `@State` version is used (line 43: `sheet(item: $selectedMasjid)`)
- ViewModel's `@Published` version is never accessed — dead code

**Target Behavior:**
- Single source of truth for `selectedMasjid` state
- Remove dead property from ViewModel
- View uses its own `@State` or binds to ViewModel's published property (choose one pattern)

**Step-by-Step Instructions:**

1. **Verify which version is actually used:**
   - Search for references to `selectedMasjid` in both files
   - In View: `sheet(item: $selectedMasjid)` on line 43 — uses View's @State
   - In View: `selectedMasjid = masjid` on lines 43, 80 — uses View's @State
   - In ViewModel: Check if any code references `self.selectedMasjid` — likely none

2. **Option A: Remove from ViewModel (simplest):**
   - Delete line 13 from MasjidFinderViewModel: `@Published var selectedMasjid: MasjidItem?`
   - Keep View's `@State private var selectedMasjid: MasjidItem?`
   - This is acceptable because selection is a transient UI state (not persisted)

3. **Option B: Move to ViewModel (MVVM purist approach):**
   - Remove line 7 from MasjidFinderView: `@State private var selectedMasjid: MasjidItem?`
   - Use ViewModel's `@Published var selectedMasjid: MasjidItem?`
   - Update View: `sheet(item: $viewModel.selectedMasjid)`
   - This is more MVVM-compliant but requires coordination between View and ViewModel

4. **Recommendation: Use Option A (remove from ViewModel):**
   - Selection is ephemeral UI state (clearing when sheet dismisses)
   - View-level state is appropriate for this use case
   - Simpler code, fewer dependencies

5. **Update MasjidFinderViewModel:**
   - Delete line 13
   - Verify no other code in the ViewModel references `selectedMasjid`
   - Run tests to ensure nothing breaks

6. **Alternatively, if choosing Option B:**
   - Update MasjidFinderView line 43 to: `sheet(item: $viewModel.selectedMasjid)`
   - Update MasjidFinderView lines 65, 80 to use `viewModel.selectedMasjid = masjid`
   - Delete line 7 from MasjidFinderView

**Verification:**
- Build and run MasjidFinder feature
- Tap on a masjid on the map — detail sheet opens
- Tap on a masjid in the list — detail sheet opens
- Dismiss the sheet — sheet closes and selectedMasjid is cleared
- Xcode shows no compiler warnings about unused properties

**Dependencies:**
- None for Option A (remove from ViewModel)
- If choosing Option B, requires updating all references in View

**Risk/Rollback:**
- Low risk: this is cleanup only, no functional changes
- Rollback: re-add the deleted property and use original pattern

---

### QA-08: Remove Dead isNavigating Variable in RoutineCardView

**Priority:** P1 (MEDIUM)  
**Assigned Files:**
- `Revenge/Features/Home/RoutineCardView.swift` (Line 18)

**Current Behavior:**
- `@State private var isNavigating = false` is declared on line 18
- This variable is never read or written anywhere in the view
- It's likely leftover from a previous implementation that used manual navigation
- Current implementation uses `NavigationLink` for automatic handling (line 20)

**Target Behavior:**
- Dead code removed
- View code is cleaner and easier to maintain
- No unused state variables

**Step-by-Step Instructions:**

1. **Locate the dead variable (line 18):**
   ```swift
   @State private var isNavigating = false
   ```

2. **Verify it's not used anywhere in the file:**
   - Search for `isNavigating` in the entire RoutineCardView.swift file
   - Should find exactly 1 match (the declaration)
   - No assignments or reads anywhere else

3. **Verify the view uses NavigationLink correctly (line 20):**
   ```swift
   NavigationLink(destination: RoutineView(routineType: routineType)) {
       // ... button content ...
   }
   ```
   - This pattern handles navigation automatically without explicit state

4. **Delete the line:**
   ```swift
   // Remove this line:
   // @State private var isNavigating = false
   ```

5. **Verify no compilation errors after removal:**
   - Build the app
   - Navigate to Home tab and tap on the routine card
   - Verify navigation to RoutineView works correctly

**Verification:**
- Build succeeds with no warnings
- Routine card is visible on Home screen
- Tapping routine card navigates to RoutineView
- No VoiceOver issues or accessibility regressions

**Dependencies:**
- None

**Risk/Rollback:**
- Minimal risk: purely removing dead code
- Rollback: re-add the line if navigation breaks

---

### QA-09: Add Input Validation for Manual City Geocoding

**Priority:** P1 (MEDIUM)  
**Assigned Files:**
- `Revenge/Features/Qibla/QiblaViewModel.swift` (Lines 66–72)

**Current Behavior:**
- `searchCity()` function takes `manualCity` string input
- Passes directly to `CLGeocoder` without validation
- No sanitization of input (spaces, special characters, etc.)
- No loading state shown to user while geocoding
- No error state if geocoding fails
- VoiceOver users have no feedback about the operation status

**Target Behavior:**
- Input is validated before geocoding (non-empty, length limits, character whitelist)
- User sees loading indicator while geocoding is in progress
- User sees error message if geocoding fails
- User sees success feedback if geocoding succeeds
- Accessibility users hear state announcements

**Step-by-Step Instructions:**

1. **Add validation state to ViewModel:**
   ```swift
   @Published var isGeocodingCity = false
   @Published var geocodingError: String?
   @Published var geocodingSuccess = false
   ```

2. **Update `searchCity()` to validate input:**
   ```swift
   func searchCity() {
       // Trim whitespace
       let trimmed = manualCity.trimmingCharacters(in: .whitespaces)
       
       // Validate input
       guard !trimmed.isEmpty else {
           geocodingError = "City name cannot be empty"
           return
       }
       
       guard trimmed.count <= 100 else {
           geocodingError = "City name is too long"
           return
       }
       
       // Optional: check for valid characters (alphanumeric, spaces, hyphens)
       let allowedCharacters = CharacterSet.alphanumerics
           .union(CharacterSet(charactersIn: " -"))
       guard trimmed.rangeOfCharacter(from: allowedCharacters.inverted) == nil else {
           geocodingError = "City name contains invalid characters"
           return
       }
       
       // Proceed with geocoding
       performGeocoding(trimmed)
   }
   
   private func performGeocoding(_ cityName: String) {
       isGeocodingCity = true
       geocodingError = nil
       geocodingSuccess = false
       
       Task {
           if let coord = await locationService.geocodeCity(cityName) {
               updateBearing(from: coord)
               geocodingSuccess = true
               isGeocodingCity = false
           } else {
               geocodingError = "Could not find coordinates for \(cityName)"
               isGeocodingCity = false
           }
       }
   }
   ```

3. **Update the View to show loading/error states:**
   - When `isGeocodingCity` is true, show a ProgressView or disable the search button
   - When `geocodingError` is not nil, show an error message
   - Add `.accessibilityLabel()` and `.accessibilityHint()` for the error/loading states

4. **Add timeout handling:**
   - If geocoding takes longer than 10 seconds, show a timeout error
   - Use `Task` with timeout: `try Task.sleep(nanoseconds: 10_000_000_000)`

5. **Add accessibility announcements:**
   ```swift
   .accessibilityLiveRegion(.polite) // Announce errors/success to VoiceOver
   .accessibilityLabel(isGeocodingCity ? "Searching for city..." : "Search")
   ```

**Verification:**
- Build and run Qibla view
- Enter empty city name, tap search — error message "City name cannot be empty" appears
- Enter valid city name (e.g., "Mecca"), tap search — loading indicator appears, then qibla updates
- Enter invalid city name (e.g., "XYZ123"), tap search — error message appears after timeout
- Enable VoiceOver and repeat — errors/success are announced

**Dependencies:**
- May require updating QiblaView to display the new loading/error states
- Requires updating `locationService.geocodeCity()` to return appropriate error info

**Risk/Rollback:**
- Low-medium risk: adds new state and error handling
- Rollback: revert to simple direct geocoding without validation

---

### QA-10: Replace print() Statements with os.Logger

**Priority:** P2 (LOW)  
**Assigned Files:**
- `HomeViewModel.swift`
- `CacheManager.swift`
- `SurahListViewModel.swift`
- `AudioPlayerService.swift`
- `PrayerTimesService.swift`
- `NotificationService.swift`
- `MasjidFinderViewModel.swift`
- `LocationService.swift`
(~15 locations total)

**Current Behavior:**
- Multiple `print()` statements used for error logging and debugging
- Output is visible only in Xcode console during development
- Completely invisible in production (released app)
- No structured logging format
- No log levels (error, warning, info, debug)
- Difficult to troubleshoot production issues

**Target Behavior:**
- Structured logging using `os.Logger`
- Log levels: error, warning, info, debug
- Visible in Console.app on device or in Xcode
- Persisted in device system logs for debugging production issues
- Searchable and filterable by log category/subsystem

**Step-by-Step Instructions:**

1. **Understand os.Logger API:**
   ```swift
   import os
   
   let logger = Logger(subsystem: "com.kheir.app", category: "ViewModels")
   logger.error("Error loading ayah: \(error)")
   logger.warning("Slow network detected")
   logger.info("User bookmarked ayah \(id)")
   logger.debug("API response: \(data)")
   ```

2. **Create a logger instance in each file:**
   - Add `import os` at the top
   - Create a file-level logger: `private let logger = Logger(subsystem: "com.kheir.app", category: "FileName")`

3. **Replace each `print()` statement:**
   - Search for `print(` in each file
   - Determine the severity: error, warning, info, or debug
   - Replace with appropriate logger call:
     ```swift
     // Before:
     print("Error: \(error)")
     
     // After:
     logger.error("Error loading data: \(error)")
     ```

4. **Categorize log statements by file/feature:**
   - Use consistent subsystem: `"com.kheir.app"`
   - Use distinct categories: `"HomeViewModel"`, `"CacheManager"`, `"APIService"`, etc.
   - This allows filtering logs by feature in Console.app

5. **Remove or downgrade verbose debug logs:**
   - Use `logger.debug()` for verbose output (not shown by default in production)
   - Use `logger.info()` for noteworthy events (user actions, state changes)
   - Use `logger.warning()` for potential issues
   - Use `logger.error()` for actual errors

6. **Example replacements:**
   ```swift
   // HomeViewModel.swift
   private let logger = Logger(subsystem: "com.kheir.app", category: "HomeViewModel")
   
   // Replace:
   print("Daily ayah loaded")
   // With:
   logger.info("Daily ayah loaded")
   
   // Replace:
   print("Error fetching hadith: \(error)")
   // With:
   logger.error("Error fetching hadith: \(error)")
   ```

7. **Test logging on a real device:**
   - Build and run on an iPhone
   - Open Console.app on Mac while device is connected
   - Search for logs with subsystem "com.kheir.app"
   - Verify logs appear with correct levels and messages

**Verification:**
- All `print()` statements are replaced with `logger.*()` calls
- Xcode shows no compiler warnings about `print` being called
- Logs appear in Console.app when app runs on device
- Logs are properly categorized and filtered in Console.app

**Dependencies:**
- Requires `import os` in each file
- No runtime dependencies

**Risk/Rollback:**
- Low risk: additive changes, no functional logic change
- Rollback: revert to `print()` statements

---

### QA-11: Add reduceMotion Check to ScrollRevealModifier

**Priority:** P2 (LOW)  
**Assigned Files:**
- `Revenge/Core/Extensions/View+Extensions.swift` (Lines 4–19)

**Current Behavior:**
- `ScrollRevealModifier` applies animation and offset effects unconditionally
- Does not check `Environment(\.accessibilityReduceMotion)` 
- Users with "Reduce Motion" accessibility setting enabled see animations anyway
- This violates WCAG 2.1 Animation from Interactions guideline
- Can cause discomfort or motion sickness for sensitive users

**Target Behavior:**
- `ScrollRevealModifier` checks `reduceMotion` environment variable
- When `reduceMotion = true`, animations are disabled
- Elements appear without animation/offset when motion reduction is enabled
- Accessibility compliant

**Step-by-Step Instructions:**

1. **Understand the current modifier (lines 4–19):**
   ```swift
   struct ScrollRevealModifier: ViewModifier {
       let delay: Double
       @State private var hasAppeared = false
       
       func body(content: Content) -> some View {
           content
               .opacity(hasAppeared ? 1 : 0)
               .offset(y: hasAppeared ? 0 : 20)
               .animation(.easeOut(duration: 0.45).delay(delay), value: hasAppeared)
               .onAppear {
                   if !hasAppeared {
                       hasAppeared = true
                   }
               }
       }
   }
   ```

2. **Add reduceMotion environment variable:**
   ```swift
   struct ScrollRevealModifier: ViewModifier {
       let delay: Double
       @State private var hasAppeared = false
       @Environment(\.accessibilityReduceMotion) private var reduceMotion
       
       func body(content: Content) -> some View {
           content
               .opacity(hasAppeared ? 1 : 0)
               .offset(y: hasAppeared && !reduceMotion ? 0 : 20)
               .animation(
                   reduceMotion ? nil : .easeOut(duration: 0.45).delay(delay),
                   value: hasAppeared
               )
               .onAppear {
                   if !hasAppeared {
                       hasAppeared = true
                   }
               }
       }
   }
   ```

3. **Explanation of changes:**
   - `.opacity(hasAppeared ? 1 : 0)` — keeps opacity animation (subtle, usually safe)
   - `.offset(y: hasAppeared && !reduceMotion ? 0 : 20)` — only offset if NOT reducing motion
   - `.animation(reduceMotion ? nil : ...)` — disable animation if reducing motion
   - When `reduceMotion = true`, animation is `nil` (no animation), and offset is always 0 (no movement)

4. **Test with Reduce Motion enabled:**
   - Open Settings > Accessibility > Motion > Reduce Motion
   - Toggle "Reduce Motion" ON
   - Build and run the app
   - Navigate to Home screen
   - Observe elements appear without slide-in animation
   - Verify content is still visible and readable

5. **Test with Reduce Motion disabled:**
   - Toggle "Reduce Motion" OFF in Settings
   - Build and run the app
   - Verify elements animate smoothly on Home screen

**Verification:**
- Build and run on simulator with Reduce Motion ON
- Home screen elements load without animation or offset
- Build and run on simulator with Reduce Motion OFF
- Home screen elements animate smoothly
- All accessibility tests pass

**Dependencies:**
- None (uses standard SwiftUI environment variable)

**Risk/Rollback:**
- Low risk: purely accessibility enhancement
- Rollback: revert to unconditional animation

---

### QA-12: Refactor shareAyah UIKit Presentation

**Priority:** P2 (LOW)  
**Assigned Files:**
- `Revenge/Features/Quran/ReadingView.swift` (Lines 337–355)

**Current Behavior:**
- `shareAyah()` function uses UIKit imperative presentation:
  - Traverses view hierarchy: `UIApplication.shared.connectedScenes` → `windows.first?.rootViewController`
  - Manually finds topmost controller by walking presented hierarchy
  - Manually configures `popoverPresentationController` for iPad
- This approach is fragile and breaks on:
  - iPad with multiple windows
  - Adaptive layouts with multiple presentation contexts
  - Custom view hierarchies or third-party view controllers

**Target Behavior:**
- Use SwiftUI-native `.sheet()` or `.popover()` modifier
- Share presentation handled by SwiftUI's presentation engine
- Works correctly on all device sizes and orientations

**Step-by-Step Instructions:**

1. **Understand current implementation (lines 337–355):**
   ```swift
   private func shareAyah(_ ayah: DisplayAyah) {
       let text = viewModel.shareText(for: ayah)
       let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
       if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let rootVC = windowScene.windows.first?.rootViewController {
           var topVC = rootVC
           while let presented = topVC.presentedViewController {
               topVC = presented
           }
           if let popover = activityVC.popoverPresentationController {
               popover.sourceView = topVC.view
               popover.sourceRect = CGRect(x: topVC.view.bounds.midX, y: topVC.view.bounds.midY, width: 0, height: 0)
               popover.permittedArrowDirections = []
           }
           topVC.present(activityVC, animated: true)
       }
   }
   ```

2. **Create a wrapper struct for UIActivityViewController:**
   ```swift
   struct ShareSheet: UIViewControllerRepresentable {
       let text: String
       @Environment(\.dismiss) var dismiss
       
       func makeUIViewController(context: Context) -> UIActivityViewController {
           let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
           return activityVC
       }
       
       func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
   }
   ```

3. **Add state for share presentation:**
   ```swift
   @State private var showShareSheet = false
   @State private var shareAyahForShare: DisplayAyah?
   ```

4. **Update the View body to add sheet modifier:**
   ```swift
   .sheet(item: $shareAyahForShare) { ayah in
       ShareSheet(text: viewModel.shareText(for: ayah))
   }
   ```

5. **Simplify shareAyah() to just set state:**
   ```swift
   private func shareAyah(_ ayah: DisplayAyah) {
       shareAyahForShare = ayah
   }
   ```

6. **Test on multiple devices:**
   - iPhone: verify share sheet slides up from bottom
   - iPad: verify share sheet appears as popover (if SwiftUI is configured to do so)
   - Test both portrait and landscape

7. **Alternative: Use UIActivityViewController directly with .sheet():**
   - iOS 16+ allows `UIActivityViewController` in SwiftUI sheets more easily
   - Check if the existing approach can be replaced with a simpler `.sheet()` call

**Verification:**
- Build and run on iPhone — share sheet appears correctly
- Build and run on iPad — popover appears (or sheet, depending on SwiftUI configuration)
- Test on multiple orientations
- Xcode shows no warnings about deprecated UIKit patterns

**Dependencies:**
- May require creating a `ShareSheet` wrapper struct (UIViewControllerRepresentable)
- Requires updating ReadingView state management

**Risk/Rollback:**
- Medium risk: replacing UIKit presentation with SwiftUI
- If the new approach doesn't work on iPad, revert to UIKit
- Alternative: use a third-party ShareSheet wrapper library

---

### QA-13: Replace DispatchQueue.main.asyncAfter with Task.sleep

**Priority:** P2 (LOW)  
**Assigned Files:**
- `Revenge/Features/Quran/ReadingView.swift` (Lines 44, 328)
- `Revenge/Features/Home/StreakCardView.swift` (Line 118)

**Current Behavior:**
- Uses `DispatchQueue.main.asyncAfter(deadline: .now() + X)` for delayed execution
- This is a legacy pattern from before Swift Concurrency
- Mixes async/await with DispatchQueue, making code harder to follow
- Potential issues with task cancellation and cleanup

**Target Behavior:**
- Use `Task.sleep(nanoseconds:)` with Swift Concurrency
- Cleaner, more idiomatic Swift code
- Better integration with structured concurrency
- Proper task cancellation support

**Step-by-Step Instructions:**

1. **Locate the DispatchQueue calls:**
   - Line 44 in ReadingView.swift: scroll-to-ayah delay
   - Line 328 in ReadingView.swift: copy feedback delay
   - Line 118 in StreakCardView.swift: animation delay

2. **Understand Task.sleep:**
   ```swift
   // Old way (DispatchQueue):
   DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
       proxy.scrollTo(scrollTo, anchor: .top)
   }
   
   // New way (Task.sleep):
   Task {
       try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds in nanoseconds
       proxy.scrollTo(scrollTo, anchor: .top)
   }
   ```

3. **Convert nanoseconds (1 second = 1,000,000,000 nanoseconds):**
   ```swift
   0.5 seconds = 500,000,000 ns
   2 seconds = 2,000,000,000 ns
   ```

4. **Update ReadingView line 44:**
   ```swift
   // Before:
   DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
       withAnimation(reduceMotion ? .none : .easeOut(duration: 0.4)) {
           proxy.scrollTo(scrollTo, anchor: .top)
       }
   }
   
   // After:
   Task {
       try await Task.sleep(nanoseconds: 500_000_000)
       withAnimation(reduceMotion ? .none : .easeOut(duration: 0.4)) {
           proxy.scrollTo(scrollTo, anchor: .top)
       }
   }
   ```

5. **Update ReadingView line 328 (copy feedback):**
   ```swift
   // Before:
   DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
       withAnimation {
           if copiedAyahID == ayah.id {
               copiedAyahID = nil
           }
       }
   }
   
   // After:
   Task {
       try await Task.sleep(nanoseconds: 2_000_000_000)
       withAnimation {
           if copiedAyahID == ayah.id {
               copiedAyahID = nil
           }
       }
   }
   ```

6. **Update StreakCardView line 118:**
   - Follow the same pattern as above
   - Replace `DispatchQueue.main.asyncAfter` with `Task { try await Task.sleep(...) }`

7. **Handle potential errors:**
   - `Task.sleep()` can throw `CancellationError`
   - Wrap in `do-catch` or use `try?` if cancellation should be silent:
   ```swift
   Task {
       try? await Task.sleep(nanoseconds: 500_000_000)
       // Code here might not run if task is cancelled
   }
   ```

8. **Test that delays still work:**
   - Scroll to ayah: verify delay before scroll happens
   - Copy feedback: verify 2-second timeout before checkmark disappears
   - Streak animation: verify animation delay is respected

**Verification:**
- Build and run on iPhone
- Navigate to Quran section and scroll to ayah — scroll delay works correctly
- Copy an ayah — checkmark appears for ~2 seconds then disappears
- All animations and delays function as expected
- No compiler warnings about DispatchQueue usage

**Dependencies:**
- Requires Swift 5.9+ (Task.sleep is available in Swift Concurrency)
- No other dependencies

**Risk/Rollback:**
- Low risk: Task.sleep is a drop-in replacement for DispatchQueue.main.asyncAfter
- Rollback: revert to DispatchQueue calls if issues arise

---

## Execution Timeline

### Phase 1: Critical Fixes (Week 1)
- **QA-01** — Fix 4 failing UI tests (2-3 days)
- **QA-02** — Fix CacheManagerTests flaky shared state (1-2 days)
- **QA-03** — Fix MockAPIService @unchecked Sendable (1 day)

### Phase 2: Accessibility & Code Quality (Week 2)
- **QA-04** — Add accessibility labels to HomeView (1 day)
- **QA-05** — Fix PrayerTime.id stability (1 day)
- **QA-06** — Replace deprecated Map API (1-2 days)
- **QA-07** — Remove duplicate selectedMasjid state (0.5 day)
- **QA-08** — Remove dead isNavigating variable (0.5 day)

### Phase 3: Input Validation & Logging (Week 3)
- **QA-09** — Add input validation for city geocoding (1 day)
- **QA-10** — Replace print() with os.Logger (~15 occurrences, 1-2 days)

### Phase 4: Polish & Optimization (Week 4)
- **QA-11** — Add reduceMotion to ScrollRevealModifier (0.5 day)
- **QA-12** — Refactor shareAyah UIKit presentation (1 day)
- **QA-13** — Replace DispatchQueue.main.asyncAfter with Task.sleep (0.5 day)

### Estimated Total
- **18 person-days** (3-4 weeks with 1 engineer)
- Parallelizable tasks can be split across team members

---

## Success Metrics

- [ ] All 7 UI tests pass consistently (10 consecutive runs without failure)
- [ ] CacheManager tests pass in any execution order (5 randomized runs)
- [ ] MockAPIService compiles with Swift 6 strict concurrency enabled
- [ ] VoiceOver users can operate all interactive elements in HomeView
- [ ] Prayer times list does not re-render unnecessarily on state changes
- [ ] MasjidFinderView compiles without deprecation warnings
- [ ] No unused properties in codebase (linter check)
- [ ] All logging uses `os.Logger` (no `print()` calls in production code)
- [ ] ScrollRevealModifier respects accessibility reduce motion setting
- [ ] All async delays use `Task.sleep` instead of DispatchQueue

---

## Questions for Engineering Team

1. **QA-02:** Is `CacheManager` designed to be used as a singleton only, or can it be instantiated for testing?
2. **QA-03:** Should we use NSLock, @MainActor, or Actor pattern for MockAPIService? (Recommended: NSLock for minimal test changes)
3. **QA-06:** What is the minimum iOS deployment target? (Need to know if iOS 17+ MapKit API is acceptable)
4. **QA-07:** Should `selectedMasjid` be a ViewModel property (MVVM) or View property (simplicity)? (Recommended: View property)
5. **QA-09:** Does `LocationService.geocodeCity()` currently return nil on failure, or throw an error?
6. **QA-12:** Are we open to adding a `ShareSheet` SwiftUI wrapper, or prefer staying with UIKit?

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-04-26 | QA/Accessibility Team | Initial plan created |

---

**Next Steps:**
1. Engineering team reviews plan and asks clarifying questions
2. Team assigns tasks and estimates effort
3. Implementation begins with Phase 1 (critical fixes)
4. Daily standups to track progress and blockers
5. Weekly verification of success metrics
6. Plan adjustments based on findings during implementation

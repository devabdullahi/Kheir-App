# Implementation Plan: Concurrency & Thread Safety

## Department Overview

This plan addresses critical concurrency and thread-safety issues identified by a comprehensive audit of the Kheir (Revenge) codebase. The primary goals are to:

1. **Eliminate data races** in shared mutable state (CacheManager, AppSettings)
2. **Fix main-thread violations** from background callbacks (LocationService, NotificationService)
3. **Ensure Sendable conformance** across service layer and model layer for strict concurrency checking
4. **Maintain backward compatibility** with production code while improving internal safety guarantees

These fixes are essential for app stability, preventing silent data loss (bookmarks, journal entries), and supporting future Swift concurrency features (strict mode, distributed actors).

---

## Priority Order

### Execution Dependency Graph

```
CS-01 (CacheManager Actor)
├── Blocks: CS-02 (CacheManager Protocol)
└── Blocks: CS-06 (AppSettings @MainActor)

CS-02 (CacheManager Protocol)
├── Blocks: CS-07 (Model Sendable)
└── Follows: CS-01

CS-03 (LocationService @MainActor)
├── Independent
└── Precedes: CS-08 (Integration Tests)

CS-04 (PrayerTimesService Sendable)
├── Independent
└── Precedes: CS-08

CS-05 (NotificationService Sendable)
├── Independent
└── Precedes: CS-08

CS-06 (AppSettings @MainActor)
├── Follows: CS-01 (to avoid protocol conflicts)
└── Precedes: CS-08

CS-07 (Model Structs Sendable)
├── Follows: CS-02
└── Precedes: CS-08

CS-08 (Integration & Concurrency Tests)
├── Depends on: CS-01, CS-02, CS-03, CS-04, CS-05, CS-06, CS-07
└── Final validation task
```

### Suggested Sprint Schedule

**Sprint 1 (Days 1–3):** Foundation
- CS-01: CacheManager Actor conversion
- CS-02: CacheManager Protocol update
- CS-03: LocationService @MainActor annotation

**Sprint 2 (Days 4–5):** Service Layer Isolation
- CS-04: PrayerTimesService Sendable
- CS-05: NotificationService Sendable
- CS-06: AppSettings @MainActor

**Sprint 3 (Day 6):** Model Layer & Verification
- CS-07: Model Structs Sendable conformance
- CS-08: Integration & concurrency tests

---

## Task Breakdown

### CS-01: Convert CacheManager to Actor

**Priority:** P0 (Critical — blocks all bookmark/journal operations)

**Assigned Files:**
- `Revenge/Core/Services/CacheManager.swift`

**Current Behavior:**

The `CacheManager` is declared as a `final class` (line 19). While it uses a serial DispatchQueue (`ioQueue`) for disk I/O synchronization, the read-modify-write cycles in bookmark and journal mutation methods are **not atomic** with respect to concurrent callers:

```swift
// Lines 300–305 (saveAyahBookmark)
func saveAyahBookmark(_ bookmark: BookmarkedAyah) {
    var bookmarks = loadAyahBookmarks()  // Read
    bookmarks.insert(bookmark, at: 0)   // Modify
    save(bookmarks, filename: ayahBookmarksFile)  // Write (async!)
}
```

If two ViewModels call `saveAyahBookmark` simultaneously on different threads (e.g., HomeViewModel on MainActor, BookmarksViewModel on MainActor during a background task), both will execute `loadAyahBookmarks()` before either `save()` completes. The second save will overwrite the first, losing one bookmark.

Similarly, `removeAyahBookmark`, `updateJournalEntry`, and all other mutation methods share this vulnerability. The memory cache update (line 158) happens synchronously, but the disk write is async, creating a window for interleaved mutations.

**Target Behavior:**

Convert `CacheManager` to a Swift `actor`. All read/modify/write cycles will be serialized by the actor's isolation guarantee:

- **Synchronous caller becomes async:** Functions that were synchronous (e.g., `loadAyahBookmarks()`) become `async`.
- **Isolation guarantees atomicity:** No two mutation calls can interleave. The actor's implicit executor ensures serial access to all mutable state.
- **ioQueue replaced by actor executor:** The DispatchQueue becomes redundant; the actor's default global concurrent executor handles I/O.
- **MainActor compatibility:** ViewModels on `@MainActor` can `await` the actor's methods without deadlock because actors use a thread-pool executor, not the main thread.

**Step-by-Step Instructions:**

1. **Change class declaration to actor** (line 19):
   - Replace `final class CacheManager` with `actor CacheManager`

2. **Remove DispatchQueue ioQueue** (lines 44, 162, 208):
   - Delete the `private let ioQueue = DispatchQueue(label: "com.kheir.cache.io", qos: .utility)` declaration
   - Do NOT remove any `.async` or `.sync` calls yet — they will be handled in the next steps

3. **Make all public methods async**:
   - All `func load*()`, `func save*()`, `func remove*()`, `func delete()`, and similar methods must add `async` to their signature
   - Return type stays the same; only the calling convention changes
   - Examples:
     - `func loadAyahBookmarks() -> [BookmarkedAyah]` becomes `func loadAyahBookmarks() async -> [BookmarkedAyah]`
     - `func saveAyahBookmark(_ bookmark: BookmarkedAyah)` becomes `func saveAyahBookmark(_ bookmark: BookmarkedAyah) async`
   - Methods returning `Bool` (e.g., `isAyahBookmarked`) also become `async` to maintain consistency

4. **Replace ioQueue dispatch with direct execution**:
   - Line 162: Remove the `ioQueue.async` wrapper around the disk write in `save()`:
     ```swift
     // OLD: ioQueue.async { [weak self] in
     //         guard self != nil else { return }
     //         try data.write(to: url, options: .atomic)
     //     }
     // NEW:
     let url = cacheDirectory.appendingPathComponent(filename)
     do {
         try data.write(to: url, options: .atomic)
     } catch {
         print("CacheManager: disk write error for '\(filename)': \(error)")
     }
     ```
   - Line 208: Remove the `ioQueue.async` wrapper around the delete in `delete()`:
     ```swift
     // OLD: ioQueue.async { [weak self] in
     //         try? self?.fileManager.removeItem(at: url)
     //     }
     // NEW:
     try? fileManager.removeItem(at: url)
     ```
   - Line 182: Remove the `ioQueue.sync` wrapper in `load()`:
     ```swift
     // OLD: return ioQueue.sync { [self] in
     //         if let box = memoryCache.object(forKey: filename as NSString) { ... }
     //         ...
     //     }
     // NEW: (inline without dispatch)
     // Double-check after acquiring queue — another thread may have warmed the cache.
     if let box = memoryCache.object(forKey: filename as NSString) {
         return try? JSONDecoder().decode(type, from: box.data)
     }
     ...
     ```

5. **Update `migrateToAppGroupIfNeeded()`**:
   - This method is called from `init()` and must remain synchronous (init cannot be async)
   - Remove any await calls and ensure it runs synchronously at actor initialization
   - The design comment at lines 5–17 should be updated to reflect actor isolation instead of DispatchQueue semantics

6. **Update design comments** (lines 5–17):
   - Replace the DispatchQueue explanation with actor-based explanation
   - Note that methods are now async and serialize automatically
   - Explain that NSCache.setObject remains thread-safe for concurrent access, and the actor ensures no data races on the in-memory layer

**Verification:**

1. **Compilation:**
   - The project should compile without errors. The Swift compiler will enforce that callers use `await` with async methods.

2. **Behavior test:**
   - Write a unit test (or manual script) that:
     - Starts two concurrent tasks calling `saveAyahBookmark` with different bookmarks
     - Waits for both tasks to complete
     - Calls `loadAyahBookmarks()` and verifies **both** bookmarks are present, in the correct order (newest first)
     - Verify the test fails under the old class-based implementation and passes under the actor

3. **Memory integrity:**
   - Use Instruments (Xcode Memory Debugger) to verify no dangling references or premature deallocations of `CacheManager` singleton

4. **Performance check:**
   - Measure `await loadAyahBookmarks()` latency in a cache-hit scenario (data already in NSCache)
   - Should be under 1ms on modern iOS devices

**Dependencies:**

- None (this is foundational)

**Risk & Rollback:**

- **Risk:** All callers of CacheManager become async-required. ViewModels and other call sites must use `Task { await ... }` or be themselves async.
- **Rollback:** If severe blocking issues arise, revert to `final class` and keep the DispatchQueue, but acknowledge that data races will persist.
- **Mitigation:** Review CS-02 (CacheManager Protocol) and ensure all protocol conformances are updated in lockstep. Delay wider rollout until integration testing confirms MainActor compatibility.

---

### CS-02: Update CacheManaging Protocol

**Priority:** P0 (Follows CS-01)

**Assigned Files:**
- `Revenge/Core/Services/ServiceProtocols.swift`

**Current Behavior:**

The `CacheManaging` protocol (lines 29–60) declares all methods as synchronous. Once CacheManager becomes an actor, the protocol must reflect async semantics.

The TODO at line 31 acknowledges the race condition that CS-01 will fix.

**Target Behavior:**

Update all method signatures in the protocol to `async`. The protocol remains `AnyObject` (not actor-scoped) so that non-actor mocks (used in tests) can conform to it.

**Step-by-Step Instructions:**

1. **Update all protocol method signatures to async**:
   - Every function declaration in the `CacheManaging` protocol must add `async`
   - Examples:
     ```swift
     // OLD:
     func cacheDailyAyah(_ ayah: DailyAyah)
     func loadDailyAyah(for date: String) -> DailyAyah?
     func isAyahBookmarked(surah: Int, ayah: Int) -> Bool
     
     // NEW:
     func cacheDailyAyah(_ ayah: DailyAyah) async
     func loadDailyAyah(for date: String) async -> DailyAyah?
     func isAyahBookmarked(surah: Int, ayah: Int) async -> Bool
     ```
   - Apply this to all 21 methods in the protocol

2. **Remove or update the TODO** (line 30–31):
   - Replace:
     ```swift
     /// NOTE: CacheManager is intentionally NOT an actor for now.
     /// TODO(phase2): race when Home + Bookmarks mutate concurrently; convert to actor with widget App Group work
     ```
   - With:
     ```swift
     /// NOTE: All methods are now async to ensure atomicity of read-modify-write cycles
     /// and prevent data races on concurrent bookmark/journal mutations.
     ```

3. **Update CacheManager conformance** (line 102):
   - The conformance statement `extension CacheManager: CacheManaging {}` remains the same
   - The Swift compiler will ensure the actor's async methods match the protocol

4. **Update MockCacheManager if needed**:
   - If MockCacheManager is used in tests without actual async calls, wrap the mocked methods as:
     ```swift
     func cacheDailyAyah(_ ayah: DailyAyah) async {
         cacheDailyAyahCallCount += 1
         dailyAyahStore[ayah.dateString] = ayah
     }
     ```
   - All methods remain non-blocking (no real I/O), so they execute to completion immediately even though they're async

**Verification:**

1. **Compilation:**
   - The project should compile with updated protocol signatures

2. **Protocol conformance:**
   - Verify that `CacheManager` (actor) correctly conforms to `CacheManaging` (async protocol)
   - Verify that MockCacheManager (class) also conforms with async stubs

3. **Call site verification:**
   - Spot-check a few call sites (e.g., HomeViewModel loading daily ayahs) and confirm they use `await`

**Dependencies:**

- Depends on: CS-01 (CacheManager must be an actor first)

**Risk & Rollback:**

- **Risk:** Protocol change breaks all existing call sites; must update all ViewModels and Services that call CacheManager methods
- **Mitigation:** Search for all calls to `cacheManager.*` or `cache.*` and update them to use `await`
- **Rollback:** Revert protocol to synchronous and downgrade CacheManager back to `final class` (undoes CS-01)

---

### CS-03: Add @MainActor Isolation to LocationService

**Priority:** P1 (High)

**Assigned Files:**
- `Revenge/Core/Services/LocationService.swift`

**Current Behavior:**

`LocationService` conforms to `ObservableObject` (line 5) and publishes `@Published` properties:
- `@Published var currentLocation: CLLocationCoordinate2D?` (line 10)
- `@Published var heading: CLHeading?` (line 12)
- `@Published var authorizationStatus: CLAuthorizationStatus = .notDetermined` (line 11)
- `@Published var headingAccuracy: Double = -1` (line 13)

The `CLLocationManagerDelegate` callbacks (lines 45–63) are invoked by the CoreLocation framework on arbitrary background threads, not the main thread. When these callbacks modify the `@Published` properties (e.g., `currentLocation = locations.last?.coordinate` on line 46), they trigger `objectWillChange`, a Combine Publisher that **must** send events on the main thread.

Sending a Published event from a background thread violates SwiftUI's main-thread requirement and causes:
- Runtime warnings in the console
- Potential data races (ObservableObject is not thread-safe)
- Undefined behavior if SwiftUI observers update UI from background thread signals

**Target Behavior:**

Mark `LocationService` with `@MainActor` annotation to declare that all its mutable state and methods must be accessed from the main thread. The CLLocationManager callbacks will explicitly dispatch their state updates to the main thread.

**Step-by-Step Instructions:**

1. **Add @MainActor to class declaration** (line 5):
   - Change `final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate` to:
     ```swift
     @MainActor
     final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate
     ```

2. **Wrap delegate callback updates in DispatchQueue.main.async**:
   - `locationManager(_:didUpdateLocations:)` (lines 45–47):
     ```swift
     func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
         DispatchQueue.main.async {
             self.currentLocation = locations.last?.coordinate
         }
     }
     ```
   - `locationManager(_:didUpdateHeading:)` (lines 49–52):
     ```swift
     func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
         DispatchQueue.main.async {
             self.heading = newHeading
             self.headingAccuracy = newHeading.headingAccuracy
         }
     }
     ```
   - `locationManagerDidChangeAuthorization(_:)` (lines 54–59):
     ```swift
     func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
         DispatchQueue.main.async {
             self.authorizationStatus = manager.authorizationStatus
             if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
                 self.startUpdating()
             }
         }
     }
     ```

3. **Verify init and static shared are on main**:
   - The `override private init()` (line 15) is fine — it's called at app startup on the main thread
   - The `static let shared = LocationService()` (line 6) is also fine — runs at app init time

4. **No changes needed to public methods**:
   - `requestPermission()`, `startUpdating()`, `stopUpdating()`, `startHeadingUpdates()`, `stopHeadingUpdates()` (lines 22–42) are already called from @MainActor ViewModels
   - They remain synchronous and don't change signature

5. **Async geocoding is safe**:
   - `geocodeCity()` is already `async` (line 66) and doesn't directly modify @Published properties
   - No changes needed

**Verification:**

1. **Compilation:**
   - The project compiles with @MainActor annotation

2. **Runtime behavior:**
   - Run the app and trigger location updates (enable location permission in Settings → Kheir)
   - Observe the Xcode console — **no warnings** about "publishing changes from background thread"
   - Check that `@Published var currentLocation` updates flow smoothly to SwiftUI views

3. **Instrument test:**
   - Enable Main Thread Checker in Xcode (Product → Scheme → Edit Scheme → Diagnostics → Main Thread Checker)
   - Run the app and request location permission
   - Confirm no "Main Thread Checker" violations are reported

**Dependencies:**

- None (independent task)

**Risk & Rollback:**

- **Risk:** If a caller is not on MainActor and calls a public method, it will fail to compile. This is the desired behavior (forces callers to be MainActor-aware), but may reveal hidden bugs.
- **Mitigation:** Review all call sites and ensure they are either @MainActor or use `Task { @MainActor in ... }`
- **Rollback:** Remove @MainActor annotation and revert the DispatchQueue.main.async wrappers

---

### CS-04: Add Sendable Conformance to PrayerTimesService

**Priority:** P1 (High)

**Assigned Files:**
- `Revenge/Core/Services/PrayerTimesService.swift`

**Current Behavior:**

`PrayerTimesService` (line 19) is declared as a `final class` singleton without Sendable conformance. It is accessed from `@MainActor` ViewModels via `await` calls (e.g., in NotificationService line 64). Under strict concurrency checking, the absence of Sendable declaration is flagged as an error because the class contains mutable state (`self` in instance methods is not Sendable by default).

**Target Behavior:**

Declare `PrayerTimesService` as `@unchecked Sendable` because:
- It has no mutable state (all methods are read-only transformations; no stored properties are modified)
- All public methods are `async` and thread-safe by design
- The calculation logic is deterministic and has no side effects
- The only external dependency is `APIService.shared`, which is also Sendable

**Step-by-Step Instructions:**

1. **Add @unchecked Sendable conformance** (line 19):
   - Change `final class PrayerTimesService` to:
     ```swift
     final class PrayerTimesService: @unchecked Sendable
     ```

2. **Verify no mutable state**:
   - Scan the entire file for any `var` declarations at the class level
   - Confirm there are none (all private methods are helper functions, not stored properties)

3. **No code changes needed**:
   - All methods are already effectively pure/deterministic
   - No locking or internal synchronization needed

**Verification:**

1. **Compilation:**
   - The project compiles with Sendable conformance

2. **Strict concurrency check:**
   - Temporarily enable strict concurrency checking in build settings (Swift 5.10+) and verify no errors in this file

3. **Cross-actor call test:**
   - In a unit test or app code, call `await PrayerTimesService.shared.fetchPrayerTimes(...)` from a non-MainActor context (e.g., a background task)
   - Confirm it compiles and runs correctly

**Dependencies:**

- None (independent task)

**Risk & Rollback:**

- **Risk:** The `@unchecked Sendable` assertion bypasses the compiler's safety checks. If future code adds mutable state, it will be unsafe.
- **Mitigation:** Add a comment explaining why @unchecked is safe: "No stored mutable state; all methods are deterministic"
- **Rollback:** Remove @unchecked Sendable and fall back to non-Sendable singleton (will require callers to avoid cross-isolation calls)

---

### CS-05: Add Sendable Conformance to NotificationService

**Priority:** P1 (High)

**Assigned Files:**
- `Revenge/Core/Services/NotificationService.swift`

**Current Behavior:**

`NotificationService` (line 5) is a `final class` singleton with no Sendable conformance. It is accessed from `@MainActor` ViewModels and from other services (e.g., called from settings views). Under strict concurrency, this is flagged as unsafe.

**Target Behavior:**

Declare `NotificationService` as `@unchecked Sendable` because:
- It has no stored mutable state (all methods are stateless wrappers around UNUserNotificationCenter)
- All methods are either synchronous helpers or async functions that return Void
- Thread safety is guaranteed by the underlying UNUserNotificationCenter API

**Step-by-Step Instructions:**

1. **Add @unchecked Sendable conformance** (line 5):
   - Change `final class NotificationService` to:
     ```swift
     final class NotificationService: @unchecked Sendable
     ```

2. **Verify no mutable state**:
   - Scan for any `var` declarations at class level
   - Confirm there are none (only methods and the private init)

3. **No code changes needed**:
   - All methods are stateless helpers

**Verification:**

1. **Compilation:**
   - The project compiles

2. **API safety test:**
   - Call `NotificationService.shared.requestPermission()` from both MainActor and non-MainActor contexts in a test
   - Confirm both work correctly

3. **Strict concurrency check:**
   - Enable strict concurrency checking and verify no errors in this file

**Dependencies:**

- None (independent task)

**Risk & Rollback:**

- **Risk:** Same as CS-04 — @unchecked bypasses compiler safety
- **Mitigation:** Add explanatory comment
- **Rollback:** Remove @unchecked Sendable

---

### CS-06: Add @MainActor Isolation to AppSettings

**Priority:** P1 (High)

**Assigned Files:**
- `Revenge/Core/Models/AppSettings.swift`

**Current Behavior:**

`AppSettings` (line 5) is an `ObservableObject` class that uses `@AppStorage` for all properties (lines 8–31). While `@AppStorage` itself is thread-safe (backed by UserDefaults which is thread-safe), the `ObservableObject` protocol's `objectWillChange` publisher is **not** thread-safe.

The class is accessed from:
- `@MainActor` ViewModels (safe)
- `NotificationService` (line 18 in NotificationService.swift) on arbitrary threads (unsafe)

If a notification scheduling operation reads or writes AppSettings from a background thread, it could cause a data race on the `objectWillChange` publisher, resulting in:
- Skipped SwiftUI updates
- Corruption of the published value cache
- Potential crashes

**Target Behavior:**

Mark `AppSettings` as `@MainActor` to enforce that all access (reads and writes) happens on the main thread. Wrap any background-thread accesses with `DispatchQueue.main.async`.

**Step-by-Step Instructions:**

1. **Add @MainActor to class declaration** (line 5):
   - Change `class AppSettings: ObservableObject` to:
     ```swift
     @MainActor
     class AppSettings: ObservableObject
     ```

2. **Update NotificationService to marshal AppSettings access**:
   - In `schedulePrayerNotifications(prayers:settings:)` (line 18 in NotificationService.swift):
     - The parameter `settings: AppSettings` is passed in; no change needed here if the caller is already on MainActor
     - Reads inside the method (e.g., `settings.fajrNotification`) must happen on main thread
   - In `scheduleWeekOfNotifications(coordinate:settings:)` (line 55):
     - Same pattern — reads from `settings` must be main-thread-safe
     - The call to `PrayerTimesService` is already async; ensure AppSettings reads happen before/after this call, not during
   - Review all method calls to `settings` properties and ensure they are guarded by MainActor

3. **Search for all AppSettings.shared accesses**:
   - Use grep to find all `AppSettings.shared` usages
   - Ensure they are only called from @MainActor contexts (ViewModels) or wrapped in `DispatchQueue.main.async`

4. **No init changes needed**:
   - The `private init()` at line 37 is fine — app initialization is on main thread

**Verification:**

1. **Compilation:**
   - The project compiles with @MainActor annotation
   - All ViewModels that read AppSettings.shared are themselves @MainActor (they already should be)

2. **Runtime test:**
   - Run the app and change a setting in the UI (e.g., toggle a notification switch)
   - Confirm the change persists (AppStorage write succeeds)
   - Observe SwiftUI reactive updates immediately

3. **Notification scheduling test:**
   - Call the notification service to schedule a week of notifications
   - Monitor the console for any thread-safety warnings
   - Confirm settings are read correctly on the background task

**Dependencies:**

- Follows CS-01 (CacheManager Actor) to avoid protocol conflicts with async patterns
- Should be coordinated with CS-05 (NotificationService Sendable) to ensure NotificationService properly marshals AppSettings calls

**Risk & Rollback:**

- **Risk:** Any background thread that tries to access AppSettings.shared will fail to compile, revealing implicit non-main-thread access
- **Mitigation:** Audit all callers and wrap with `Task { @MainActor in ... }` where needed
- **Rollback:** Remove @MainActor annotation

---

### CS-07: Add Explicit Sendable Conformance to Model Structs

**Priority:** P2 (Low, but required for strict concurrency)

**Assigned Files:**
- `Revenge/Core/Models/BookmarkModels.swift`
- `Revenge/Core/Models/HadithModels.swift`
- `Revenge/Core/Models/QuranModels.swift`
- `Revenge/Core/Models/JournalModels.swift`
- `Revenge/Core/Models/StreakModels.swift`
- `Revenge/Core/Models/RoutineModels.swift`
- `Revenge/Core/Models/ShareModels.swift`
- `Revenge/Core/Models/PrayerModels.swift`

**Current Behavior:**

Value-type model structs (e.g., `DailyAyah`, `BookmarkedAyah`, `DailyHadith`) are Codable and Identifiable but do not explicitly conform to Sendable. Under strict concurrency checking, the compiler flags them as potentially unsafe when passed across isolation boundaries (e.g., from an actor to a @MainActor ViewModel).

In practice, these structs are Sendable (all properties are either primitives or other Sendable types like UUID, Date, String), but the compiler cannot verify without an explicit declaration.

**Target Behavior:**

Add explicit `Sendable` conformance to all model structs. This allows them to be safely passed across isolation boundaries and silences compiler warnings in strict concurrency mode.

**Step-by-Step Instructions:**

1. **Update BookmarkModels.swift**:
   - Line 3: `struct BookmarkedAyah: Codable, Identifiable` becomes `struct BookmarkedAyah: Codable, Identifiable, Sendable`
   - Line 23: `struct BookmarkedHadith: Codable, Identifiable` becomes `struct BookmarkedHadith: Codable, Identifiable, Sendable`

2. **Update HadithModels.swift**:
   - Line 3: `struct DailyHadith: Codable, Identifiable` becomes `struct DailyHadith: Codable, Identifiable, Sendable`
   - Line 28: `struct HadithSectionResponse: Codable` becomes `struct HadithSectionResponse: Codable, Sendable`
   - Line 33: `struct HadithMetadata: Codable` becomes `struct HadithMetadata: Codable, Sendable`
   - Line 45: `struct HadithSectionDetail: Codable` becomes `struct HadithSectionDetail: Codable, Sendable`
   - Line 55: `struct HadithAPIEntry: Codable` becomes `struct HadithAPIEntry: Codable, Sendable`
   - Line 71: `struct HadithGradeEntry: Codable` becomes `struct HadithGradeEntry: Codable, Sendable`
   - Line 76: `struct HadithReference: Codable` becomes `struct HadithReference: Codable, Sendable`
   - Line 82: `struct HadithEditionInfo: Codable` becomes `struct HadithEditionInfo: Codable, Sendable`
   - Line 101: `enum HadithCollection: String, CaseIterable` becomes `enum HadithCollection: String, CaseIterable, Sendable`

3. **Update QuranModels.swift**:
   - Line 4: `struct SurahListResponse: Codable` becomes `struct SurahListResponse: Codable, Sendable`
   - Line 10: `struct SurahInfo: Codable, Identifiable` becomes `struct SurahInfo: Codable, Identifiable, Sendable`
   - Line 22: `struct SurahDetailResponse: Codable` becomes `struct SurahDetailResponse: Codable, Sendable`
   - Line 28: `struct SurahDetail: Codable` becomes `struct SurahDetail: Codable, Sendable`
   - Line 38: `struct Ayah: Codable, Identifiable` becomes `struct Ayah: Codable, Identifiable, Sendable`
   - Line 50: `struct DisplayAyah: Identifiable` becomes `struct DisplayAyah: Identifiable, Sendable`
   - Line 60: `struct EditionResponse: Codable` becomes `struct EditionResponse: Codable, Sendable`
   - Line 66: `struct Edition: Codable, Identifiable` becomes `struct Edition: Codable, Identifiable, Sendable`
   - Line 77: `struct DailyAyah: Codable, Identifiable` becomes `struct DailyAyah: Codable, Identifiable, Sendable`
   - Line 102: `struct Qari: Identifiable, Codable` becomes `struct Qari: Identifiable, Codable, Sendable`
   - Line 131: `struct CachedSurah: Codable` becomes `struct CachedSurah: Codable, Sendable`

4. **Update JournalModels.swift, StreakModels.swift, RoutineModels.swift, ShareModels.swift, PrayerModels.swift**:
   - Apply the same pattern: add `, Sendable` to all `struct` and `enum` declarations that are currently Codable or Identifiable
   - Enums become Sendable automatically (all enum cases are value-based)

5. **Verify all properties are Sendable**:
   - For each struct/enum, verify that all property types are themselves Sendable:
     - Primitives (Int, String, Double, Bool): Sendable
     - UUID, Date: Sendable
     - Collections ([T], [K: V]) of Sendable types: Sendable
     - Nested Codable types: must also be Sendable
   - If any property is non-Sendable, that struct cannot be marked Sendable (e.g., CLLocationCoordinate2D is not Sendable by default)

**Verification:**

1. **Compilation:**
   - The project compiles with all Sendable conformances added
   - No warning about unconformable types

2. **Strict concurrency check:**
   - Enable strict concurrency checking (Swift 5.10+) and verify no errors in model files

3. **Cross-isolation passing test:**
   - In a unit test, create a DailyAyah on MainActor and pass it to a non-MainActor function; confirm it compiles and works

**Dependencies:**

- Follows CS-02 (CacheManager Protocol must be async-based) because models are passed through the protocol methods
- Precedes CS-08 (Integration tests)

**Risk & Rollback:**

- **Risk:** If any property is non-Sendable and was undetected, marking the struct Sendable is a lie and could lead to data races
- **Mitigation:** Review all property types carefully before adding Sendable
- **Rollback:** Remove Sendable conformances and fall back to non-Sendable models

---

### CS-08: Integration & Concurrency Tests

**Priority:** P0 (Final validation after all other tasks)

**Assigned Files:**
- New file: `RevengeTests/ConcurrencyTests.swift`
- New file: `RevengeTests/CacheActorTests.swift`
- Updated: `RevengeTests/Mocks/ServiceMocks.swift`

**Current Behavior:**

The test suite has basic mocking but lacks rigorous concurrency and data-race testing. Concurrent mutations of shared state (bookmarks, journal) are not validated. Main-thread violations in LocationService are not checked.

**Target Behavior:**

Create comprehensive test suites that validate:
1. **CacheManager actor atomicity:** Concurrent bookmark/journal mutations do not lose data
2. **LocationService main-thread safety:** Delegate callbacks don't trigger background thread warnings
3. **Sendable conformance:** Models can be safely passed across isolation boundaries
4. **Integration:** All async/await call chains work correctly across the service layer

**Step-by-Step Instructions:**

1. **Create CacheActorTests.swift**:
   ```
   Test: Concurrent Bookmark Saves
   - Setup: Create a CacheManager actor instance
   - Execute: Start 10 concurrent tasks, each saving a unique bookmark
   - Verify: loadAyahBookmarks() returns all 10 bookmarks
   - Measure: Total time should be < 500ms
   
   Test: Concurrent Removes
   - Setup: Pre-populate 10 bookmarks
   - Execute: Concurrently remove 5 different bookmarks from different tasks
   - Verify: Only 5 remain, correct ones are removed
   
   Test: Concurrent Read-Write
   - Setup: One task continuously reading, another continuously writing
   - Execute: Run both for 5 seconds
   - Verify: No crashes, read count > 100, write count > 50
   
   Test: Journal Entry Updates
   - Setup: Create and save a journal entry
   - Execute: Concurrently update the same entry from 5 tasks with different content
   - Verify: Final entry has content from the last-completing task (or is idempotent)
   ```

2. **Create ConcurrencyTests.swift**:
   ```
   Test: LocationService MainActor Dispatch
   - Setup: Create a LocationService and mock CLLocationManager
   - Execute: Simulate location updates from background thread
   - Verify: @Published properties update on main thread; no console warnings
   
   Test: AppSettings MainActor Access
   - Setup: Access AppSettings.shared from non-MainActor context
   - Execute: Attempt to read/write properties
   - Verify: Compiler error or proper Task wrapper required
   
   Test: Sendable Model Passing
   - Setup: Create DailyAyah on @MainActor
   - Execute: Pass to an actor/non-MainActor function
   - Verify: Compiles and transfers correctly
   
   Test: PrayerTimesService Async Chain
   - Setup: Call fetchPrayerTimes from @MainActor ViewModel
   - Execute: Await the result, trigger UI update
   - Verify: No deadlocks, data flows correctly
   ```

3. **Update MockAPIService** (ServiceMocks.swift):
   - Ensure MockAPIService remains `@unchecked Sendable` (no changes needed from CS-04 scope)
   - Verify all configurable properties are read-only or use proper locking if writable
   - Add note that this is intentionally simplified for tests

4. **Add Main Thread Checker Integration**:
   - Create a test helper that enables Main Thread Checker instrumentation
   - Run all tests with this enabled to catch any background-thread violations

5. **Create a "Stress Test"**:
   ```
   Test: 100 Concurrent Operations
   - Setup: CacheManager + 10 concurrent tasks, each doing 10 operations
   - Execute: Mix of reads, writes, deletes over 10 seconds
   - Verify: No crashes, no data loss, performance acceptable
   ```

**Verification:**

1. **All tests pass:**
   - Run `xcodebuild test` and confirm 100% pass rate

2. **No thread-safety warnings:**
   - Run tests with Main Thread Checker enabled; expect 0 violations

3. **Performance benchmarks:**
   - concurrent bookmark saves complete in under 500ms
   - actor overhead is negligible (< 5% latency increase vs. non-concurrent baseline)

4. **Code coverage:**
   - Concurrency tests should cover all paths in CacheManager, LocationService, AppSettings

**Dependencies:**

- Depends on: CS-01, CS-02, CS-03, CS-04, CS-05, CS-06, CS-07 (all previous tasks must be complete)

**Risk & Rollback:**

- **Risk:** Tests may reveal unexpected failures or performance issues
- **Mitigation:** Plan for iterative debugging; flag failures as P0 blockers for release
- **Rollback:** If concurrency tests fail, revert prior commits and re-evaluate the design

---

## Execution Timeline

### Week 1: Foundation (Days 1–3)

| Day | Task | Owner | Status |
|-----|------|-------|--------|
| Day 1 (2h) | CS-01: CacheManager Actor conversion | Eng | ✅ Done (Apr 29) |
| Day 1 (1h) | CS-02: CacheManaging Protocol update | Eng | ✅ Done (Apr 29) |
| Day 2 (2h) | CS-03: LocationService @MainActor | Eng | ✅ Done (Apr 28) |
| Day 3 (2h) | Code review & integration prep | Eng | ✅ Done (Apr 29) |

**Success Criteria:**
- CacheManager compiles as actor
- All call sites use `await`
- No compile errors
- LocationService main-thread isolation verified

### Week 2: Service Layer (Days 4–5)

| Day | Task | Owner | Status |
|-----|------|--------|--------|
| Day 4 (1h) | CS-04: PrayerTimesService Sendable | Eng | Scheduled |
| Day 4 (1h) | CS-05: NotificationService Sendable | Eng | Scheduled |
| Day 5 (1.5h) | CS-06: AppSettings @MainActor | Eng | Scheduled |
| Day 5 (1.5h) | Integration testing | Eng | Scheduled |

**Success Criteria:**
- All services compile with Sendable/MainActor
- Cross-service calls work correctly
- No data races detected

### Week 3: Validation (Day 6)

| Day | Task | Owner | Status |
|-----|------|--------|--------|
| Day 6 (1h) | CS-07: Model Sendable conformances | Eng | ✅ Done (Apr 28) |
| Day 6 (2h) | CS-08: Integration & concurrency tests | Eng | Scheduled |
| Day 6 (1h) | Final review & documentation | Eng | Scheduled |

**Success Criteria:**
- All tests pass
- No thread-safety warnings
- Performance benchmarks met
- Ready for release

---

## Summary of Changes by Component

### CacheManager
- **Before:** Final class with DispatchQueue, synchronous methods, data-race-prone mutations
- **After:** Actor with async methods, atomic read-modify-write, no lost bookmarks

### LocationService
- **Before:** ObservableObject with delegate callbacks on background threads
- **After:** @MainActor with DispatchQueue.main.async wrappers, safe Published updates

### PrayerTimesService
- **Before:** Non-Sendable singleton, unsafe to pass across isolation boundaries
- **After:** @unchecked Sendable singleton, safe for all contexts

### NotificationService
- **Before:** Non-Sendable singleton, unsafe in strict concurrency mode
- **After:** @unchecked Sendable singleton, safe for all contexts

### AppSettings
- **Before:** ObservableObject without isolation, thread-unsafe
- **After:** @MainActor ObservableObject, thread-safe

### Model Layer (BookmarkModels, QuranModels, HadithModels, etc.)
- **Before:** Sendable by value but not declared, compiler warnings in strict mode
- **After:** Explicit Sendable conformance, clean strict concurrency

### ViewModels (HomeViewModel, BookmarksViewModel, etc.)
- **Before:** Synchronous calls to CacheManager
- **After:** Async calls with `await`, properly structured concurrency

---

## Appendix: Terminology

- **Data race:** Two threads access the same mutable state concurrently without synchronization
- **Isolation boundary:** A transition between different concurrency contexts (e.g., @MainActor → background actor)
- **@MainActor:** Annotation declaring that all accesses to this type must happen on the main thread
- **Actor:** A Swift concurrency primitive that serializes access to mutable state via an implicit executor
- **Sendable:** A type-safe protocol declaring that a value can be safely transferred across isolation boundaries
- **@unchecked Sendable:** An assertion that a type is Sendable even though the compiler cannot verify it; use with caution
- **Strict concurrency:** A Swift compiler mode that flags unsafe cross-isolation type transfers and requires Sendable conformance

---

## References & Resources

- [Swift Concurrency — Apple Documentation](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
- [Actor Isolation in Swift — Swift Forums](https://forums.swift.org/t/actor-isolation/49099)
- [Sendable Protocol — Apple Docs](https://developer.apple.com/documentation/swift/sendable)
- [SE-0306: Actors](https://github.com/apple/swift-evolution/blob/main/proposals/0306-actors.md)
- [SE-0337: Incremental migration to concurrency isolation checking](https://github.com/apple/swift-evolution/blob/main/proposals/0337-support-incremental-migration-to-concurrency-checking.md)

---

**Document Version:** 1.1
**Last Updated:** 2026-04-29
**Status:** Sprint 1 Complete — CS-01 through CS-03 and CS-07 done

### Implementation Notes (Apr 28–29, 2026)

**Phase 1 (Apr 28):** Committed as `eca3931`. Cached DateFormatters/JSON coders (PR-01, PR-02),
extracted PrayerCountdownViewModel (PR-03), added Sendable to all model structs (CS-07),
@MainActor on LocationService (CS-03), eliminated force unwraps (DL-01, DL-02).

**Phase 2A (Apr 29):** CacheManager actor conversion (CS-01) and full protocol async update (CS-02).
Additionally completed during this phase:
- Added `JournalManaging` and `SurahCaching` sub-protocols to `CacheManaging` (supports AD-01)
- Injected `CacheManaging` protocol into BookmarksViewModel, JournalViewModel (supports AD-03)
- Changed ReadingViewModel and SurahListViewModel to use protocol-typed cache (supports AD-02)
- Updated `StreakTracking` and `RoutineProviding` protocols to async (ripple from CS-01)
- Updated RoutineViewModel.loadRoutine to async, RoutineView uses `.task` modifier
- All 9 test files updated for async/await compatibility
- Both app and test targets compile cleanly (verified via xcodebuild)

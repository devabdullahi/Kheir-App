# API & Data Layer Implementation Plan

**Department:** API & Data Layer  
**Product:** Kheir (Islamic Spiritual Companion App)  
**Created:** April 26, 2026  
**Version:** 1.0

---

## Department Overview

The API & Data Layer department owns all data fetching, caching, error handling, and persistence infrastructure for the Kheir app. This department manages:

- **APIService:** Network requests to Quran, Hadith, Prayer Times, and Hijri date APIs
- **CacheManager:** File-based and in-memory caching with eviction policies
- **Error Handling:** APIError enum and error recovery strategies
- **Data Persistence:** Daily content caching, bookmark storage, journal entries, routine tracking
- **Performance:** Main thread safety, cache warmup, I/O optimization
- **Widget Integration:** Shared data layer with KheirWidget extension via App Groups

**Current Status (as of 2026-04-26):**
- Core caching system implemented with NSCache + serial dispatch queue
- CacheManager warmup syncs on main thread (3 file I/O calls)
- APIError enum exists but too coarse (no HTTP status codes, lost DecodingError)
- Force unwraps on API responses and widget Calendar operations
- Cache files accumulate indefinitely (730+ files per year)
- Bookmark lookup O(n) on every check
- URLCache allocation unused (no server cache headers)

---

## Priority Order

### Blocking Issues (Must Fix Before Next Release)
1. **DL-01** — Force unwrap crash on fetchRandomHadith() response.hadiths — ✅ Done (Apr 28)
2. **DL-02** — Widget force unwrap Calendar.current.date() crash — ✅ Done (Apr 28)
3. **DL-03** — Placeholder App Store URL blocks production launch

### High-Impact Issues (Fix in Sprint)
4. **DL-04** — Enhance APIError with HTTP status codes and DecodingError
5. **DL-05** — Implement cache eviction policy for daily content files
6. **DL-06** — Optimize bookmark lookup with in-memory index
7. **DL-07** — Move CacheManager warmup off main thread — ⚠️ Partially addressed (Apr 29, actor executor runs on thread pool, but init still synchronous)
8. **DL-08** — Replace sync NSCache slowpath with async reload — ✅ Done (Apr 29, ioQueue.sync removed; actor serializes all access natively)

### Medium-Impact Issues (Backlog)
9. **DL-09** — Fix SurahListViewModel cache-only guard (no refresh)
10. **DL-10** — Cancel location retry Task in HomeViewModel
11. **DL-11** — Remove duplicate PrayerTimesViewModel tomorrow's Fajr API call
12. **DL-12** — Audit URLCache effectiveness and reconfigure

### Polish (Nice to Have)
13. **DL-13** — Remove CacheManager.exists() disk-check optimization
14. **DL-14** — Expand String.isArabic range (Arabic Supplement/Extended)
15. **DL-15** — Share widget color constants via App Group or framework

---

## Task Definitions

---

### DL-01: Force Unwrap Crash on fetchRandomHadith()

**Priority:** P0 (CRITICAL)  
**Files:**
- `Revenge/Core/Services/APIService.swift` (lines 109, 118)

**Current Behavior:**
```swift
let collections: [HadithCollection] = [.bukhari, .muslim, .abuDawud, .tirmidhi, .nasai, .ibnMajah]
let collection = collections.randomElement()!  // Line 109 — safe (non-empty literal)

// ...

guard !response.hadiths.isEmpty else {
    throw APIError.serverError
}

let hadith = response.hadiths.randomElement()!  // Line 118 — UNSAFE (API data)
```

Even though there's an isEmpty guard, if:
- The API behavior changes and returns empty section
- A race condition unloads the response between the guard and force unwrap
- A future code change removes the guard

Then the app crashes in production with no recovery.

**Target Behavior:**
- Safely unwrap `randomElement()` results using `guard let` or `throw`
- Return appropriate APIError when either collection or hadiths array is unexpectedly empty
- Add detailed error message for debugging API response issues

**Step-by-Step Instructions:**

1. **Modify fetchRandomHadith() to replace force unwrap on line 109:**
   - Change `let collection = collections.randomElement()!` to `guard let collection = collections.randomElement() else { throw APIError.serverError }`
   - This defensive approach handles potential future changes to the collections array

2. **Modify fetchRandomHadith() to replace force unwrap on line 118:**
   - Replace the force unwrap with a guard statement
   - Add new APIError case for "empty response" (e.g., `case emptyResponse`)
   - When hadiths array is empty after the guard check, throw `APIError.emptyResponse`

3. **Update APIError enum (lines 183-195):**
   - Add case: `case emptyResponse(resource: String)` to communicate which resource was empty
   - Update errorDescription to include resource name

4. **Test the change:**
   - Verify that fetchRandomHadith throws appropriate error when response is empty
   - Verify that error is caught gracefully in HomeViewModel.fetchDailyHadith (which already has try-catch)
   - Verify fallback hadith is displayed when fetch fails

**Verification:**
- Unit test fetchRandomHadith with mocked empty response
- Confirm HomeView displays fallback/error state instead of crashing
- Verify error is logged to help diagnose API issues

**Dependencies:** None (local change only)

**Risk/Rollback:**
- Risk: Minimal. Error path already handled in calling code.
- Rollback: Revert to force unwrap (previous behavior) if error handling causes issues.
- Mitigation: Test with mock empty response before rollout.

---

### DL-02: Widget Force Unwrap Calendar.current.date() Crash

**Priority:** P0 (CRITICAL)  
**Files:**
- `KheirWidget/DailyAyahWidget.swift` (line 53)
- `Revenge/Features/Home/HomeViewModel.swift` (line 268)

**Current Behavior:**
```swift
// DailyAyahWidget.swift:53
let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!

// HomeViewModel.swift:268
nextPrayerTime = Calendar.current.date(byAdding: .day, value: 1, to: times.fajr)
```

Widget crashes are unrecoverable without user reinstall. Widget extension runs outside app sandbox and cannot recover gracefully. If Calendar.current.date() returns nil (rare but possible under edge cases), the widget becomes unusable.

**Target Behavior:**
- Use safe unwrapping with guard/if-let
- Return sensible defaults or skip timeline update on edge case
- Widget remains responsive even if date calculation fails

**Step-by-Step Instructions:**

1. **Fix DailyAyahWidget.swift line 53:**
   - Replace `let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!` with safe unwrap
   - If unwrap fails, use `Date().addingTimeInterval(86400)` as fallback (24 hours forward)
   - Comment why: "Calendar.current.date can return nil in rare edge cases; fallback ensures widget reliability"

2. **Fix HomeViewModel.swift line 268:**
   - This line assigns to nextPrayerTime without guard
   - Wrap in: `if let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: times.fajr) { nextPrayerTime = nextDay }`
   - If nil, leave nextPrayerTime unchanged (will trigger next loadPrayerCountdown on timer tick)

3. **Document the change:**
   - Add comment about widget reliability and Calendar edge cases
   - Note that defensive coding in widgets is non-negotiable due to unrecoverable crash state

**Verification:**
- Test widget timeline generation with mock data
- Verify widget renders even if Calendar.date returns nil
- Confirm countdown still updates if Prayer times calculation fails

**Dependencies:** None

**Risk/Rollback:**
- Risk: Very low. Defensive coding only improves reliability.
- Rollback: Revert if fallback date logic causes unexpected prayer time display.

---

### DL-03: Placeholder App Store URL Blocks Production Launch

**Priority:** P0 (CRITICAL)  
**Files:**
- `Revenge/Features/Settings/SettingsView.swift` (line 402)

**Current Behavior:**
```swift
Button {
    if let url = URL(string: "https://apps.apple.com/app/idYOUR_APP_ID") {
        UIApplication.shared.open(url)
    }
}
```

In production, this URL is invalid. Tapping "Rate Kheir on the App Store" opens a broken App Store page, creating a poor user experience and suggesting the app is unfinished.

**Target Behavior:**
- Replace placeholder with actual App Store ID when available
- Gracefully disable button if ID is not configured (development builds)
- Update URL to correct format: `https://apps.apple.com/app/kheir/idXXXXXXXXXX`

**Step-by-Step Instructions:**

1. **Create AppConstants or config for App Store ID:**
   - Add to `AppConstants.swift` (or similar configuration file):
     ```
     static let appStoreID = "YOUR_APP_ID"  // Replace with actual ID from App Store Connect
     ```

2. **Update SettingsView.swift line 402:**
   - Replace hardcoded URL with: `"https://apps.apple.com/app/kheir/id\(AppConstants.appStoreID)"`
   - Or conditionally show button only if appStoreID is not a placeholder

3. **Add validation:**
   - Before release, verify appStoreID is set to correct 9-10 digit number
   - Add assert in debug builds: `assert(AppConstants.appStoreID != "YOUR_APP_ID", "App Store ID not configured")`

4. **Test:**
   - Verify button opens correct App Store page when tapped

**Verification:**
- Confirm URL is valid format before release
- Test opening URL on device (not simulator)
- Verify App Store page shows correct app

**Dependencies:** Requires App Store ID from App Store Connect (blocking task for PM/releases team)

**Risk/Rollback:**
- Risk: None if ID is correct. Rollback requires updating AppConstants.
- Mitigation: Add CI check to prevent release build with placeholder ID.

---

### DL-04: Enhance APIError with HTTP Status Codes and DecodingError

**Priority:** P1 (HIGH)  
**Files:**
- `Revenge/Core/Services/APIService.swift` (lines 23-33, 183-195)

**Current Behavior:**
```swift
enum APIError: LocalizedError {
    case invalidURL
    case serverError          // Covers 429, 404, 500, any non-2xx
    case decodingError        // Declared but never thrown
}

// In fetch():
guard let httpResponse = response as? HTTPURLResponse,
      200..<300 ~= httpResponse.statusCode else {
    throw APIError.serverError  // Lost HTTP status code!
}
return try JSONDecoder().decode(type, from: data)  // Throws raw DecodingError, not APIError.decodingError
```

**Problem:**
- All server errors produce identical "Server error" message
- Rate limit (429) indistinguishable from server error (500)
- DecodingError details lost; clients cannot distinguish between malformed JSON and missing fields
- No way to implement retry logic based on HTTP status (e.g., exponential backoff for 429)
- Difficult to debug API integration issues in production

**Target Behavior:**
- Preserve HTTP status code in error
- Preserve original DecodingError with detailed context
- Classify errors into categories: network, client, rate limit, server, decode
- Callers can implement intelligent retry logic

**Step-by-Step Instructions:**

1. **Redesign APIError enum (lines 183-195):**
   ```
   enum APIError: LocalizedError {
       case invalidURL
       case networkError(URLError)
       case httpError(statusCode: Int, message: String)
       case decodingError(DecodingError)
   }
   ```
   - Add associated values for status code, original error details
   - Update errorDescription to include status code and meaningful message

2. **Update fetch() method (lines 23-33):**
   - Capture statusCode in guard failure:
     ```
     guard let httpResponse = response as? HTTPURLResponse else {
         throw APIError.networkError(...)
     }
     guard 200..<300 ~= httpResponse.statusCode else {
         throw APIError.httpError(statusCode: httpResponse.statusCode, message: "HTTP error")
     }
     ```
   - Catch DecodingError from JSONDecoder and wrap:
     ```
     do {
         return try JSONDecoder().decode(type, from: data)
     } catch let decodingError as DecodingError {
         throw APIError.decodingError(decodingError)
     }
     ```

3. **Update all callers (HomeViewModel, PrayerTimesViewModel, etc.):**
   - Review error handling in all locations that call apiService methods
   - Add specific handling for rate limit (429) if present: log and retry with backoff
   - Add specific handling for decode error: log original DecodingError details for debugging

4. **Test:**
   - Mock APIService to throw each error type
   - Verify error messages are helpful and include status codes
   - Confirm callers can distinguish between error types

**Verification:**
- Unit test fetch() with mocked HTTPURLResponse for 404, 429, 500
- Unit test fetch() with malformed JSON response
- Verify error messages include status codes and original error context
- Confirm callers handle new error types without crashing

**Dependencies:** All code calling APIService needs testing after change

**Risk/Rollback:**
- Risk: Medium. Error handling is critical path. Changes need thorough testing.
- Rollback: Revert to simple 3-case enum if new error handling causes issues.
- Mitigation: Add comprehensive error handling tests before rollout.

---

### DL-05: Implement Cache Eviction Policy for Daily Content Files

**Priority:** P1 (HIGH)  
**Files:**
- `Revenge/Core/Services/CacheManager.swift` (lines 239-287, new cleanup method)

**Current Behavior:**
```swift
// Each day:
func cacheDailyAyah(_ ayah: DailyAyah) {
    save(ayah, filename: "daily_ayah_\(ayah.dateString).json")  // daily_ayah_2026-04-26.json
}

func cacheDailyHadith(_ hadith: DailyHadith) {
    save(hadith, filename: "daily_hadith_\(hadith.dateString).json")  // daily_hadith_2026-04-26.json
}

func saveRoutine(_ routine: DailyRoutine) {
    save(routine, filename: "routine_\(routine.type.rawValue)_\(routine.dateString).json")  // routine_morning_2026-04-26.json
}
```

**Problem:**
- After 1 year: ~730 daily_ayah + 730 daily_hadith + 1460 routine files = 2,920+ cache files
- No cleanup ever runs; storage grows unbounded
- migrateToAppGroupIfNeeded copies ALL files (expensive on first migration)
- No performance impact yet, but scales poorly if app adds more daily content

**Target Behavior:**
- Keep only last 30 days of daily content
- Keep only last 90 days of routine data
- Cleanup runs automatically when CacheManager detects old files
- New method: `evictStaleCache()` called on app launch (not blocking)

**Step-by-Step Instructions:**

1. **Add eviction constants to CacheManager:**
   ```
   private let dailyContentRetentionDays = 30
   private let routineDataRetentionDays = 90
   ```

2. **Create evictStaleCache() method:**
   - Runs async on ioQueue (not main thread)
   - Scans cacheDirectory for files matching patterns:
     - `daily_ayah_YYYY-MM-DD.json`
     - `daily_hadith_YYYY-MM-DD.json`
     - `routine_*_YYYY-MM-DD.json`
   - Parse date from filename
   - If date < (today - retentionDays), delete file
   - Log count of deleted files for debugging

3. **Call evictStaleCache() from init():**
   - After migrateToAppGroupIfNeeded()
   - Async dispatch so main thread not blocked:
     ```
     ioQueue.async { [weak self] in
         self?.evictStaleCache()
     }
     ```

4. **Add date parsing helper:**
   - Extract YYYY-MM-DD from filename
   - Compare with today's date
   - Handle edge cases (invalid filename format)

5. **Test:**
   - Create mock cache files with old dates
   - Call evictStaleCache()
   - Verify old files deleted, recent files retained

**Verification:**
- Unit test evictStaleCache with mock file dates
- Confirm only files older than retention threshold deleted
- Verify count of deleted files logged correctly
- Measure migration time improvement (fewer files to copy)

**Dependencies:** None

**Risk/Rollback:**
- Risk: Low. Eviction happens on startup (non-blocking).
- Rollback: Comment out evictStaleCache() call if issues arise.
- Mitigation: Add retention constants as user-configurable settings if feedback suggests different retention needed.

---

### DL-06: Optimize Bookmark Lookup with In-Memory Index

**Priority:** P1 (HIGH)  
**Files:**
- `Revenge/Core/Services/CacheManager.swift` (lines 289-361, extensions for bookmarks)
- `Revenge/Core/Models/` (relevant bookmark models)

**Current Behavior:**
```swift
func isAyahBookmarked(surah: Int, ayah: Int) -> Bool {
    loadAyahBookmarks().contains { $0.surahNumber == surah && $0.ayahNumber == ayah }
}

func isHadithBookmarked(text: String, source: String) -> Bool {
    loadHadithBookmarks().contains { $0.text == text && $0.source == source }
}
```

**Problem:**
- Called on every HomeView appearance (expensive if many bookmarks)
- Called in list rendering for each row (O(n) per row = O(n²) total)
- Loads entire array from memory cache or disk, decodes JSON, scans linearly
- Performance degrades as bookmarks grow (100+ bookmarks now painful)

**Target Behavior:**
- Maintain in-memory Set<String> index of bookmarked coordinates
- Index updated atomically when bookmarks saved/removed
- Lookup becomes O(1) by coordinate or hash
- Maintains consistency with file-based truth

**Step-by-Step Instructions:**

1. **Create bookmark index structure:**
   - Add private properties to CacheManager:
     ```
     private var ayahBookmarkIndex = Set<String>()      // "surah:ayah" format
     private var hadithBookmarkIndex = Set<String>()    // hash(text + source)
     ```
   - Or use Dictionary<String, UUID> to maintain stable IDs

2. **Populate indices during warmMemoryCache():**
   - When warmMemoryCache loads bookmarks, build index in-memory
   - Parse loaded data and extract coordinates
   - Store in ayahBookmarkIndex / hadithBookmarkIndex

3. **Update saveAyahBookmark():**
   - After save(), also insert into ayahBookmarkIndex
   - Use format: "\(bookmark.surahNumber):\(bookmark.ayahNumber)"

4. **Update removeAyahBookmark():**
   - After save(), also remove from ayahBookmarkIndex
   - Remove both by coordinate and by ID

5. **Replace isAyahBookmarked() with index lookup:**
   ```
   func isAyahBookmarked(surah: Int, ayah: Int) -> Bool {
       let key = "\(surah):\(ayah)"
       return ayahBookmarkIndex.contains(key)
   }
   ```

6. **Repeat for Hadith bookmarks:**
   - Use hash of (text + source) as key
   - Example: `let key = "\(text):\(source)".hashValue.description`

7. **Test:**
   - Verify index matches file truth on load
   - Verify isAyahBookmarked returns correct result (index hit vs miss)
   - Verify bookmark save/remove updates index
   - Profile performance improvement

**Verification:**
- Unit test index building from loaded bookmarks
- Unit test isAyahBookmarked with bookmarks in index and not in index
- Benchmark: measure time for 1000 lookups before/after (should be < 1ms after)
- Verify index stays in sync with file on each mutation

**Dependencies:** None

**Risk/Rollback:**
- Risk: Low. Index is optimization only; file is source of truth.
- Rollback: Remove index and revert to loadAyahBookmarks().contains() if sync issues arise.

---

### DL-07: Move CacheManager Warmup Off Main Thread

**Priority:** P1 (HIGH)  
**Files:**
- `Revenge/Core/Services/CacheManager.swift` (lines 59-81)

**Current Behavior:**
```swift
private init() {
    let containerURL: URL = ...
    cacheDirectory = ...
    try? fileManager.createDirectory(...)
    
    // Synchronous file I/O on main thread during HomeViewModel.init()!
    warmMemoryCache(filename: ayahBookmarksFile,  type: [BookmarkedAyah].self)
    warmMemoryCache(filename: hadithBookmarksFile, type: [BookmarkedHadith].self)
    warmMemoryCache(filename: journalFile,          type: [JournalEntry].self)
    
    migrateToAppGroupIfNeeded()
}

private func warmMemoryCache<T: Decodable>(filename: String, type: T.Type) {
    let url = cacheDirectory.appendingPathComponent(filename)
    guard let data = try? Data(contentsOf: url) else { return }  // Synchronous disk read!
    memoryCache.setObject(CacheBox(data), forKey: filename as NSString)
}
```

**Problem:**
- CacheManager.shared accessed during HomeViewModel.init (main thread)
- Three synchronous Data(contentsOf:) calls block main thread during app launch
- On slow devices or under disk pressure, can cause visible UI stall (100-500ms)
- Contributes to slow app startup time

**Target Behavior:**
- Warmup happens on background thread (ioQueue)
- Main thread returns immediately from init()
- First bookmark/journal reads slightly slower (hit disk if warmup not complete), but app is responsive
- Cache still warmed by the time user interacts with bookmarks

**Step-by-Step Instructions:**

1. **Remove synchronous warmMemoryCache calls from init():**
   - Delete or comment out the three warmMemoryCache() calls (lines 76-78)

2. **Add warmupAsync() method to CacheManager:**
   ```swift
   private func warmupAsync() {
       ioQueue.async { [weak self] in
           self?.warmMemoryCache(filename: ayahBookmarksFile, type: [BookmarkedAyah].self)
           self?.warmMemoryCache(filename: hadithBookmarksFile, type: [BookmarkedHadith].self)
           self?.warmMemoryCache(filename: journalFile, type: [JournalEntry].self)
       }
   }
   ```

3. **Call warmupAsync() at end of init():**
   - After migrateToAppGroupIfNeeded()
   - Dispatch async so init completes immediately

4. **Optional: Add warmup completion tracking:**
   - If needed, add @Published var isWarmupComplete = false
   - Set to true when warmupAsync finishes
   - Not strictly necessary since NSCache is thread-safe

5. **Test:**
   - Measure app startup time with and without warmup
   - Verify first bookmark access is still fast (within 50ms)
   - Confirm no race conditions between first read and warmup

**Verification:**
- Profile startup time (should improve)
- Unit test that warmupAsync populates cache
- Integration test: app launches, user opens bookmarks before warmup completes (should still work, maybe slightly slower)
- Verify load() slowpath (disk fallback) works correctly if warmup not done yet

**Dependencies:** None

**Risk/Rollback:**
- Risk: Low. Worst case is first bookmark read hits disk (acceptable).
- Rollback: Move warmup back to init() if integration test fails.

---

### DL-08: Replace Sync NSCache Slowpath with Async Reload

**Priority:** P1 (HIGH)  
**Files:**
- `Revenge/Core/Services/CacheManager.swift` (lines 172-195)

**Current Behavior:**
```swift
func load<T: Decodable>(_ type: T.Type, filename: String) -> T? {
    // Fast path: memory hit
    if let box = memoryCache.object(forKey: filename as NSString) {
        return try? JSONDecoder().decode(type, from: box.data)
    }
    
    // Slow path: evicted, must read disk synchronously on main thread!
    return ioQueue.sync { [self] in  // BLOCKS main thread waiting for disk I/O
        if let box = memoryCache.object(forKey: filename as NSString) {
            return try? JSONDecoder().decode(type, from: box.data)
        }
        
        let url = cacheDirectory.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return nil }  // Disk read blocks
        
        memoryCache.setObject(CacheBox(data), forKey: filename as NSString)
        return try? JSONDecoder().decode(type, from: data)
    }
}
```

**Problem:**
- When NSCache evicts under memory pressure (exactly when system is stressed), slowpath activates
- ioQueue.sync blocks caller's thread waiting for disk I/O
- If caller is on main thread (common), UI freezes for 5-50ms on older devices
- Defeats purpose of async caching infrastructure

**Target Behavior:**
- Slowpath loads asynchronously
- Return cached value immediately if available; if evicted, return nil and reload in background
- Callers handle nil gracefully (most do already via ?? fallback or optional binding)
- No main thread blocking on disk I/O

**Step-by-Step Instructions:**

1. **Keep current load() as "fast memory path only":**
   - Remove slowpath (ioQueue.sync block)
   - Return nil immediately if not in memoryCache
   ```swift
   func load<T: Decodable>(_ type: T.Type, filename: String) -> T? {
       guard let box = memoryCache.object(forKey: filename as NSString) else {
           // Cache miss; async reload starts below, return nil for now
           reloadAsyncIfNeeded(filename: filename, type: T.self)
           return nil
       }
       return try? JSONDecoder().decode(type, from: box.data)
   }
   ```

2. **Create reloadAsyncIfNeeded() helper:**
   ```swift
   private func reloadAsyncIfNeeded<T: Decodable>(filename: String, type: T.Type) {
       // Avoid duplicate reloads in flight
       ioQueue.async { [weak self] in
           guard let self else { return }
           
           let url = self.cacheDirectory.appendingPathComponent(filename)
           guard let data = try? Data(contentsOf: url) else { return }
           
           self.memoryCache.setObject(CacheBox(data), forKey: filename as NSString)
       }
   }
   ```

3. **Update callers to handle nil:**
   - Most already do: `load(...) ?? []` or `if let data = load(...)`
   - Some may need updates if they assume synchronous load
   - Bookmark methods return [] on nil: `loadAyahBookmarks() ?? []` — already safe

4. **Consider single-threaded guarantees:**
   - If caller expects immediate result (e.g., synchronously rendering UI), handle differently
   - For most cases (bookmark checks, etc.), async reload is fine

5. **Test:**
   - Verify load() returns nil on cache miss
   - Verify reloadAsyncIfNeeded() populates cache for next call
   - Verify subsequent load() hits refreshed cache
   - Verify no race conditions if load() called twice rapidly

**Verification:**
- Unit test load() with cache eviction scenario
- Unit test subsequent load() finds reloaded data
- Integration test: app under memory pressure, bookmark access still responsive
- Benchmark: measure no blocking on disk I/O from main thread

**Dependencies:** DL-06 (bookmark index optimization) makes nil handling more acceptable

**Risk/Rollback:**
- Risk: Medium. Changes contract of load() from synchronous to "async with immediate nil".
- Rollback: Revert to sync slowpath if callers break (unlikely, most handle nil).
- Mitigation: Add @Deprecated(message: "sync load is blocking; use async reloadAsyncIfNeeded") if keeping slowpath temporarily.

---

### DL-09: Fix SurahListViewModel Cache-Only Guard (No Refresh)

**Priority:** P2 (MEDIUM)  
**Files:**
- `Revenge/Features/Quran/SurahListViewModel.swift` (line 35)

**Current Behavior:**
```swift
private func fetchSurahs() async {
    guard surahs.isEmpty else { return }  // Skip network forever once cache loaded!
    isLoading = true
    do {
        let list = try await APIService.shared.fetchSurahList()
        surahs = list
        filteredSurahs = list
        cache.cacheSurahList(list)
    } catch {
        print("Surah list error: \(error)")
    }
    isLoading = false
}
```

**Problem:**
- First time: cache empty, fetches from network ✓
- After cache loads: guard returns, never fetches again ✗
- If API changes or bugs exist in cached data, user sees stale surahs forever
- No refresh mechanism (e.g., pull-to-refresh or manual "Refresh" button)
- Differs from HomeViewModel behavior which passes forceRefresh flag

**Target Behavior:**
- Fetch on first load (cache miss)
- Support manual refresh (add forceRefresh parameter)
- Optionally refresh on interval if stale (e.g., > 30 days)

**Step-by-Step Instructions:**

1. **Add forceRefresh parameter:**
   ```swift
   func fetchSurahs(forceRefresh: Bool = false) async {
       guard forceRefresh || surahs.isEmpty else { return }
       isLoading = true
       // ... rest of fetch
   }
   ```

2. **Call from onAppear() without forceRefresh:**
   - First load hits cache, then network (parallel like HomeViewModel)
   - Subsequent appearances skip network unless forced

3. **Add manual refresh button to UI (optional):**
   - Create refreshSurahs() method that calls fetchSurahs(forceRefresh: true)
   - Caller can add NavigationLink or Button to trigger manual refresh

4. **Consider stale cache detection:**
   - Add timestamp to cached surah list
   - If cache > 30 days old, forceRefresh automatically
   - Prevents month-old stale data while minimizing network calls

5. **Test:**
   - Verify first load uses cache then network
   - Verify forceRefresh bypasses cache guard
   - Verify manual refresh fetches fresh data

**Verification:**
- Unit test fetchSurahs with empty and populated surahs array
- Unit test forceRefresh=true overrides guard
- Integration test: clear cache, app loads surahs, cache persists, manual refresh re-fetches

**Dependencies:** None

**Risk/Rollback:**
- Risk: Very low. Adding parameter is backward compatible.
- Rollback: Remove forceRefresh parameter if not needed.

---

### DL-10: Cancel Location Retry Task in HomeViewModel

**Priority:** P2 (MEDIUM)  
**Files:**
- `Revenge/Features/Home/HomeViewModel.swift` (lines 237-251)

**Current Behavior:**
```swift
private func loadPrayerCountdown() {
    guard let location = locationService.currentLocation else {
        // Try loading after a delay — NOT CANCELLABLE
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds
            if let loc = locationService.currentLocation {
                await updateNextPrayer(location: loc)
            }
        }
        return
    }
    Task {
        await updateNextPrayer(location: location)
    }
}
```

**Problem:**
- If location becomes available before 2-second sleep completes, stale retry fires anyway
- If user navigates away and back quickly, multiple sleep Tasks accumulate
- Task is not stored, so onDisappear() cannot cancel it
- Wastes CPU time on retries that may be unnecessary

**Target Behavior:**
- Store Task reference
- Cancel on onDisappear() or when location becomes available
- Clean up resources properly

**Step-by-Step Instructions:**

1. **Add Task storage to HomeViewModel:**
   ```swift
   private var locationRetryTask: Task<Void, Never>?
   ```

2. **Update loadPrayerCountdown() to store and cancel previous Task:**
   ```swift
   private func loadPrayerCountdown() {
       locationRetryTask?.cancel()  // Cancel any in-flight retry
       
       guard let location = locationService.currentLocation else {
           locationRetryTask = Task {
               try? await Task.sleep(nanoseconds: 2_000_000_000)
               guard !Task.isCancelled else { return }  // Check cancellation
               if let loc = locationService.currentLocation {
                   await updateNextPrayer(location: loc)
               }
           }
           return
       }
       
       Task {
           await updateNextPrayer(location: location)
       }
   }
   ```

3. **Cancel in onDisappear():**
   ```swift
   func onDisappear() {
       timer?.invalidate()
       locationRetryTask?.cancel()  // Add this
       if let observer = midnightObserver {
           NotificationCenter.default.removeObserver(observer)
           midnightObserver = nil
       }
   }
   ```

4. **Test:**
   - Verify retry Task cancels on navigation away
   - Verify retry completes if location becomes available during sleep
   - Verify no duplicate retries on multiple loadPrayerCountdown() calls

**Verification:**
- Unit test cancellation behavior
- Integration test: navigate away during 2-second sleep, verify no stale update

**Dependencies:** None

**Risk/Rollback:**
- Risk: Very low. Defensive resource cleanup only.
- Rollback: Remove Task storage if not needed.

---

### DL-11: Remove Duplicate PrayerTimesViewModel Tomorrow's Fajr API Call

**Priority:** P2 (MEDIUM)  
**Files:**
- `Revenge/Features/PrayerTimes/PrayerTimesViewModel.swift` (lines 78-89)

**Current Behavior:**
```swift
} else {
    // All of today's prayers have passed — roll over to tomorrow's Fajr.
    let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    if let tomorrowTimes = await PrayerTimesService.shared.fetchPrayerTimes(
        coordinate: coordinate,
        date: tomorrow,  // Extra API call!
        method: settings.calculationMethod,
        madhab: settings.madhab
    ) {
        let fajr = tomorrowTimes.all.first
        nextPrayer = fajr.map { PrayerTime(name: $0.name, time: $0.time, icon: $0.icon, isNext: true) }
    }
}
```

**Problem:**
- When all today's prayers pass (late evening), makes an extra API call to get tomorrow's Fajr
- HomeViewModel already fetches prayer times and handles this case (line 268)
- Redundant network request wastes bandwidth and adds latency
- PrayerTimesService.fetchPrayerTimes may not cache by date, causing inefficiency

**Target Behavior:**
- Reuse cached prayer times if available
- Only fetch tomorrow's times if necessary
- Reduce API calls to one per screen

**Step-by-Step Instructions:**

1. **Check if PrayerTimesService caches by date:**
   - Review PrayerTimesService.swift to see if it stores times for multiple dates
   - If not cached, consider caching next day's times when fetching today's

2. **Calculate tomorrow's Fajr without extra API call:**
   - If today's prayer times don't extend to tomorrow, calculate next Fajr manually
   - Or fetch once and cache both days

3. **Option A: Cache both days in PrayerTimesService:**
   - When fetching today's times, also fetch and cache tomorrow's times
   - Use cached times when all today's prayers pass
   - Requires PrayerTimesService change

4. **Option B: Use local calculation:**
   - Store today's prayer times in ViewModel
   - When showing next prayer, calculate "tomorrow at Fajr time" locally
   - Requires knowing Fajr time varies by date (complex)

5. **Option C: Accept single extra API call but throttle:**
   - Keep current logic but add check: "has this call already fired today?"
   - Store lastTomorrowFajrFetch timestamp
   - Only fetch once per day even if Fajr is reached multiple times

**Verify current behavior:**
- Check if PrayerTimesService caches times by date
- Measure how often this code path fires (late evening only)
- Estimate API call savings (minimal if rare, but still worth optimizing)

**Verification:**
- Measure API call count before/after fix
- Verify next prayer still shows correct tomorrow's Fajr time
- No manual calculation errors (Fajr time varies by date)

**Dependencies:** May require PrayerTimesService changes

**Risk/Rollback:**
- Risk: Low if using cached times. High if using manual calculation without proper validation.
- Rollback: Remove optimization and keep extra API call if calculation is incorrect.
- Mitigation: Test extensively with different dates and locations.

---

### DL-12: Audit URLCache Effectiveness and Reconfigure

**Priority:** P2 (MEDIUM)  
**Files:**
- `Revenge/Core/Services/APIService.swift` (lines 8-20)

**Current Behavior:**
```swift
private init() {
    let cache = URLCache(
        memoryCapacity: 10 * 1024 * 1024,   // 10 MB
        diskCapacity:   50 * 1024 * 1024,    // 50 MB
        diskPath: "api_service_cache"
    )
    let config = URLSessionConfiguration.default
    config.urlCache = cache
    config.requestCachePolicy = .useProtocolCachePolicy  // Honor server cache headers
}
```

**Problem:**
- `requestCachePolicy = .useProtocolCachePolicy` but APIs (Quran, Hadith, Prayer) likely return no Cache-Control headers
- URLCache is allocated (60MB total) but likely unused since APIs don't advertise cacheability
- Network requests hit server every time instead of using cached response
- 50MB disk cache is wasted; 10MB memory cache not leveraged

**Target Behavior:**
- Audit actual server cache headers from APIs
- Reconfigure URLCache policy based on findings:
  - If servers return Cache-Control: use useProtocolCachePolicy ✓
  - If not: consider useReturnCacheDataElseLoad (return cached if available)
  - Or: reduce cache size if APIs don't support caching (reclaim memory)
- Document cache strategy for each API

**Step-by-Step Instructions:**

1. **Audit server cache headers:**
   - Use curl or Proxyman to inspect HTTP headers from each API:
     - Quran API: /surah, /ayah
     - Hadith API: /editions/[collection]/sections/[section]
     - Aladhan Prayer Times API: /timings/[date]
     - Hijri conversion API: /gpiToH/[date]
   - Document what each API returns (Cache-Control, Expires, Last-Modified, ETag)

2. **Document findings:**
   - Create comment in APIService explaining cache policy per API
   - Example: "Quran API returns Cache-Control: max-age=3600, so static surahs cache well"

3. **Reconfigure URLCache if appropriate:**
   - If none of the APIs support caching, consider:
     ```swift
     config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
     ```
     - Frees memory, avoids confusion of stale URLCache
   - Or keep current policy but reduce sizes:
     ```swift
     let cache = URLCache(memoryCapacity: 2 * 1024 * 1024, diskCapacity: 10 * 1024 * 1024)
     ```

4. **Consider adding manual caching for static data:**
   - Quran surahs and ayahs are immutable; CacheManager already caches these
   - URLCache redundant for these; disable or reconfigure
   - Prayer times are date-specific; should not cache across days

5. **Test:**
   - Network conditions: offline, slow, fast
   - Verify cache headers are respected (if present)
   - Measure actual cache hit rate (network profiler)

**Verification:**
- Inspect HTTP headers in Proxyman or Charles
- Document cache policy for each API in code
- Measure URLCache effectiveness (cache hits vs misses)
- Confirm static data (Quran) caches correctly

**Dependencies:** Network auditing tool (Proxyman, Charles, etc.)

**Risk/Rollback:**
- Risk: Low. Configuration change only.
- Rollback: Revert to original cache settings if behavior changes unexpectedly.

---

### DL-13: Remove CacheManager.exists() Disk-Check Optimization

**Priority:** P3 (NICE TO HAVE)  
**Files:**
- `Revenge/Core/Services/CacheManager.swift` (lines 198-202)

**Current Behavior:**
```swift
func exists(filename: String) -> Bool {
    let url = cacheDirectory.appendingPathComponent(filename)
    return fileManager.fileExists(atPath: url.path)  // Checks disk, ignores memory cache!
}
```

**Problem:**
- Method exists() checks disk file presence, ignoring in-memory NSCache
- Inconsistent with rest of CacheManager API (which checks memory first)
- Rarely used; most callers just call load() which returns nil if missing
- Confusing: if file was just saved, exists() lags while memory cache is instant

**Target Behavior:**
- Remove exists() or update to check memory cache first
- Use load() instead (returns nil if missing, equivalent to !exists())

**Step-by-Step Instructions:**

1. **Search for uses of CacheManager.exists():**
   - Grep codebase for `.exists(`
   - Identify all callers

2. **Replace with load() or isAyahBookmarked()/isHadithBookmarked():**
   - For bookmarks: use isAyahBookmarked() or isHadithBookmarked() instead
   - For other data: use `if let data = load(...)` instead of `if exists(...) { let data = load(...) }`

3. **Remove exists() method entirely:**
   - Delete lines 198-202 from CacheManager.swift
   - Or mark as @Deprecated if library consumers depend on it

4. **Test:**
   - Verify all exists() calls replaced
   - Confirm no behavioral change (exists() was rarely used)

**Verification:**
- Grep for CacheManager.exists( to ensure all replaced
- Unit test load() returns nil for missing files (equivalent to !exists())

**Dependencies:** None

**Risk/Rollback:**
- Risk: Very low. Method barely used.
- Rollback: Re-add exists() if a caller was missed.

---

### DL-14: Expand String.isArabic Range (Arabic Supplement/Extended)

**Priority:** P3 (NICE TO HAVE)  
**Files:**
- `Revenge/Core/Extensions/String+Extensions.swift` (lines 4-7)

**Current Behavior:**
```swift
var isArabic: Bool {
    let arabicRange = Unicode.Scalar("\u{0600}")...Unicode.Scalar("\u{06FF}")
    return unicodeScalars.contains { arabicRange.contains($0) }
}
```

**Problem:**
- Only checks basic Arabic block (U+0600 to U+06FF)
- Misses Arabic Supplement (U+0750–U+077F)
- Misses Arabic Extended-A (U+08A0–U+08FF)
- Some Quranic diacritical marks (tashkeel) and special characters fall outside range
- App may incorrectly classify some texts as non-Arabic

**Target Behavior:**
- Check multiple Unicode ranges for Arabic script variants
- Correctly identify all Arabic text including diacritics

**Step-by-Step Instructions:**

1. **Update isArabic to check multiple ranges:**
   ```swift
   var isArabic: Bool {
       let ranges = [
           Unicode.Scalar("\u{0600}")...Unicode.Scalar("\u{06FF}"),  // Arabic
           Unicode.Scalar("\u{0750}")...Unicode.Scalar("\u{077F}"),  // Arabic Supplement
           Unicode.Scalar("\u{08A0}")...Unicode.Scalar("\u{08FF}"),  // Arabic Extended-A
           Unicode.Scalar("\u{FB50}")...Unicode.Scalar("\u{FDFF}"),  // Arabic Presentation Forms-A
           Unicode.Scalar("\u{FE70}")...Unicode.Scalar("\u{FEFF}")   // Arabic Presentation Forms-B
       ]
       return unicodeScalars.contains { scalar in
           ranges.contains { $0.contains(scalar) }
       }
   }
   ```

2. **Test with Quranic text:**
   - Test strings with diacritical marks (fatha, damma, kasra, sukun)
   - Verify isArabic returns true for all variants

3. **Consider performance:**
   - Multiple range checks slower than single range check
   - If called frequently, consider caching or optimizing
   - Benchmark impact (likely negligible for small strings)

**Verification:**
- Unit test isArabic with text from each Unicode block
- Verify diacritical marks recognized as Arabic
- Benchmark performance (ensure no noticeable slowdown)

**Dependencies:** None

**Risk/Rollback:**
- Risk: Very low. Expanding range only expands coverage.
- Rollback: Revert to single range if performance impact unacceptable.

---

### DL-15: Share Widget Color Constants via App Group or Framework

**Priority:** P3 (NICE TO HAVE)  
**Files:**
- `Revenge/Core/Design/Color+Theme.swift` (inferred, likely exists)
- `KheirWidget/DailyAyahWidget.swift` (lines 6-17)

**Current Behavior:**
```swift
// DailyAyahWidget.swift — DUPLICATED from app
private extension Color {
    static let darkBackground = Color(red: 0.08, green: 0.09, blue: 0.18)
    static let darkCardSurface = Color(red: 0.08, green: 0.16, blue: 0.14)
    static let islamicGold = Color(red: 0.85, green: 0.68, blue: 0.32)
    static let darkBodyText = Color(red: 0.93, green: 0.93, blue: 0.90)
    // ... more duplicates
}
```

**Problem:**
- Color constants declared separately in widget and app
- If theme changes, must update two places
- Risk of drift/mismatch between app and widget appearance
- Violates DRY principle

**Target Behavior:**
- Share Color+Theme.swift between app and widget via framework or shared code
- Single source of truth for theme colors
- Both targets automatically use latest colors

**Step-by-Step Instructions:**

1. **Option A: Create a shared framework:**
   - Create new Xcode framework target: "KheirDesignSystem" or "KheirCore"
   - Move Color+Theme.swift into framework
   - Add framework membership to both app and widget targets
   - Import in both targets

2. **Option B: Use App Group UserDefaults:**
   - Store theme colors as encoded JSON in shared UserDefaults
   - App updates defaults on launch
   - Widget reads colors from shared defaults
   - Less elegant, but avoids new framework

3. **Option C: Duplicate with comment:**
   - If framework overhead undesirable, keep duplicate but add comment:
     - "// SYNC WITH: Revenge/Core/Design/Color+Theme.swift line XXX"
   - Add CI check to alert on mismatch

4. **Recommended: Create shared framework (Option A):**
   - Move Color+Theme.swift to framework
   - Update imports in app and widget
   - Remove widget duplicate

5. **Test:**
   - Verify widget and app use same colors
   - Verify color changes in one place propagate to both targets
   - Check build targets include new framework

**Verification:**
- Inspect Color definitions in both targets
- Verify they reference same source (framework or UserDefaults)
- Visual test: compare widget and app colors side-by-side

**Dependencies:** May require project restructuring

**Risk/Rollback:**
- Risk: Low for Option B (UserDefaults), medium for Option A (framework).
- Rollback: If framework causes build issues, revert and keep duplicates.

---

## Execution Timeline

### Phase 1: Critical (Week of April 29 - May 3)
**Goal:** Eliminate crash risks before production launch.

- **DL-01:** Force unwrap on fetchRandomHadith (1 day)
- **DL-02:** Widget force unwrap Calendar.current.date (1 day)
- **DL-03:** Replace placeholder App Store URL (0.5 day + blocking PM/app store ID)

**Completion Criteria:**
- No force unwraps on API data or date calculations
- App Store URL is valid
- All crash risks verified in QA

---

### Phase 2: Performance & Stability (Week of May 6 - 17, 2 weeks)
**Goal:** Improve data layer performance and reliability.

- **DL-04:** Enhance APIError with HTTP status codes (2 days)
- **DL-05:** Implement cache eviction policy (2 days)
- **DL-06:** Bookmark lookup index optimization (2 days)
- **DL-07:** Move warmup off main thread (1 day)
- **DL-08:** Replace sync slowpath with async (2 days)

**Completion Criteria:**
- App startup time < 1.5 seconds
- No main thread blocking on cache operations
- Bookmark lookup O(1)
- Cache files auto-cleanup on app launch

---

### Phase 3: Refinement & Polish (Week of May 20 - 24, 1 week)
**Goal:** Address edge cases and improve code quality.

- **DL-09:** Fix SurahListViewModel refresh guard (1 day)
- **DL-10:** Cancel location retry Task (0.5 day)
- **DL-11:** Remove duplicate prayer times API call (1 day)
- **DL-12:** Audit URLCache effectiveness (1 day)

**Completion Criteria:**
- Surah list refreshes on demand
- Location retries cleaned up properly
- API call count reduced
- Cache strategy documented

---

### Phase 4: Future Optimization (Backlog)
**Lower priority, can slip to next quarter if needed.**

- **DL-13:** Remove CacheManager.exists()
- **DL-14:** Expand String.isArabic ranges
- **DL-15:** Share widget colors via framework

---

## Success Metrics

### Performance Metrics
- App startup time < 1.5 seconds (target: 1.2s)
- Main thread block on cache operations < 5ms (target: < 1ms)
- Bookmark lookup latency < 1ms (any count)
- Cache memory footprint < 20MB
- Zero "hangs detected" warnings in Xcode console

### Reliability Metrics
- Zero crashes in APIService or CacheManager (target: stable for 1 month)
- Force unwrap issues eliminated (target: 100% removed)
- Widget reliability >= 99% (no unrecoverable widget crashes)
- Cache eviction functioning (no unbounded file growth)

### Code Quality Metrics
- Unit test coverage for CacheManager >= 85%
- Unit test coverage for APIService >= 80%
- All error paths tested and documented
- No synchronous file I/O on main thread

---

## Rollout Strategy

### Phase 1 Rollout (Immediate)
- Hotfix branch off main
- Deploy critical fixes (DL-01, DL-02, DL-03) to staging
- 24-hour QA validation
- Merge to main and release patch version

### Phase 2-3 Rollout (Gradual)
- Feature branch: feature/api-data-layer-q2
- Merge completed tasks incrementally (not waiting for all)
- Beta test build released to internal testers after each major task
- Merge to main after Phase 2 complete (2-week cycle)

### Testing Checklist
- [ ] Unit tests pass for all modified components
- [ ] Integration tests pass (app lifecycle, bookmark operations, cache warmup)
- [ ] QA: app startup time measured
- [ ] QA: bookmark operations responsive (no UI stall)
- [ ] QA: force unwrap crashes verified fixed
- [ ] QA: widget rendering reliable
- [ ] Device testing: iPhone SE (slow), iPhone 15 Pro (fast)
- [ ] Offline scenario testing

---

## Dependencies & Blockers

### External Dependencies
- **App Store ID** (DL-03): Blocked on PM/App Store Connect setup
- **API Header Audit** (DL-12): Requires network debugging tool (Proxyman) access

### Internal Dependencies
- DL-07 (main thread warmup) → unblocks faster app startup
- DL-04 (APIError enhancement) → benefits from DL-06 (index) for better error handling

### Assumptions
- HomeViewModel and PrayerTimesViewModel error handling is robust (already assume it is)
- No architectural changes needed to CacheManager (serial queue design is sound)

---

## Risk Mitigation

### DL-01 & DL-02 (Force Unwraps)
- **Risk:** Removing force unwraps may miss edge cases where arrays are guaranteed non-empty.
- **Mitigation:** Code review to verify isEmpty guards precede any remaining unwraps; test with mock empty responses.

### DL-04 (APIError Enhancement)
- **Risk:** New error types may break existing error handling.
- **Mitigation:** Add tests for each error type; callers already use `catch` blocks which handle any error.

### DL-05 (Cache Eviction)
- **Risk:** Aggressive eviction may delete files still needed by user.
- **Mitigation:** 30/90-day retention is conservative; older data is unlikely to be accessed; test extensively with mock old files.

### DL-07 & DL-08 (Async Cache)
- **Risk:** Async warmup and slowpath may cause nil returns where sync was expected.
- **Mitigation:** Most callers already handle nil (using ?? fallback); review callers before change.

---

## Review Checklist

- [ ] All force unwraps removed or justified
- [ ] APIError enum enhanced with status codes and original errors
- [ ] Cache eviction tested with old files
- [ ] Warmup moved off main thread; startup time measured
- [ ] Bookmark index verified O(1) performance
- [ ] Unit test coverage >= 85% (CacheManager), >= 80% (APIService)
- [ ] No synchronous file I/O observed on main thread (Instruments profile)
- [ ] Widget reliability verified
- [ ] Documentation updated for error handling
- [ ] Rollout plan confirmed with engineering leads

---

## Appendix: File Locations & Summary

| Task | Primary Files | LOC Impact | Difficulty | Est. Days |
|------|--------------|-----------|-----------|-----------|
| DL-01 | APIService.swift | 5 lines | Easy | 1 |
| DL-02 | DailyAyahWidget.swift, HomeViewModel.swift | 3 lines | Easy | 1 |
| DL-03 | SettingsView.swift | 2 lines | Easy | 0.5 |
| DL-04 | APIService.swift | 30 lines | Medium | 2 |
| DL-05 | CacheManager.swift | 40 lines | Medium | 2 |
| DL-06 | CacheManager.swift | 50 lines | Medium | 2 |
| DL-07 | CacheManager.swift | 10 lines | Easy | 1 |
| DL-08 | CacheManager.swift | 15 lines | Medium | 2 |
| DL-09 | SurahListViewModel.swift | 5 lines | Easy | 1 |
| DL-10 | HomeViewModel.swift | 10 lines | Easy | 0.5 |
| DL-11 | PrayerTimesViewModel.swift | 10 lines | Medium | 1 |
| DL-12 | APIService.swift + audit | 20 lines | Medium | 1 |
| DL-13 | CacheManager.swift | -5 lines | Easy | 0.5 |
| DL-14 | String+Extensions.swift | 10 lines | Easy | 0.5 |
| DL-15 | Color+Theme.swift, DailyAyahWidget.swift | varies | Medium | 2 |
| | **TOTAL** | **215 lines** | **Avg Medium** | **~18 days** |

---

**Document Version:** 1.0  
**Last Updated:** April 26, 2026  
**Prepared by:** Product Manager, API & Data Layer  
**Next Review:** May 3, 2026 (after Phase 1 completion)

# Performance & Rendering Implementation Plan

**Kheir (Revenge) iOS App**  
**Department:** Performance & Rendering  
**Plan Date:** April 26, 2026  
**Target Sprint:** Sprint 2-3  

---

## Department Overview

The Performance & Rendering department is responsible for delivering a fast, smooth, and responsive iOS app experience. This plan addresses critical rendering bottlenecks and CPU/memory inefficiencies identified in a comprehensive 4-agent audit.

**Why This Matters:**
- Every second, `countdownText` mutations trigger full HomeView body re-evaluations, causing jank on 5-10 year old devices
- Canvas background redraws ~90 star paths every second during prayer countdown
- Multiple stale timers accumulate in memory due to missing invalidation
- DateFormatter/JSONDecoder allocations on every frame cost 2-5ms per call
- ScrollReveal animations create 286+ state nodes for long surahs (Al-Baqarah)

**Expected Outcomes:**
- Home screen: 60 FPS sustained prayer countdown animation
- Background Canvas: Pre-rendered or `.drawingGroup()` eliminates redraw overhead
- Memory: No timer stacking; DateFormatter/JSONDecoder cached as static singletons
- Long Surah (286 ayahs): <50 state nodes vs 286 (preserve scroll reveal only for first 10 visible)
- Scroll responsiveness: Prayer countdown continues smoothly during drag

---

## Priority Order

| # | Task ID | Title | Priority | Dependencies | Status |
|---|---------|-------|----------|--------------|--------|
| 1 | PR-01 | Cache DateFormatter instances as static singletons | P0 | None | ✅ Done (Apr 28) |
| 2 | PR-02 | Cache JSONDecoder/JSONEncoder as static singletons | P0 | None | ✅ Done (Apr 28) |
| 3 | PR-03 | Extract PrayerCountdownViewModel and subview | P0 | None | ✅ Done (Apr 28) |
| 4 | PR-04 | Schedule timer on .common RunLoop mode | P0 | PR-03 | Pending |
| 5 | PR-05 | Invalidate stale timers before creating new ones | P0 | None |
| 6 | PR-06 | Add `.drawingGroup()` to IslamicPatternBackground | P1 | None |
| 7 | PR-07 | Cap scrollReveal state nodes to visible items only | P1 | None |
| 8 | PR-08 | Replace PlayerBar AnyView type erasure | P1 | None |
| 9 | PR-09 | Add @ObservedObject AppSettings in HomeView | P1 | None |
| 10 | PR-10 | Cache routineProgress on-demand instead of .onAppear | P1 | None |
| 11 | PR-11 | Add accessibilityReduceMotion check to ScrollRevealModifier | P2 | None |
| 12 | PR-12 | Remove Task wrapper from timer closure (main RunLoop already) | P2 | PR-03 |
| 13 | PR-13 | Move AVAudioSession.setCategory off main thread | P2 | None |
| 14 | PR-14 | Remove duplicate app icon from asset catalog | P2 | None |

---

## Detailed Task Specifications

### PR-01: Cache DateFormatter Instances

**Priority:** P0  
**Files:** `Revenge/Core/Extensions/Date+Extensions.swift`  
**Current Behavior:**  
```
Every call to gregorianString, hijriString, dayKey, timeString, and currentDayKey() 
allocates a fresh DateFormatter. DateFormatter initialization includes locale loading 
and calendar setup, costing 1-3ms per allocation. With timeString called 6× per second 
from countdown timer (plus property reads in HomeViewModel.init at line 62-63), 
this adds 6-18ms/second of allocation overhead.
```

**Target Behavior:**  
```
All DateFormatter instances are cached as static properties within Date extensions.
Each format pattern (gregorian, hijri, cache-key, time-only) gets one reusable 
formatter per thread if needed. No allocation overhead per call.
```

**Step-by-Step Instructions:**

1. Open `Revenge/Core/Extensions/Date+Extensions.swift`
2. Replace all DateFormatter allocations with static cached properties:
   - Create a static stored property `gregorianFormatter: DateFormatter` with format `"EEEE, MMMM d, yyyy"`
   - Create a static stored property `hijriFormatter: DateFormatter` with format `"d MMMM yyyy"` using Islamic calendar
   - Create a static stored property `dayKeyFormatter: DateFormatter` with format `"yyyy-MM-dd"` (already exists in HomeViewModel at line 122-127 — move to extensions and reuse)
   - Create a static stored property `timeFormatter: DateFormatter` with format `"h:mm a"`
3. Update `var gregorianString: String` to use the static formatter
4. Update `var hijriString: String` to use the static formatter
5. Update `var dayKey: String` to use the static formatter
6. Update `static func currentDayKey()` to use the static formatter
7. Update `var timeString: String` to use the static formatter
8. In HomeViewModel, remove the local `dayKeyFormatter` static at line 122-127 and call `Date().currentDayKey()` instead
9. Thread-safe consideration: Mark formatters as `@Sendable` or wrap access in `DispatchQueue.main.sync` if using from background threads (currently not, so simple static is safe)

**Verification:**
- Run HomeView onAppear → should create zero new DateFormatter instances
- Run 60 seconds of countdown → confirm timeString calls don't spike memory or CPU
- Profile Instruments → Time Profiler should show no DateFormatter initialization overhead in hot path
- Compare allocation timeline before/after: expect 6-18ms/s savings

**Dependencies:** None  
**Risk/Rollback:**
- Risk: Formatter state mutation if thread-unsafe modification occurs (low risk, formatters are read-only after init)
- Rollback: Revert to local allocations; no state loss

---

### PR-02: Cache JSONDecoder/JSONEncoder Instances

**Priority:** P0  
**Files:** `Revenge/Core/Services/APIService.swift` (line 32), `Revenge/Core/Services/CacheManager.swift` (line 152)  
**Current Behavior:**  
```
APIService.fetch() creates a fresh JSONDecoder on every API call (line 32).
CacheManager.save() creates a fresh JSONEncoder on every cache write (line 152).
JSONDecoder/JSONEncoder initialization loads locale data, date strategies, and keyPath 
caches. Costs 0.5-1.5ms per allocation. With 2-3 API calls per home load and cache 
writes on every routine refresh/bookmark toggle, this adds 1-5ms per user interaction.
```

**Target Behavior:**  
```
JSONDecoder and JSONEncoder are cached as static properties in APIService and CacheManager.
Both use default configuration (no custom date formatting or key strategies needed).
All calls reuse the same instance; no allocation overhead.
```

**Step-by-Step Instructions:**

1. Open `Revenge/Core/Services/APIService.swift`
2. Add two static properties to the APIService class:
   ```
   private static let decoder = JSONDecoder()
   private static let encoder = JSONEncoder()
   ```
3. In the `fetch<T>()` method at line 32, replace `JSONDecoder().decode(...)` with `Self.decoder.decode(...)`
4. Open `Revenge/Core/Services/CacheManager.swift`
5. Add a static property to the CacheManager class:
   ```
   private static let encoder = JSONEncoder()
   ```
6. At line 152, replace `JSONEncoder().encode(...)` with `CacheManager.encoder.encode(...)`
7. If CacheManager loads JSON (check `load()` methods), also add:
   ```
   private static let decoder = JSONDecoder()
   ```
   And update all JSONDecoder calls in load methods to use `CacheManager.decoder`
8. Verify no custom date formatters or KeyDecodingStrategies are set (they default to ISO8601 and useAsIs, which match the codebase)

**Verification:**
- Run full app flow: API fetch → decode → cache write → cache read
- Profile memory: expect flat allocations (no new decoder/encoder objects)
- Run 10 API calls in sequence → confirm no multi-MB allocation spikes
- Benchmark: measure before/after time for `fetchDailyAyah()` + cache write; expect 1-3ms savings per API call

**Dependencies:** None  
**Risk/Rollback:**
- Risk: Decoder/encoder state persisting across calls (unlikely; decoders are stateless)
- Rollback: Create new instances in each call; no data loss

---

### PR-03: Extract PrayerCountdownViewModel and Subview

**Priority:** P0  
**Files:** `Revenge/Features/Home/HomeView.swift`, `Revenge/Features/Home/HomeViewModel.swift`, and new file: `Revenge/Features/Home/PrayerCountdownViewModel.swift` + `Revenge/Features/Home/PrayerCountdownView.swift`  
**Current Behavior:**  
```
HomeViewModel publishes @Published var countdownText: String. Every second, the timer 
at line 273-282 mutates countdownText, triggering objectWillChange on HomeViewModel.
This causes the entire HomeView.body (line 11-113) to re-evaluate, including all 
siblings: dateHeader, streakCard, routineCard, dailyAyahCard, dailyHadithCard, all 
.scrollReveal modifiers, and IslamicPatternBackground Canvas redraw.
```

**Target Behavior:**  
```
Extract prayer countdown logic into a separate @MainActor ObservableObject 
called PrayerCountdownViewModel with @Published nextPrayerName, nextPrayerTime, 
countdownText. Create a dedicated PrayerCountdownView that observes only this 
sub-viewmodel. HomeView observes HomeViewModel and PrayerCountdownViewModel 
separately. When countdownText mutates, only PrayerCountdownView.body re-evaluates.
```

**Step-by-Step Instructions:**

1. Create new file `Revenge/Features/Home/PrayerCountdownViewModel.swift`
2. Copy the following methods/properties from HomeViewModel:
   - `@Published var nextPrayerName: String`
   - `@Published var nextPrayerTime: Date?`
   - `@Published var countdownText: String`
   - `private var timer: Timer?`
   - `private let locationService: LocationService`
   - `private let prayerTimesService: PrayerTimesService`
   - `private let settings: AppSettings`
   - `func loadPrayerCountdown()`
   - `private func updateNextPrayer(location:)`
   - `private func startCountdownTimer()`
3. Create a new `PrayerCountdownViewModel` class marked `@MainActor final class`:
   ```swift
   @MainActor
   final class PrayerCountdownViewModel: ObservableObject {
       @Published var nextPrayerName: String = ""
       @Published var nextPrayerTime: Date?
       @Published var countdownText: String = "--:--:--"
       
       private var timer: Timer?
       private let locationService: LocationService
       private let prayerTimesService: PrayerTimesService
       private let settings: AppSettings
       
       init(
           locationService: LocationService = .shared,
           prayerTimesService: PrayerTimesService = .shared,
           settings: AppSettings = .shared
       ) {
           self.locationService = locationService
           self.prayerTimesService = prayerTimesService
           self.settings = settings
       }
       
       func onAppear() {
           loadPrayerCountdown()
           startCountdownTimer()
       }
       
       func onDisappear() {
           timer?.invalidate()
       }
       
       private func loadPrayerCountdown() { ... }
       private func updateNextPrayer(location:) { ... }
       private func startCountdownTimer() { ... }
   }
   ```
4. Create new file `Revenge/Features/Home/PrayerCountdownView.swift`:
   ```swift
   struct PrayerCountdownView: View {
       @ObservedObject var viewModel: PrayerCountdownViewModel
       @Environment(\.colorScheme) private var colorScheme
       
       var body: some View {
           VStack(spacing: 6) {
               if !viewModel.nextPrayerName.isEmpty {
                   Text("Next: \(viewModel.nextPrayerName)")
                       .font(.subheadline)
                       .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
               }
               Text(viewModel.countdownText)
                   .font(.system(.largeTitle, design: .rounded, weight: .bold))
                   .foregroundStyle(Color.adaptivePrimary(colorScheme))
                   .monospacedDigit()
                   .accessibilityIdentifier("prayerCountdown")
           }
           .frame(maxWidth: .infinity)
           .padding()
           .background {
               ZStack {
                   Color.adaptiveCardSurface(colorScheme)
                   IslamicPatternBackground(colorScheme: colorScheme)
               }
           }
           .clipShape(RoundedRectangle(cornerRadius: 16))
           .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 8, y: 4)
       }
   }
   ```
5. In HomeViewModel, remove the four `@Published` properties, timer, and three methods (loadPrayerCountdown, updateNextPrayer, startCountdownTimer)
6. Update HomeView.body: replace `prayerCountdown` computed var with:
   ```swift
   @StateObject private var prayerCountdownVM = PrayerCountdownViewModel()
   
   var body: some View {
       // ... in the VStack ...
       PrayerCountdownView(viewModel: prayerCountdownVM)
           .scrollReveal(delay: 0.1)
   }
   ```
7. Add lifecycle calls to PrayerCountdownVM in HomeView:
   ```swift
   .onAppear { prayerCountdownVM.onAppear() }
   .onDisappear { prayerCountdownVM.onDisappear() }
   ```
8. Update HomeViewModel.onAppear() to remove `loadPrayerCountdown()` and `startCountdownTimer()` calls
9. Update HomeViewModel.onDisappear() to remove `timer?.invalidate()`

**Verification:**
- Launch HomeView → prayer countdown renders and ticks
- Scroll up/down HomeView → observe no lag in countdown animation
- Check Instruments Memory tab → no timer duplication
- Profile with Time Profiler → countdownText mutations no longer trigger HomeView body re-evaluation
- Render cycle: confirm only PrayerCountdownView.body re-evaluates every second, not HomeView.body

**Dependencies:** None (but should be done before PR-04 and PR-05)  
**Risk/Rollback:**
- Risk: PrayerCountdownViewModel lifecycle tied to HomeView; if HomeView is recreated, countdown resets (low risk if onAppear/onDisappear wired correctly)
- Rollback: Re-inline countdown into HomeViewModel; revert `prayerCountdown` computed var back

---

### PR-04: Schedule Timer on .common RunLoop Mode

**Priority:** P0  
**Files:** `Revenge/Features/Home/PrayerCountdownViewModel.swift` (new, from PR-03), `Revenge/Features/PrayerTimes/PrayerTimesViewModel.swift` (line 99-107)  
**Current Behavior:**  
```
Timer.scheduledTimer uses default RunLoop mode (.default). When user scrolls HomeView,
the RunLoop switches to .tracking mode to prioritize scroll events, pausing the timer.
Countdown visually freezes until scroll completes.
```

**Target Behavior:**  
```
Timer scheduled on RunLoop.Mode.common, which continues firing during scroll tracking.
Countdown animates smoothly while scrolling without visible pauses.
```

**Step-by-Step Instructions:**

1. Open `Revenge/Features/Home/PrayerCountdownViewModel.swift` (created in PR-03)
2. In the `startCountdownTimer()` method, change:
   ```swift
   timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
   ```
   to:
   ```swift
   let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
       // ... existing closure ...
   }
   RunLoop.main.add(timer, forMode: .common)
   self.timer = timer
   ```
3. Open `Revenge/Features/PrayerTimes/PrayerTimesViewModel.swift`
4. In the `startTimer()` method at line 99-107, apply the same change:
   ```swift
   private func startTimer() {
       let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
           Task { @MainActor in
               guard let self = self, let next = self.nextPrayer else { return }
               let remaining = next.time.timeIntervalSince(Date())
               self.countdownText = PrayerCountdownFormatter.format(remaining)
           }
       }
       RunLoop.main.add(timer, forMode: .common)
       self.timer = timer
   }
   ```

**Verification:**
- Launch HomeView with prayer countdown visible
- Scroll up/down rapidly in the ScrollView
- Confirm countdown text updates every ~1 second without pauses (even during active scroll)
- Compare before/after video: countdown should remain fluid while dragging

**Dependencies:** PR-03 (to avoid duplicate edits)  
**Risk/Rollback:**
- Risk: Timer now fires during scroll tracking; may cause micro-jank if countdown update is slow (unlikely; countdownText assignment is <1ms)
- Rollback: Revert to Timer.scheduledTimer(withTimeInterval:repeats:block:)

---

### PR-05: Invalidate Stale Timers Before Creating New Ones

**Priority:** P0  
**Files:** `Revenge/Features/Home/PrayerCountdownViewModel.swift` (new, from PR-03), `Revenge/Features/PrayerTimes/PrayerTimesViewModel.swift` (line 99-107)  
**Current Behavior:**  
```
If onAppear fires multiple times (tab switching, app backgrounding), new Timer objects 
are created without invalidating old ones. Multiple timers accumulate in memory, all 
updating countdownText simultaneously, causing jank and memory leaks.
```

**Target Behavior:**  
```
Before creating a new timer in startCountdownTimer/startTimer, first invalidate any 
existing timer. Only one timer ever exists at a time.
```

**Step-by-Step Instructions:**

1. Open `Revenge/Features/Home/PrayerCountdownViewModel.swift`
2. In `startCountdownTimer()`, add this line at the very beginning:
   ```swift
   private func startCountdownTimer() {
       timer?.invalidate()  // <-- add this line
       let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
           // ... rest of method ...
       }
       RunLoop.main.add(timer, forMode: .common)
       self.timer = timer
   }
   ```
3. Open `Revenge/Features/PrayerTimes/PrayerTimesViewModel.swift`
4. In `startTimer()`, add the same invalidation:
   ```swift
   private func startTimer() {
       timer?.invalidate()  // <-- add this line
       let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
           // ... rest of method ...
       }
       RunLoop.main.add(timer, forMode: .common)
       self.timer = timer
   }
   ```

**Verification:**
- Simulate multi-tap: repeatedly navigate away from and back to HomeView (or toggle tabs rapidly)
- Use Instruments Allocations → filter "Timer": confirm only one timer object exists at a time (not accumulating)
- No double-firing observed: countdown should tick once per second, not twice
- Memory stable: repeating nav away/back should not cause memory growth

**Dependencies:** None (but best paired with PR-03 and PR-04)  
**Risk/Rollback:**
- Risk: Calling invalidate() on nil timer (safe; NSTimer.invalidate() is idempotent)
- Rollback: Remove the `timer?.invalidate()` line

---

### PR-06: Add .drawingGroup() to IslamicPatternBackground Canvas

**Priority:** P1  
**Files:** `Revenge/Core/Extensions/View+Extensions.swift` (line 40-80)  
**Current Behavior:**  
```
IslamicPatternBackground renders an 8-pointed star grid using Canvas. Every time 
the Canvas is redrawn (which is every second due to HomeView.body re-evaluation 
from PR-01 being fixed), all ~90 star paths are recalculated and re-drawn.
Metal rendering cost: 5-10ms per frame on older devices.
```

**Target Behavior:**  
```
Wrap the Canvas in .drawingGroup(), which caches the render to an offscreen 
texture. Subsequent renders are blitted from cache instead of re-rasterizing 
paths. Or: pre-render background as a static Image asset instead of Canvas.
```

**Step-by-Step Instructions:**

**Option A: Add .drawingGroup() (simpler, backward-compatible)**

1. Open `Revenge/Core/Extensions/View+Extensions.swift`
2. In the `IslamicPatternBackground.body` computed property, wrap the Canvas in `.drawingGroup()`:
   ```swift
   struct IslamicPatternBackground: View {
       let colorScheme: ColorScheme

       var body: some View {
           Canvas { context, size in
               // ... all star drawing code unchanged ...
           }
           .drawingGroup()  // <-- add this
       }
   }
   ```
3. No other changes needed.

**Option B: Pre-render to Image (more optimal for static patterns)**

1. Create a helper method that renders the Canvas once and caches to a static Image:
   ```swift
   struct IslamicPatternBackground: View {
       let colorScheme: ColorScheme
       
       private static var cachedImage: UIImage?
       
       private func getCachedImage(size: CGSize) -> Image? {
           // Render once, store in static cache
           // Return Image(uiImage: cachedImage)
       }
       
       var body: some View {
           if let img = getCachedImage(size: CGSize(width: 400, height: 400)) {
               img.resizable().ignoresSafeArea()
           }
       }
   }
   ```
2. This is more complex but eliminates Canvas rendering entirely.

**Recommended:** Use Option A for simplicity and compatibility. Option B requires careful lifecycle management.

**Verification:**
- Launch HomeView with prayer countdown
- Run 30 seconds of countdown (30 .drawingGroup() renders if using Option A)
- Profile with Metal Debugger: confirm Canvas texture is cached, not re-rasterized every frame
- Measure CPU: expect 2-3ms/frame instead of 5-10ms/frame during countdown
- Visual check: background pattern still visible and crisp

**Dependencies:** Ideally after PR-03 (so HomeView.body stabilizes), but can be done independently  
**Risk/Rollback:**
- Risk: .drawingGroup() may slightly blur edges on some devices (usually imperceptible for geometric patterns)
- Rollback: Remove .drawingGroup() call

---

### PR-07: Cap scrollReveal State Nodes to Visible Items Only

**Priority:** P1  
**Files:** `Revenge/Features/Quran/ReadingView.swift` (line 30-35), `Revenge/Core/Extensions/View+Extensions.swift` (line 4-19)  
**Current Behavior:**  
```
Each ayah rendered in ReadingView gets a ScrollRevealModifier with @State var hasAppeared.
Surah Al-Baqarah has 286 ayahs. Rendering the entire surah creates 286 state slots 
in SwiftUI's state tree, even though only ~5-10 ayahs are visible at once.
State management overhead: slower onAppear/body re-evaluations, higher memory.
All 286 ayahs also get the 0.45s reveal animation, even those never scrolled to.
```

**Target Behavior:**  
```
Only apply scrollReveal animation to the first N visible ayahs (e.g., first 15).
Remaining ayahs either have no animation or use a simpler enter animation that 
doesn't require @State. Reduces state nodes from 286 to ~20 per surah.
```

**Step-by-Step Instructions:**

1. Open `Revenge/Features/Quran/ReadingView.swift`
2. Find the ForEach loop at line 30-35:
   ```swift
   ForEach(Array(viewModel.displayAyahs.enumerated()), id: \.element.id) { index, ayah in
       ayahCard(ayah, index: index)
           .id(ayah.numberInSurah)
           .scrollReveal(delay: reduceMotion ? 0 : 0.1)
   }
   ```
3. Update to conditionally apply scrollReveal only to first 15 ayahs:
   ```swift
   ForEach(Array(viewModel.displayAyahs.enumerated()), id: \.element.id) { index, ayah in
       ayahCard(ayah, index: index)
           .id(ayah.numberInSurah)
           .if(index < 15) { view in
               view.scrollReveal(delay: reduceMotion ? 0 : 0.1)
           }
   }
   ```
4. Add a helper extension to View if not already present:
   ```swift
   extension View {
       @ViewBuilder
       func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
           if condition {
               transform(self)
           } else {
               self
           }
       }
   }
   ```
5. Alternative: Use a simpler opacity transition for ayahs beyond index 15:
   ```swift
   .if(index >= 15) { view in
       view.opacity(1)  // Already loaded, no animation
   }
   ```

**Verification:**
- Open Surah Al-Baqarah (286 ayahs) in ReadingView
- Profile Instruments → Allocations/VM Tracker: compare state memory before/after (expect ~15-20 KB reduction)
- Scroll through first 20 ayahs: confirm smooth reveal animation
- Scroll to ayahs 100+: confirm no janky animation catch-up (no reveal animation applied)
- Render performance: expect no visible FPS improvement (state reduction is modest), but memory cleaner

**Dependencies:** None  
**Risk/Rollback:**
- Risk: Ayahs beyond index 15 appear instantly instead of animated (low impact; they're usually off-screen when reached)
- Rollback: Apply scrollReveal to all ayahs again

---

### PR-08: Replace PlayerBar AnyView Type Erasure

**Priority:** P1  
**Files:** `Revenge/Features/Quran/PlayerBar.swift` (line 14-17)  
**Current Behavior:**  
```
PlayerBar.body returns AnyView(EmptyView()) or AnyView(playerContent(...)).
AnyView type erasure destroys SwiftUI structural identity, forcing the entire 
PlayerBar to re-render (destroy and recreate) on every body re-evaluation, 
even when nowPlaying state hasn't changed.
```

**Target Behavior:**  
```
Use @ViewBuilder with conditional View composition instead of AnyView.
SwiftUI preserves identity, reuses views, and eliminates unnecessary recreations.
```

**Step-by-Step Instructions:**

1. Open `Revenge/Features/Quran/PlayerBar.swift`
2. Replace the body property (line 12-18):
   ```swift
   var body: some View {
       guard let nowPlaying = service.nowPlaying else {
           return AnyView(EmptyView())
       }
       return AnyView(playerContent(nowPlaying: nowPlaying))
   }
   ```
   with:
   ```swift
   @ViewBuilder
   var body: some View {
       if let nowPlaying = service.nowPlaying {
           playerContent(nowPlaying: nowPlaying)
       }
   }
   ```
3. No other changes needed. SwiftUI's @ViewBuilder automatically handles empty vs populated cases.

**Verification:**
- Open ReadingView with audio player
- Start playback: PlayerBar slides up smoothly
- Pause/resume multiple times: confirm bar doesn't flicker or redraw unnecessarily
- Use Instruments Core Animation → Color Blended Layers: expect yellow blending only on new content, not entire bar
- Memory profiling: expect slightly lower allocation churn during playback

**Dependencies:** None  
**Risk/Rollback:**
- Risk: @ViewBuilder can infer ambiguous View types in some edge cases (unlikely here; only two paths)
- Rollback: Revert to AnyView pattern

---

### PR-09: Add @ObservedObject AppSettings in HomeView

**Priority:** P1  
**Files:** `Revenge/Features/Home/HomeView.swift` (line 165-167)  
**Current Behavior:**  
```
HomeView reads AppSettings.shared.arabicFontSize directly in dailyAyahCard() (line 166) 
and dailyHadithCard() (line 251) without @ObservedObject subscription.
Changing font size in Settings does not reactively update HomeView because the binding 
to AppSettings.shared is not established.
```

**Target Behavior:**  
```
Add @ObservedObject var appSettings = AppSettings.shared at HomeView top level.
Use appSettings.arabicFontSize instead of AppSettings.shared.arabicFontSize.
When user changes font size, HomeView.body re-evaluates and applies new size.
```

**Step-by-Step Instructions:**

1. Open `Revenge/Features/Home/HomeView.swift`
2. Add @ObservedObject at the top of HomeView struct (after line 4):
   ```swift
   struct HomeView: View {
       @StateObject private var viewModel = HomeViewModel()
       @ObservedObject private var appSettings = AppSettings.shared  // <-- add this
       @Environment(\.colorScheme) private var colorScheme
       // ... rest of properties ...
   }
   ```
3. Replace `AppSettings.shared.arabicFontSize` with `appSettings.arabicFontSize`:
   - Line 166: change to `appSettings.arabicFontSize`
   - Line 251: change to `appSettings.arabicFontSize`
   - Line 172: change `AppSettings.shared.showTransliteration` to `appSettings.showTransliteration`
4. Verify AppSettings is properly @Published for all font-related properties (it should be; check `AppSettings.swift`)

**Verification:**
- Launch HomeView
- Open Settings
- Change "Arabic Font Size" slider
- Return to HomeView: confirm text size updates immediately without re-launching
- Change "Show Transliteration" toggle: confirm transliteration visibility updates
- No visual glitches: confirm no text clipping or layout thrashing

**Dependencies:** None  
**Risk/Rollback:**
- Risk: @ObservedObject AppSettings.shared creates a long-lived reference (low risk; AppSettings is already a singleton)
- Rollback: Revert to direct AppSettings.shared reads (settings won't update reactively)

---

### PR-10: Cache routineProgress On-Demand Instead of .onAppear

**Priority:** P1  
**Files:** `Revenge/Features/Home/HomeView.swift` (line 31), `Revenge/Features/Home/HomeViewModel.swift` (line 79-87)  
**Current Behavior:**  
```
RoutineCardView.onAppear calls viewModel.refreshRoutineProgress(), which loads routine 
data from cache (JSON decode) on every appearance of HomeView, even if routine data 
hasn't changed. Cache loads run on main thread, causing brief 1-2ms pause.
Called every time HomeView re-appears (tab switching, presentation), not just when 
routine data is actually stale.
```

**Target Behavior:**  
```
Load routineProgress on-demand using a @State flag or @ObservedObject that tracks 
whether data is fresh. Only reload if:
1. App has been backgrounded + returned (use app lifecycle notification)
2. Time has advanced past the routine transition time (e.g., Fajr → Dhuhr)
3. User explicitly refreshes

Otherwise, reuse cached value in memory.
```

**Step-by-Step Instructions:**

1. Open `Revenge/Features/Home/HomeViewModel.swift`
2. Add a new @Published flag and timestamp:
   ```swift
   @Published var lastRoutineRefreshTime: Date?
   ```
3. Update `refreshRoutineProgress()` to be time-aware:
   ```swift
   func refreshRoutineProgress(force: Bool = false) {
       let now = Date()
       let timeSinceLastRefresh = lastRoutineRefreshTime.map { now.timeIntervalSince($0) } ?? .infinity
       
       // Only refresh if forced or if >5 minutes have passed since last refresh
       guard force || timeSinceLastRefresh > 300 else { return }
       
       currentRoutineType = RoutineTimeHelper.currentRoutineType()
       let today = currentDayKey()
       if let routine = routineService.loadRoutine(type: currentRoutineType, for: today) {
           routineProgress = routine.completionPercentage
       } else {
           routineProgress = 0
       }
       lastRoutineRefreshTime = now
   }
   ```
4. In `onAppear()`, change from:
   ```swift
   refreshRoutineProgress()
   ```
   to:
   ```swift
   refreshRoutineProgress(force: false)  // on-demand, not forced
   ```
5. Keep the manual refresh in RoutineCardView.onAppear for first-time load:
   ```swift
   RoutineCardView(routineType: viewModel.currentRoutineType, progress: viewModel.routineProgress)
       .scrollReveal(delay: 0.08)
       .onAppear { viewModel.refreshRoutineProgress(force: true) }  // first time only
   ```
6. Add app lifecycle detection to force-refresh on foreground:
   ```swift
   func subscribeForegroundNotification() {
       NotificationCenter.default.addObserver(
           forName: UIApplication.willEnterForegroundNotification,
           object: nil,
           queue: .main
       ) { [weak self] _ in
           self?.refreshRoutineProgress(force: true)
       }
   }
   ```
   Call this in `onAppear()` or `init()`

**Verification:**
- Launch HomeView: routine progress loads on first appearance
- Navigate away and back to HomeView: confirm progress does NOT reload (should reuse cached value for <5 minutes)
- Wait 5+ minutes and return: confirm progress reloads
- Force refresh via SwiftUI refresh gesture: confirm progress updates
- Background app 1 minute, return: confirm progress reloads (due to foreground notification)
- No main-thread stalls: measure HomeView.onAppear() duration before/after

**Dependencies:** None  
**Risk/Rollback:**
- Risk: Stale routine progress if user manually updates routine but waits <5 minutes before returning to HomeView (low risk; 5 min is reasonable cache TTL)
- Rollback: Revert to unconditional `refreshRoutineProgress()` in onAppear

---

### PR-11: Add accessibilityReduceMotion Check to ScrollRevealModifier

**Priority:** P2  
**Files:** `Revenge/Core/Extensions/View+Extensions.swift` (line 4-19)  
**Current Behavior:**  
```
ScrollRevealModifier always applies 0.45s .easeOut animation regardless of user's 
accessibility settings. Users with "Reduce Motion" enabled experience unwanted animations, 
violating accessibility guidelines (WCAG 2.1 Animation from Interactions).
```

**Target Behavior:**  
```
Check @Environment(\.accessibilityReduceMotion) in ScrollRevealModifier.
If enabled, skip animation or use instant opacity/offset change.
If disabled, apply normal animation.
```

**Step-by-Step Instructions:**

1. Open `Revenge/Core/Extensions/View+Extensions.swift`
2. Update ScrollRevealModifier:
   ```swift
   struct ScrollRevealModifier: ViewModifier {
       let delay: Double
       @State private var hasAppeared = false
       @Environment(\.accessibilityReduceMotion) private var reduceMotion  // <-- add this

       func body(content: Content) -> some View {
           content
               .opacity(hasAppeared ? 1 : 0)
               .offset(y: hasAppeared ? 0 : 20)
               .animation(
                   reduceMotion ? .none : .easeOut(duration: 0.45).delay(delay),
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

**Verification:**
- Open Settings → Accessibility → Display & Text Size → Reduce motion toggle ON
- Launch HomeView: confirm cards appear instantly without animation
- Toggle Reduce motion OFF in Settings, relaunch: confirm cards animate normally
- Test on ReadingView (many scrollReveal calls): all should respect the toggle

**Dependencies:** None  
**Risk/Rollback:**
- Risk: None; animation is optional enhancement
- Rollback: Remove reduceMotion check, always animate

---

### PR-12: Remove Task Wrapper from Timer Closure

**Priority:** P2  
**Files:** `Revenge/Features/Home/PrayerCountdownViewModel.swift` (from PR-03), `Revenge/Features/PrayerTimes/PrayerTimesViewModel.swift` (line 100-107)  
**Current Behavior:**  
```
Timer closure wraps work in Task { @MainActor in ... }. Timer.scheduledTimer already 
fires on main RunLoop, so the Task wrapper is overhead:
- Task allocation (~100µs per tick × 60 ticks/min = 6ms/minute overhead)
- Unnecessary context switching in Swift concurrency runtime
- @MainActor assertion is redundant (already on main thread)
```

**Target Behavior:**  
```
Remove Task wrapper. Call countdownText assignment directly in timer closure.
Task is still useful if background work is needed, but here it's purely synchronous 
main-thread assignment.
```

**Step-by-Step Instructions:**

1. Open `Revenge/Features/Home/PrayerCountdownViewModel.swift` (created in PR-03)
2. In `startCountdownTimer()`, change from:
   ```swift
   timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
       Task { @MainActor in
           guard let self = self, let target = self.nextPrayerTime else { return }
           self.countdownText = Date().timeRemaining(to: target)
           if target <= Date() {
               self.loadPrayerCountdown()
           }
       }
   }
   ```
   to:
   ```swift
   timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
       guard let self = self, let target = self.nextPrayerTime else { return }
       self.countdownText = Date().timeRemaining(to: target)
       if target <= Date() {
           self.loadPrayerCountdown()
       }
   }
   ```
3. Open `Revenge/Features/PrayerTimes/PrayerTimesViewModel.swift`
4. In `startTimer()`, change from:
   ```swift
   timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
       Task { @MainActor in
           guard let self = self, let next = self.nextPrayer else { return }
           let remaining = next.time.timeIntervalSince(Date())
           self.countdownText = PrayerCountdownFormatter.format(remaining)
       }
   }
   ```
   to:
   ```swift
   let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
       guard let self = self, let next = self.nextPrayer else { return }
       let remaining = next.time.timeIntervalSince(Date())
       self.countdownText = PrayerCountdownFormatter.format(remaining)
   }
   RunLoop.main.add(timer, forMode: .common)
   self.timer = timer
   ```

**Verification:**
- Launch HomeView and PrayerTimesView
- Verify countdown updates correctly (no regression)
- Profile with Instruments → System Trace: compare Task allocation rate before/after (expect lower allocation count)
- CPU: expect minimal difference (Task overhead is small but measurable)
- No crashes: confirm app stays stable after repeated countdown ticks

**Dependencies:** PR-03 (for PrayerCountdownViewModel), but PR-12 can be applied to PrayerTimesViewModel independently  
**Risk/Rollback:**
- Risk: None; timer closure is always on main thread
- Rollback: Add Task wrapper back

---

### PR-13: Move AVAudioSession.setCategory Off Main Thread

**Priority:** P2  
**Files:** `Revenge/Features/Quran/AudioPlayerService.swift` (line 106-111)  
**Current Behavior:**  
```
AudioPlayerService.init() calls AVAudioSession.sharedInstance().setCategory(...) on 
the main thread. AVAudioSession.setCategory involves audio hardware configuration and 
lock acquisition, blocking the main thread for 2-5ms.
If AudioPlayerService is initialized before HomeView loads, this causes brief app 
unresponsiveness on app launch.
```

**Target Behavior:**  
```
Defer AVAudioSession.setCategory to a background DispatchQueue (global .userInitiated).
Audio session is then ready before playback actually starts (eager init, async config).
Main thread unblocked on app launch.
```

**Step-by-Step Instructions:**

1. Open `Revenge/Features/Quran/AudioPlayerService.swift`
2. Find the init() method (line 106-111)
3. Wrap the AVAudioSession setup in a background task:
   ```swift
   private init() {
       // ... other init code ...
       
       // Configure audio session asynchronously to avoid blocking main thread
       DispatchQueue.global(qos: .userInitiated).async {
           let session = AVAudioSession.sharedInstance()
           try? session.setCategory(.playback, mode: .default, options: .defaultToSpeaker)
           try? session.setActive(true, options: .notifyOthersOnDeactivation)
       }
   }
   ```
4. No other changes needed; audio playback will handle any race conditions gracefully.

**Verification:**
- Profile app launch: measure time to HomeView.body rendered (expect 1-3ms faster)
- Start audio playback within 1 second of app launch: confirm playback works (audio session ready in time)
- Play audio normally: no regressions
- Test on iPhone 8 or older (slower devices): measure launch time improvement more clearly

**Dependencies:** None  
**Risk/Rollback:**
- Risk: If user starts playback immediately on app launch (<1s), audio session might not be configured yet (very low risk; async task completes within 100ms)
- Rollback: Move setCategory back to init() on main thread

---

### PR-14: Remove Duplicate App Icon from Asset Catalog

**Priority:** P2  
**Files:** `Revenge/Assets.xcassets/AppIcon.appiconset/`  
**Current Behavior:**  
```
Asset catalog contains two identical 84KB PNG files for the same app icon slot 
(exact duplicate, same content). Wastes ~84KB in the final app binary.
```

**Target Behavior:**  
```
Remove one of the duplicate PNG files. Retain only one copy per icon slot.
```

**Step-by-Step Instructions:**

1. Open Xcode project
2. Navigate to Assets.xcassets → AppIcon.appiconset
3. Identify the two identical PNG files (likely named something like `icon-120@2x.png` and `icon-120@2x-1.png` or similar)
4. Delete one of the duplicates:
   - Right-click the duplicate file in the asset browser
   - Select "Delete" → confirm
5. Verify the remaining icon is assigned to all required slots (1x, 2x, 3x, iPad, etc.)
6. Build and verify app icon displays correctly on simulator and device

**Verification:**
- Run `ls -la Revenge/Assets.xcassets/AppIcon.appiconset/` to confirm only one of each icon size remains
- Launch app: confirm app icon displays correctly on home screen
- Check file size: `du -h Revenge/Assets.xcassets/AppIcon.appiconset/` should be ~42KB instead of ~84KB (rough estimate)
- Build app and verify binary size reduced slightly

**Dependencies:** None  
**Risk/Rollback:**
- Risk: If wrong icon deleted, app icon might not display (caught immediately in build)
- Rollback: Restore the deleted file from git or re-add it to xcassets

---

## Execution Timeline

### Sprint 2 (Week 1-2)

These are foundational, highest-impact tasks:

1. **PR-01** (2 hours) — Cache DateFormatter instances
2. **PR-02** (2 hours) — Cache JSONDecoder/JSONEncoder
3. **PR-03** (4 hours) — Extract PrayerCountdownViewModel and subview
4. **PR-05** (1 hour) — Invalidate stale timers (paired with PR-03)
5. **PR-04** (1 hour) — Schedule timer on .common RunLoop (paired with PR-03)

**Rationale:** These 5 tasks unblock the most critical rendering issue (HomeView re-evaluating every second). Completing them first will show immediate FPS improvement and set a foundation for remaining work.

### Sprint 2 (Week 2-3)

Mid-tier fixes with solid ROI:

6. **PR-06** (1 hour) — Add .drawingGroup() to Canvas background
7. **PR-09** (1 hour) — Add @ObservedObject AppSettings
8. **PR-08** (1 hour) — Replace PlayerBar AnyView type erasure
9. **PR-10** (2 hours) — Cache routineProgress on-demand
10. **PR-11** (1 hour) — Add accessibilityReduceMotion check

**Rationale:** These improve perceived smoothness and accessibility without major refactoring.

### Sprint 3 (Week 1)

Lower-priority cleanup:

11. **PR-07** (2 hours) — Cap scrollReveal state nodes
12. **PR-12** (1 hour) — Remove Task wrapper from timer
13. **PR-13** (1 hour) — Move AVAudioSession.setCategory off main thread
14. **PR-14** (30 min) — Remove duplicate app icon

**Rationale:** These have smaller impact but improve code cleanliness and memory footprint.

---

## Verification & Rollout Strategy

### Testing Checklist

- [ ] **Instruments Profiling**
  - Time Profiler: DateFormatter/JSONDecoder allocation rate should drop 80%
  - Core Animation: PlayerBar should show yellow blending only on playback state change, not every frame
  - Memory: No timer stacking; allocations stable during tab switching
  - Energy: No increase in CPU wake-ups or background activity

- [ ] **Functional Testing**
  - HomeView: Countdown ticks smoothly while scrolling (PR-04)
  - HomeView: Tap settings, change font size → returns to home, text size updates immediately (PR-09)
  - PrayerTimesView: Countdown updates during scroll (PR-04)
  - ReadingView: Surah with 286 ayahs loads without memory spike (PR-07)
  - ReadingView: Audio player starts/stops smoothly (PR-08, PR-12, PR-13)
  - Accessibility: Device set to "Reduce motion" ON → all animations disabled (PR-11)

- [ ] **Regression Testing**
  - No new crashes during app launch or background/foreground transitions
  - Widget sync still works (should not be affected by any changes)
  - Prayer notifications still fire on time (PR-04 should not affect notification scheduling)

### Rollout Plan

1. **Code Review:** Each task peer-reviewed before merge to main
2. **Branch:** Create feature branches per task (e.g., `feature/pr-01-dateformatter-cache`)
3. **Testing:** Run full test suite before merging
4. **Release:** Batch tasks into a single release build or stagger across two releases if needed
5. **Monitoring:** Track crash rates and performance metrics (DNF, FPS, memory) post-release

---

## Summary

This plan addresses 14 distinct performance bottlenecks across rendering, memory management, and accessibility. The highest-priority tasks (PR-01 through PR-05) directly eliminate the root cause of HomeView re-rendering every second, delivering the most visible improvement in responsiveness. Remaining tasks provide incremental gains in memory efficiency, accessibility compliance, and code cleanliness.

**Expected Impact:**
- **FPS:** HomeView scrolling 30→60 FPS (on older devices)
- **Jank:** Prayer countdown no longer freezes during scroll
- **Memory:** ~150KB savings (eliminated timer duplication, reduced state nodes)
- **Accessibility:** Animations respect user preferences (WCAG 2.1 compliant)
- **Responsiveness:** App launch 1-3ms faster, no main-thread stalls from audio session init

All tasks are structured for independent review and testing. Begin with Sprint 2 tasks for maximum impact.

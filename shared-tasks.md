# Shared Tasks: Claude Code + Codex
**Project:** Kheir (Revenge) iOS App  
**Created:** 2026-05-08  
**Branch:** `feature/sprint-1-engagement`  
**Last Updated:** 2026-05-08 by Claude Code

---

## How This File Works

Both Claude Code and Codex read/write this file to coordinate async and sync work.

**Rules:**
1. Before starting a task, set status to `IN PROGRESS` and add your agent name
2. When done, set status to `DONE` and note what changed (files, commit hash)
3. If blocked, set `BLOCKED` with reason
4. Never work on a task another agent has `IN PROGRESS`
5. Update `Last Updated` line at top when modifying this file

**Status Legend:**
- `TODO` — Available for pickup
- `IN PROGRESS [agent]` — Being worked on
- `REVIEW` — Done, needs verification by other agent
- `BLOCKED [reason]` — Cannot proceed
- `DONE` — Complete and verified

---

## Current Uncommitted Work

CacheManager actor migration + async/await propagation across entire codebase (25 files changed, 576 insertions, 485 deletions). This must be committed before branching new work.

**Action:** Commit current changes before starting new tasks.

---

## Team Assignments

### Team A: Claude Code
**Strengths:** Architecture, concurrency, complex refactors, multi-file changes, planning  
**Primary domains:** Concurrency Safety, Architecture/DI, Performance/Rendering

### Team B: Codex
**Strengths:** Targeted fixes, test writing, isolated module work, code cleanup  
**Primary domains:** QA/Accessibility, API/Data Layer, isolated feature tasks

---

## Active Sprint Tasks

### P0 — Blocking (Must complete first)

| ID | Task | Plan Ref | Status | Agent | Notes |
|----|------|----------|--------|-------|-------|
| ST-01 | Commit CacheManager actor migration | — | DONE | Claude Code | Committed as 64f7e27 |
| ST-02 | Fix 4 failing UI tests | QA-01 | IN PROGRESS [Codex] | Codex | Blocks release. See `RevengeUITests/RevengeUITests.swift` |
| ST-03 | Fix CacheManagerTests flaky shared state | QA-02 | DONE | Claude Code | Already isolated: unique IDs, cleanup, .serialized |
| ST-04 | Fix MockAPIService @unchecked Sendable sync | QA-03 | DONE | Claude Code | Already has NSLock synchronization |

### P1 — High Impact

| ID | Task | Plan Ref | Status | Agent | Notes |
|----|------|----------|--------|-------|-------|
| ST-05 | PrayerTimesService Sendable conformance | CS-04 | DONE | Claude Code | Removed @unchecked — no mutable state |
| ST-06 | NotificationService Sendable conformance | CS-05 | DONE | Claude Code | Removed @unchecked — no mutable state |
| ST-07 | AppSettings @MainActor isolation | CS-06 | DONE | Claude Code | Added @MainActor, build verified |
| ST-08 | Enhance APIError with HTTP status + DecodingError | DL-04 | DONE | Claude Code | Added statusCode and DecodingError associated values |
| ST-09 | Implement cache eviction policy | DL-05 | DONE | Claude Code | 30-day eviction for daily_ayah/hadith/routine files |
| ST-10 | Optimize bookmark lookup with in-memory index | DL-06 | DONE | Claude Code | Set-based O(1) ayahBookmarkIndex |
| ST-11 | Schedule timer on .common RunLoop mode | PR-04 | DONE | Claude Code | Already implemented in PrayerCountdownViewModel:83 |
| ST-12 | Invalidate stale timers before creating new | PR-05 | DONE | Claude Code | Already implemented in PrayerCountdownViewModel:73 |
| ST-13 | Complete ReadingViewModel DI (constructor injection) | AD-02 | DONE | Claude Code | Injected cache, api, audioPlayer, settings |
| ST-14 | Complete SurahListViewModel DI | AD-03 | DONE | Claude Code | Injected cache, settings |

### P2 — Medium Impact

| ID | Task | Plan Ref | Status | Agent | Notes |
|----|------|----------|--------|-------|-------|
| ST-15 | Add `.drawingGroup()` to IslamicPatternBackground | PR-06 | DONE | Claude Code | Added to Canvas in View+Extensions.swift |
| ST-16 | Cap scrollReveal state nodes to visible items | PR-07 | DONE | Claude Code | Capped to first 15 ayahs in ReadingView:198 |
| ST-17 | Fix PrayerTimesViewModel singleton hardcoding | AD-04 | DONE | Claude Code | DI for LocationService, PrayerTimesService, NotificationService, AppSettings |
| ST-18 | Fix PrayerTimesViewModel timer pattern | AD-05 | DONE | Claude Code | Aligned with PrayerCountdownVM: .common RunLoop, invalidate-before-create, nil on disappear |
| ST-19 | Add accessibility labels to HomeView cards | QA-04 | DONE | Claude Code | Ayah share + hadith bookmark/share labels |
| ST-20 | Fix PrayerTime.id instability in ForEach | QA-05 | DONE | Claude Code | Changed from UUID to name-based stable ID |
| ST-21 | Replace deprecated Map API in MasjidFinderView | QA-06 | DONE | Claude Code | New Map + Annotation content builder |
| ST-22 | Placeholder App Store URL blocks launch | DL-03 | TODO | — | Needs Abdul's input |
| ST-23 | Replace print() with os.Logger | QA-10 | DONE | Claude Code | All 15 print() → os.Logger across 8 files |
| ST-24 | Remove duplicate selectedMasjid state | QA-07 | DONE | Claude Code | Removed unused @Published from ViewModel |
| ST-25 | Add reduceMotion to ScrollRevealModifier | QA-11 | DONE | Claude Code | Respects accessibilityReduceMotion |
| ST-26 | Replace DispatchQueue.main.asyncAfter | QA-13 | DONE | Claude Code | Task.sleep in ReadingView + StreakCardView |
| ST-27 | Replace PlayerBar AnyView type erasure | PR-08 | DONE | Claude Code | if-let instead of guard+AnyView |
| ST-28 | Fix SurahListViewModel cache-only guard | DL-09 | DONE | Claude Code | Always fetch from network, show loading only when empty |
| ST-29 | Add city geocoding input validation | QA-09 | DONE | Claude Code | Trim + min 2 chars in LocationService |

---

## Completed Tasks

| ID | Task | Agent | Completed | Commit |
|----|------|-------|-----------|--------|
| — | CacheManager actor conversion (CS-01) | Claude Code | 2026-04-29 | eca3931 |
| — | Protocol async conversion (CS-02) | Claude Code | 2026-04-29 | eca3931 |
| — | Model Sendable conformance (CS-07) | Claude Code | 2026-04-28 | eca3931 |
| — | Cache DateFormatter singletons (PR-01) | Claude Code | 2026-04-28 | eca3931 |
| — | Cache JSONDecoder/Encoder singletons (PR-02) | Claude Code | 2026-04-28 | eca3931 |
| — | Extract PrayerCountdownViewModel (PR-03) | Claude Code | 2026-04-28 | eca3931 |
| — | Force unwrap fix fetchRandomHadith (DL-01) | Claude Code | 2026-04-28 | eca3931 |
| — | Widget Calendar force unwrap fix (DL-02) | Claude Code | 2026-04-28 | eca3931 |
| — | CacheManaging protocol segregation (AD-01) | Claude Code | 2026-04-29 | eca3931 |
| — | BookmarksVM + JournalVM DI (AD-03 partial) | Claude Code | 2026-04-29 | uncommitted |

---

## Coordination Log

| Date | Agent | Action |
|------|-------|--------|
| 2026-05-08 | Claude Code | Created shared-tasks.md, mapped all plan tasks to shared IDs |
| 2026-05-08 | Codex | Started ST-02: Fix 4 failing UI tests (QA-01) |
| 2026-05-08 | Claude Code | Committed ST-01 (64f7e27). Completed ST-05, ST-06, ST-07 (Sendable + @MainActor). ST-11, ST-12 already done in code. Build verified. |
| 2026-05-08 | Claude Code | Completed ST-15 (.drawingGroup), ST-16 (scrollReveal cap), ST-17 (PrayerTimesVM DI), ST-18 (timer pattern fix). Build verified. |
| 2026-05-08 | Claude Code | Sprint completion: ST-03/04 verified, ST-08–10 (APIError/eviction/index), ST-13/14 (DI), ST-19–21 (a11y/PrayerTime.id/MapKit), ST-23–29 (Logger/cleanup/PlayerBar/ScrollReveal). All build verified. |

---

## Dependency Graph (Critical Path)


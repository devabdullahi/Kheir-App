# Shared Tasks: Claude Code + Codex
**Project:** Kheir (Revenge) iOS App  
**Created:** 2026-05-08  
**Branch:** `feature/sprint-1-engagement`  
**Last Updated:** 2026-05-08 by Codex

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
| ST-01 | Commit CacheManager actor migration | — | TODO | Claude Code | 25 files, async/await propagation |
| ST-02 | Fix 4 failing UI tests | QA-01 | IN PROGRESS [Codex] | Codex | Blocks release. See `RevengeUITests/RevengeUITests.swift` |
| ST-03 | Fix CacheManagerTests flaky shared state | QA-02 | TODO | Codex | Shared state between test runs |
| ST-04 | Fix MockAPIService @unchecked Sendable sync | QA-03 | TODO | Codex | Thread-safety in test mocks |

### P1 — High Impact

| ID | Task | Plan Ref | Status | Agent | Notes |
|----|------|----------|--------|-------|-------|
| ST-05 | PrayerTimesService Sendable conformance | CS-04 | TODO | Claude Code | Independent concurrency task |
| ST-06 | NotificationService Sendable conformance | CS-05 | TODO | Claude Code | Independent concurrency task |
| ST-07 | AppSettings @MainActor isolation | CS-06 | TODO | Claude Code | Depends on ST-01 committed |
| ST-08 | Enhance APIError with HTTP status + DecodingError | DL-04 | TODO | Codex | Isolated to APIService layer |
| ST-09 | Implement cache eviction policy | DL-05 | TODO | Codex | Daily content files accumulate |
| ST-10 | Optimize bookmark lookup with in-memory index | DL-06 | TODO | Codex | Currently O(n) per check |
| ST-11 | Schedule timer on .common RunLoop mode | PR-04 | TODO | Claude Code | Depends on PR-03 (done) |
| ST-12 | Invalidate stale timers before creating new | PR-05 | TODO | Claude Code | Timer stacking in memory |
| ST-13 | Complete ReadingViewModel DI (constructor injection) | AD-02 | TODO | Codex | Partial — uses protocol type, not injected |
| ST-14 | Complete SurahListViewModel DI | AD-03 | TODO | Codex | Uses protocol type, not yet injected |

### P2 — Medium Impact

| ID | Task | Plan Ref | Status | Agent | Notes |
|----|------|----------|--------|-------|-------|
| ST-15 | Add `.drawingGroup()` to IslamicPatternBackground | PR-06 | TODO | Codex | Single file, rendering perf |
| ST-16 | Cap scrollReveal state nodes to visible items | PR-07 | TODO | Claude Code | 286+ nodes for Al-Baqarah |
| ST-17 | Fix PrayerTimesViewModel singleton hardcoding | AD-04 | TODO | Claude Code | + LocationService protocol |
| ST-18 | Extract PrayerCountdownManager | AD-05 | TODO | Claude Code | Eliminate Home/PrayerTimes duplication |
| ST-19 | Add accessibility labels to HomeView cards | QA-04 | TODO | Codex | WCAG compliance |
| ST-20 | Fix PrayerTime.id instability in ForEach | QA-05 | TODO | Codex | SwiftUI diffing issue |
| ST-21 | Replace deprecated Map API in MasjidFinderView | QA-06 | TODO | Codex | MapKit deprecation |
| ST-22 | Placeholder App Store URL blocks launch | DL-03 | TODO | — | Needs Abdul's input |
| ST-23 | Replace print() with os.Logger | QA-10 | TODO | Codex | Low priority cleanup |

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

---

## Dependency Graph (Critical Path)


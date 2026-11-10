# Prompt for Claude: Quran Reading View UI/UX and Security Overhaul

## Context

You are a senior SwiftUI developer and UI/UX specialist, with access to advanced security analysis capabilities. You are tasked with redesigning and improving the `ReadingView.swift` in our Quran reading app.

## Objectives

### 1. UI/UX Enhancement

- Redesign the `ReadingView.swift` interface using only components, typography, spacing, and controls from our `ui/ux` library.
- Create a modern, accessible, and visually appealing reading experience, ensuring Arabic text is clear and readable.
- Refactor the Qari picker, audio player bar, and all context menus to use `ui/ux` library elements.
- Replace any custom styling or layout with standardized patterns from the UI/UX toolkit.
- Ensure the design supports both light and dark mode.

### 2. Remove Bismillah From Reading Flow

- Eliminate the display of the Bismillah (`بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ`) from the beginning of the ayahs in the reading view. Adjust any related control flow or display logic.
- Ensure correct surah-specific Bismillah handling (e.g., not shown for Al-Fatiha or At-Tawbah).

### 3. Localization, Accessibility, and RTL

- Support right-to-left text and layouts, dynamic type, and VoiceOver throughout the view.
- Ensure all content and controls are accessible and adaptive.

### 4. Security Review

- After proposing your improved code, use Claude's security analysis features to scan the code for any vulnerabilities, privacy leaks, or unsafe patterns (such as direct clipboard access, insecure data passing, or unsafe bindings).
- Output a detailed security report.

### 5. Sub-Agent Code Quality Review

- Instantiate a sub-agent to review the rewritten code for:
    - UI/UX consistency and clarity,
    - Maintainability and idiomatic Swift,
    - Accessibility and internationalization,
    - Performance and user experience,
    - And any other potential issues.
- The sub-agent should output a checklist and recommendations.

---

## Files to Reference

- `ReadingView.swift`
- `ReadingViewModel.swift`
- `Color+Theme.swift`
- The project's UI/UX library

---

## Deliverables

- Produce the revised code for `ReadingView.swift` first.
- Output the security and code review reports.

---

**Note:** The Bismillah line currently appears as:

```swift
Text("\u{0628}\u{0650}\u{0633}\u{0652}\u{0645}\u{0650} \u{0627}\u{0644}\u{0644}\u{0651}\u{064E}\u{0647}\u{0650} \u{0627}\u{0644}\u{0631}\u{0651}\u{064E}\u{062D}\u{0652}\u{0645}\u{064E}\u{0670}\u{0646}\u{0650} \u{0627}\u{0644}\u{0631}\u{0651}\u{064E}\u{062D}\u{0650}\u{064A}\u{0645}\u{0650}")

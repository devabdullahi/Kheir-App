# Kheir App — UI Overhaul Design Spec

**Direction:** Sacred Garden
**Scope:** Full UI overhaul — 8 upgrade areas
**Date:** 2026-05-17

---

## 1. Sacred Garden Design System

Foundation colors, typography, spacing, and card styles for the entire app.

### Color Palette — Dark Mode (Primary)

| Token | Hex | Usage |
|-------|-----|-------|
| `background` | `#0A0F1E` | App background |
| `cardSurface` | `#0D1F1A` | Standard card fill |
| `cardElevated` | `#163D2E` | Elevated/featured card fill |
| `primary` | `#22573C` | Primary actions, active states |
| `goldAccent` | `#D4A847` | Accent highlights, active prayer, overlines |
| `primaryText` | `#E8DCC8` | Primary text |
| `secondaryText` | `#E8DCC8` at 50% | Secondary/caption text |
| `border` | `#22573C` at 20% | Card borders |
| `goldBorder` | `#D4A847` at 15% | Featured card borders |
| `destructive` | `#DC2626` | Delete actions |

### Color Palette — Light Mode

| Token | Hex | Usage |
|-------|-----|-------|
| `background` | `#F5F0E8` | App background (warm parchment) |
| `cardSurface` | `#FFFFFF` | Standard card fill |
| `cardElevated` | `#F8F5EF` | Elevated card fill |
| `primary` | `#1A6B42` | Primary actions |
| `goldAccent` | `#B8922E` | Accent highlights |
| `primaryText` | `#1A2A22` | Primary text |
| `secondaryText` | `#5A6B62` | Secondary text |
| `border` | `#1A6B42` at 10% | Card borders |
| `destructive` | `#DC2626` | Delete actions |

### Typography Scale

| Style | Size | Weight | Usage |
|-------|------|--------|-------|
| Large Title | 28pt | Bold (.rounded) | Screen titles |
| Title 1 | 22pt | Semibold | Section headers |
| Title 2 | 18pt | Semibold | Card titles |
| Headline | 16pt | Medium | Emphasized body |
| Body | 15pt | Regular | Main content |
| Caption | 13pt | Regular | Secondary info |
| Overline | 11pt | Regular, uppercase, 1.5pt tracking | Labels (gold colored) |
| Arabic | Scheherazade New, configurable (default 28pt) | Regular | Quranic text |
| Tabular | .monospacedDigit | Various | Times, countdowns |

### Card Style

- **Standard card**: `cardSurface` background, `border` 1px, 20px corner radius, `backdrop-filter: blur(16px)`, shadow `0 8px 32px rgba(0,0,0,0.2)`, inner highlight `inset 0 1px 0 rgba(255,255,255,0.03)`
- **Featured card**: Same as standard + `goldBorder` border, inner highlight tinted gold `rgba(212,168,71,0.05)`. Used for daily Ayah, active prayer, streaks.
- **Glassmorphism card** (over sky): `cardSurface` at 60-70% opacity, stronger blur (20px), used on Home header and Prayer Times tab

### Spacing

- 8pt base grid (4pt for fine adjustments)
- Card padding: 20px
- Card gap: 12px
- Section gap: 24px
- Screen horizontal inset: 16px

---

## 2. Dynamic Sky & Sun Animation System

Real-time environmental background that continuously evolves throughout the day, synced to prayer times.

### Architecture

- **`DynamicSkyView`** — SwiftUI `Canvas` component rendering sky gradient, sun/moon, stars, ambient glow
- **`SkyEngine`** — Observable class that calculates current `SkyState` from prayer times + current time
- **`SkyState`** — Model containing: gradient color stops (3-4 per period), sun/moon position (x,y normalized), sun size, glow intensity, glow color, star opacity, color temperature

### Real-Time Behavior

- `TimelineView(.periodic(every: 30))` drives updates (every 30 seconds)
- Low Power Mode: update interval increases to 60 seconds
- Continuous interpolation between adjacent prayer period states (not stepped)
- Sun position follows arc path calculated as ratio of elapsed time within current period

### Sun Arc Path

| Period | Sun Position | Behavior |
|--------|-------------|----------|
| Fajr | Bottom center, at horizon | Rising, soft glow |
| Sunrise | Lower-mid, ascending | Brightening, warm |
| Dhuhr | Top center (zenith) | Maximum brightness, white-hot |
| Asr | Upper-right, descending | Warming color temperature |
| Maghrib | Bottom center, at horizon | Setting, orange-red, fading |
| Isha | Hidden (moon top-right) | Stars fade in, minimal glow |

### 6 Prayer Atmospheres

**Fajr** — Gradient: `#0B1420` → `#1A2744` → `#3A5A7A` → `#D4926B` → `#E8B87A`. Sun: low, soft warm glow (opacity 0.85). Cool dawn tones.

**Sunrise** — Gradient: `#4A7FA5` → `#7AB5D4` → `#C4D8E0` → `#F5D5A0` → `#F0C070`. Sun: rising, brightening. Morning warmth.

**Dhuhr** — Gradient: `#1976A8` → `#2E98C4` → `#5AB8D4` → `#8AD0E0` → `#B0E0EC`. Sun: zenith, maximum size and glow. Brightest state. Strong white light with subtle yellow.

**Asr** — Gradient: `#3A7A9A` → `#5A9AB4` → `#8ABAC4` → `#C4B88A` → `#D4A86B`. Sun: descending right of center. Warmer golden tone, softer light.

**Maghrib** — Gradient: `#2A1A3A` → `#8B2E1A` → `#D4694A` → `#E8A87A` → `#F0C88A`. Sun: at horizon, deep orange-red. Dramatic golden hour. Rapid fading.

**Isha** — Gradient: `#050A14` → `#0A1020` → `#0D1A2A` → `#1A2744`. Moon: top-right, soft silver glow. Stars: 5-8 small circles with subtle shimmer. Minimal ambient light.

### Visual Properties Animated

- Sky gradient (3-4 color stops, smooth lerp)
- Sun/moon position (arc path)
- Sun brightness/size (radial gradient radius + opacity)
- Ambient glow (radial gradient from sun position)
- Star opacity (0 during day, fade in Maghrib→Isha)
- Color temperature of glow (cool white → warm gold → orange → silver)

### Placement

- **Home screen**: ~220pt hero header. Parallax compression on scroll (sky compresses to ~100pt as cards scroll up). Prayer name + time overlaid on sky.
- **Prayer Times tab**: Full screen background behind all prayer cards. Cards use glassmorphism overlay.
- **Other tabs**: No sky. Solid Sacred Garden palette.

### Performance Safeguards

- SwiftUI `Canvas` for GPU-accelerated rendering (no UIKit)
- Gradients + circles only — no textures, no images
- `@Environment(\.accessibilityReduceMotion)`: show static snapshot of current period
- Low Power Mode detection: slower update interval
- No continuous animation frames — discrete 30s updates with smooth SwiftUI animation interpolation between states

---

## 3. Custom Tab Bar

Floating pill-style tab bar replacing default `TabView`.

### Design

- Floating capsule shape: `cardSurface` at 85% opacity, 28px corner radius, blur(20px)
- Border: `border` token (green 25% opacity)
- Shadow: `0 8px 32px rgba(0,0,0,0.3)`
- Positioned above safe area bottom with 8px padding

### Tab Items (5)

Home, Quran, Saved, Qibla, Prayer — using SF Symbols.

### States

- **Active**: pill background (`primary` at 40%), gold label, filled SF Symbol, spring scale animation (0.9 → 1.0)
- **Inactive**: no background, muted label, outlined SF Symbol, 50% opacity
- **Transition**: spring animation (response: 0.3, damping: 0.7)

### Behaviors

- Haptic: light impact on tab switch
- Hide on scroll down (translate Y + opacity), reappear on scroll up
- Prayer-time tinting: tab bar background subtly shifts to match current sky atmosphere color temperature (very subtle — 5-10% tint blend)

### Implementation

- `CustomTabBar.swift` — custom view replacing system TabView
- `ContentView.swift` modified to use ZStack with custom bar overlay
- Each tab content in its own NavigationStack

---

## 4. Prayer Time Cards Redesign

State-aware prayer cards over dynamic sky background.

### Card States

**Passed prayer**: dimmed (40% opacity), green checkmark indicator, reduced card opacity, `cardSurface` at 40%

**Current prayer (active)**: featured card style with gold border glow, gold dot indicator with shadow (`0 0 8px rgba(212,168,71,0.4)`), larger text (16pt name), countdown text below name ("2h 15m remaining"), `cardSurface` at 70%, subtle gold glow on left edge

**Next prayer**: slightly elevated, hollow circle indicator (1.5px border), `cardSurface` at 55%, normal text

**Future prayers**: progressively fading opacity (from 60% down to 40%), hollow circle indicators getting thinner, `cardSurface` decreasing

### Layout

Each prayer row: `HStack` with indicator dot (8-10px) → prayer name → spacer → time (tabular nums). Current prayer adds subtitle line with countdown.

### Interactions

- **Tap current prayer**: expand to show circular countdown ring (animated trim)
- **Long press any prayer**: toggle notification for that prayer (haptic: medium impact)
- **Press feedback**: scale 0.97 with spring (response: 0.3)

### Countdown Ring (expanded current prayer)

- Circular progress ring showing time elapsed in current period
- Gold stroke (`D4A847`), 3pt width, on dark track
- Animated trim from 0 to progress value
- Time remaining in center: `HH:mm:ss` tabular digits

---

## 5. Enhanced Quran Reading Experience

Immersive reading with audio-synced verse highlighting.

### Verse Display

- Each verse in its own container with padding
- Arabic text: Scheherazade New, 2x line-height, right-aligned RTL
- Verse number in decorative circle: 24px circle with gold border (15% opacity), number in gold, inline with Arabic text
- Translation below Arabic: 13pt, secondary text color, 1.6 line-height
- Bismillah: centered, gold-tinted, separated by divider

### Audio-Synced Highlighting

- **Active verse**: green highlight background (`primary` at 15%), gold left border (3px), per-verse audio progress bar (2px, gold fill on dark track)
- **Upcoming verses**: normal styling, slightly dimmed
- **Played verses**: normal styling
- Auto-scroll to active verse with smooth animation (0.3s ease-out)
- Tap any verse to start playback from that verse

### Player Bar (bottom)

- Persistent bar at bottom of reading view
- Play/pause circle button (32px, gold border + gold play triangle)
- Full-width progress bar (3px, gold on dark green track)
- Time display: `1:23 / 5:40` tabular digits
- Playback speed indicator: `1x`
- Transition: `.move(edge: .bottom).combined(with: .opacity)` (keep existing pattern)

### Additional Enhancements

- Pinch-to-zoom text size (gesture modifies font size setting)
- Reading progress saved per surah (UserDefaults/AppStorage)
- Dynamic Type support: content reflows, no truncation

---

## 6. Haptics & Micro-interactions

Systematic tactile feedback and polished animations throughout the app.

### Haptic Map

| Trigger | Haptic Type |
|---------|------------|
| Tab switch | Light impact |
| Bookmark toggle | Light impact |
| Card tap | Light impact |
| Share action | Medium impact |
| Notification toggle | Medium impact |
| Prayer marked complete | Success notification |
| Streak milestone (7/14/30) | Success notification |
| Picker change (Qari, method) | Selection changed |
| Scroll snap to verse | Soft impact |
| Pull-to-refresh threshold | Soft impact |
| Page turn (onboarding) | Soft impact |

### Implementation

- `HapticManager.swift` — singleton wrapping `UIImpactFeedbackGenerator`, `UINotificationFeedbackGenerator`, `UISelectionFeedbackGenerator`
- Pre-warm generators on app launch
- Respect system haptic settings automatically

### Press Scale Feedback

- **Cards**: scale to 0.97 on press, spring back (response: 0.3, damping: 0.7)
- **Buttons**: opacity 0.7 + scale 0.96 on press
- **Tab icons**: scale 0.9 → 1.0 spring on switch
- **Bookmark icon**: scale pulse 1.0 → 1.3 → 1.0 on toggle
- **Share button**: slight rotation (15deg) + scale on tap

### Implementation

- `PressScaleModifier.swift` — reusable `.pressScale(amount:)` ViewModifier using `ButtonStyle`
- Applied via `.buttonStyle(PressScaleStyle())` or `.modifier(PressScaleModifier())`

### Skeleton Loading

Replace all `ProgressView()` instances with shimmer skeleton screens.

- `SkeletonModifier.swift` — `.skeleton(loading:)` modifier
- Pulse animation: opacity oscillates 0.3 → 0.7 over 1.2s (ease-in-out, repeat)
- Skeleton shapes match actual content layout (rounded rects matching card/text dimensions)
- Applied to: Home cards, Surah list rows, Prayer times, Bookmarks list

### State Transitions

- Navigation push: matched geometry for shared elements where applicable
- Sheet presentation: spring detent with `.presentationBackground(.ultraThinMaterial)`
- Content swap: crossfade (0.2s) for data changes (not instant)
- List item entrance: stagger by 30ms per item (existing scrollReveal pattern, keep capped at 15 items)

---

## 7. Onboarding — Book Page-Turn Experience

Skeuomorphic book experience for first-launch setup.

### Book Design

**Closed state (cover):**
- Dark leather texture: gradient `#1A3028` → `#0D1F1A` → `#0A1815`
- Gold embossed title "KHEIR" with crescent icon
- Gold border inset frame (double line)
- Spine ridges (4 horizontal bars on left edge)
- Visible page edges on right (3-4 cream-colored layers, slightly offset)
- Shadow: `6px 6px 20px rgba(0,0,0,0.5)`
- Tap to open (with haptic)

**Open state — pages:**
- Paper color: warm cream `#F0E8DA` with subtle grain
- Fold shadow: gradient darkening near spine on both pages
- Spine binding: 6px center strip with stitching marks
- Page numbers: bottom corner, faded ink color
- Page edge stack: 2-3 layers visible beneath current page on right

**Portrait phone:** Single page view (right page content only)
**Landscape / iPad:** Two-page spread (left: decorative, right: interactive)

### Pages (4)

**Cover** — Dark leather, gold "KHEIR", crescent, "Spiritual Companion" subtitle. Tap to open.

**Chapter One — Your Location** — Location permission request. "Enable Location" card with SF Symbol. "Or enter city manually" fallback text.

**Chapter Two — Prayer Method** — Calculation method picker (ISNA, MWL, Umm Al-Qura, etc.) with radio-style selection. Madhab picker below.

**Chapter Three — Stay Connected** — Notification toggles for prayer times and daily Ayah. "Begin Your Journey" CTA button at bottom (green gradient with gold border).

### Page Turn Animation

- `rotation3DEffect` around Y-axis, anchor at leading edge
- Perspective: 0.5 (moderate 3D depth)
- Shadow cast on page beneath during turn
- Back of page visible (slightly darker cream)
- `DragGesture` with velocity threshold for snap
- Spring physics: response 0.5, damping 0.82
- Haptic: soft impact at snap point
- Reduce motion: instant crossfade, no 3D flip

### Left Page Decorations (landscape/iPad)

- Geometric Islamic art (circles + star points, low opacity)
- Quran quote in italic: "Indeed, with hardship comes ease." — 94:6
- Decorative ornament dividers

### Implementation Files

- `OnboardingView.swift` — book container, page management, open/close state
- `OnboardingPageView.swift` — individual page content
- `BookCoverView.swift` — leather cover design
- `PageFlipModifier.swift` — 3D page turn transition + gesture

### State Management

- `@AppStorage("hasCompletedOnboarding")` gate in `RevengeApp.swift`
- Settings saved immediately as user interacts (no final "complete" gate)
- Skip always available (small text, top-right of each page)

---

## 8. Share Card Templates — Sacred Garden Edition

Three new share card templates matching the design system.

### New Templates

**Sacred Night** — Dark emerald-navy gradient (`#0A0F1E` → `#0D1F1A`). Gold overline with surah reference. Gold divider line. Cream text. Moon + "KHEIR" watermark.

**Serene Garden** — Warm parchment gradient (`#F5F0E8` → `#EDE7DA`). Green overline. Green-to-transparent divider. Dark text. Green-tinted watermark.

**Maghrib Glow** — Sunset gradient (`#2A1A3A` → `#8B2E1A` → `#D4694A` → `#E8A87A`). Warm cream text. Warm gold divider. Sunset-tinted watermark.

### Shared Structure

All templates follow: overline (surah:ayah reference) → Arabic text (serif, RTL) → divider → English translation → watermark footer (KHEIR + crescent).

### Existing Templates

Keep existing Minimal, Ornate, Elegant templates. All 6 templates support both Ayah and Hadith content types.

### Implementation

Modify `ShareCardTemplates.swift` to add three new template cases. Update `ShareCardRenderer.swift` to render new templates. Template selection UI updated with preview thumbnails.

---

## File Inventory

### New Files (10)

| File | Purpose |
|------|---------|
| `DynamicSkyView.swift` | Sky Canvas rendering |
| `SkyEngine.swift` | Prayer-time sky state calculator |
| `SkyState.swift` | Sky state model |
| `CustomTabBar.swift` | Floating pill tab bar |
| `OnboardingView.swift` | Book container + page management |
| `OnboardingPageView.swift` | Individual onboarding page content |
| `BookCoverView.swift` | Leather cover design |
| `PageFlipModifier.swift` | 3D page turn transition |
| `SkeletonModifier.swift` | Shimmer loading modifier |
| `HapticManager.swift` | Centralized haptic feedback |

### Modified Files (8)

| File | Changes |
|------|---------|
| `Color+Theme.swift` | Sacred Garden palette tokens |
| `ContentView.swift` | Custom tab bar, onboarding gate |
| `HomeView.swift` | Sky header + parallax + new card layout |
| `PrayerTimesView.swift` | Sky background + redesigned prayer cards |
| `ReadingView.swift` | Verse highlighting + audio sync + typography |
| `ShareCardTemplates.swift` | 3 new Sacred Garden templates |
| `View+Extensions.swift` | PressScale modifier, skeleton, updated cardStyle |
| `RevengeApp.swift` | Onboarding gate with @AppStorage |

---

## Accessibility

- All animations respect `@Environment(\.accessibilityReduceMotion)`
- Dynamic Type supported — no fixed heights that truncate
- VoiceOver: meaningful labels on all interactive elements, logical reading order
- Color contrast: all text meets WCAG AA (4.5:1 body, 3:1 large text) in both modes
- Touch targets: minimum 44x44pt on all interactive elements
- Sky system: static snapshot when reduce motion enabled
- Book onboarding: crossfade fallback when reduce motion enabled
- Haptics: respect system haptic settings automatically

## Performance

- Sky: Canvas rendering (GPU), 30s update interval, no continuous animation frames
- Skeleton loading: lightweight opacity animation, no complex views
- Tab bar: standard SwiftUI views, blur material
- Press scale: transform-only animation (no layout changes)
- Staggered entrances: capped at 15 items (existing pattern)
- Book page turn: single rotation3DEffect, no complex mesh

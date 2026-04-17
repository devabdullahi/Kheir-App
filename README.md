# Kheir — Islamic Spiritual Companion for iOS

A comprehensive Islamic spiritual companion app built with SwiftUI, offering Quran reading and audio recitation, prayer times with notifications, Qibla compass, daily spiritual content, bookmarks, a reflection journal, and a home-screen widget.

---

## Table of Contents

- [Project Overview](#project-overview)
- [Features](#features)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
  - [Build & Run](#build--run)
- [Usage](#usage)
- [Architecture](#architecture)
  - [Project Structure](#project-structure)
  - [Services Layer](#services-layer)
  - [Concurrency Model](#concurrency-model)
  - [Widget Extension](#widget-extension)
- [Testing](#testing)
- [Security & Best Practices](#security--best-practices)
- [Quality Assurance](#quality-assurance)
- [Contributing](#contributing)
- [License](#license)

---

## Project Overview

Kheir (codenamed **Revenge**) is a native iOS app designed to support daily Islamic spiritual practice. It aggregates Quranic text, audio recitation, Hadith collections, prayer time calculations, and Qibla direction into a single, offline-aware experience with a polished dark/light theme system.

The app is built entirely in **SwiftUI** with an **MVVM + Services** architecture, uses **async/await** structured concurrency throughout, and ships with a **WidgetKit** home-screen widget for daily Ayah reminders.

---

## Features

| Feature | Description |
|---------|-------------|
| **Quran Reading** | Full Quranic text — Arabic (Uthmani script), English translation, transliteration, and 8 translation languages |
| **Audio Recitation** | Streaming audio from 5+ reciters via Islamic CDN with lock-screen controls and auto-advance |
| **Daily Ayah & Hadith** | Fresh spiritual content each day, cached for offline access |
| **Prayer Times** | Accurate calculation with multiple methods; local notifications for all 5 daily prayers + Sunrise |
| **Qibla Compass** | Real-time compass bearing toward the Kaaba using device heading and Haversine formula |
| **Bookmarks** | Save individual Ayahs and Hadiths for quick reference |
| **Reflection Journal** | Personal notes linked to Ayahs or Hadiths with timestamps |
| **Masjid Finder** | Locate nearby mosques on a map |
| **Home-Screen Widget** | Daily Ayah widget in small, medium, and large sizes via WidgetKit |
| **Theming** | Dark mode (deep navy + Islamic gold) and light mode (warm parchment + forest green), or follow system |

---

## Getting Started

### Prerequisites

| Requirement | Minimum |
|-------------|---------|
| **Xcode** | 16.0+ |
| **Swift** | 5.0 |
| **iOS Deployment Target** | iOS 17.0+ (check `IPHONEOS_DEPLOYMENT_TARGET` in project settings) |
| **macOS** (for building) | Ventura 13.0+ |

### Installation

1. **Clone the repository**

   ```bash
   git clone https://github.com/devabdullahi/Revenge.git
   cd Revenge
   ```

2. **Resolve Swift Package Manager dependencies**

   Open the project in Xcode — SPM dependencies resolve automatically on first open. The primary package dependency is:

   - [**Adhan**](https://github.com/batoulapps/adhan-swift) (v1.4.0+) — offline prayer time calculation

3. **Signing & capabilities**

   - Select your development team under **Signing & Capabilities** for both the `Revenge` app target and the `KheirWidgetExtension` target.
   - Both targets require the **App Groups** capability with the group identifier `group.com.kheir.shared`.

### Build & Run

```bash
# Command-line build (iPhone simulator)
xcodebuild -project Revenge.xcodeproj \
  -scheme Revenge \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  build

# Or simply open in Xcode and press ⌘R
open Revenge.xcodeproj
```

---

## Usage

### Tab Navigation

The app launches with a splash screen, then presents a five-tab interface:

1. **Home** — Daily Ayah card, daily Hadith card, prayer countdown banner
2. **Quran** — Surah list → reading view with audio player bar
3. **Prayer Times** — Today's prayer schedule, next-prayer countdown, notification toggles
4. **Qibla** — Live compass pointing toward the Kaaba
5. **Settings** — Theme, translation language, reciter, calculation method, notification preferences

### Core Workflows

- **Reading Quran**: Home → Quran tab → tap a Surah → swipe through Ayahs. Tap the play button to stream audio for the current Ayah or play the full Surah.
- **Bookmarking**: While reading, tap the bookmark icon on any Ayah or Hadith. Access saved items from the Bookmarks section.
- **Prayer Notifications**: Settings → enable notification toggles per prayer. The app schedules local notifications based on calculated prayer times for your location.
- **Widget Setup**: Long-press the home screen → add widget → search "Kheir" → choose Daily Ayah in small, medium, or large size.

---

## Architecture

### Project Structure

```
Revenge/
├── RevengeApp.swift              # @main SwiftUI App entry point
├── SplashScreenView.swift        # Animated launch screen
├── ContentView.swift             # Root TabView (5 tabs)
│
├── Core/
│   ├── Models/                   # Data models (Codable structs)
│   ├── Services/                 # Business logic singletons
│   ├── Extensions/               # Swift/SwiftUI extensions
│   ├── Utilities/                # Constants, formatters
│   └── Resources/                # Assets, strings
│
├── Features/
│   ├── Home/                     # Daily content, prayer countdown
│   ├── Quran/                    # Surah list, reading, audio
│   ├── PrayerTimes/              # Prayer schedule, notifications
│   ├── Qibla/                    # Compass view
│   ├── Bookmarks/                # Saved content
│   ├── Journal/                  # Reflection notes
│   └── Settings/                 # App preferences
│
├── Assets.xcassets/              # Colors, images, app icon
│
KheirWidget/
├── KheirWidgetBundle.swift       # Widget bundle entry
└── DailyAyahWidget.swift         # Timeline provider + views
```

### MVVM + Services

```
┌─────────┐     ┌──────────────┐     ┌────────────┐
│  Views   │────▶│  ViewModels  │────▶│  Services  │
│ (SwiftUI)│     │ (@MainActor  │     │ (Singletons│
│          │◀────│  Observable) │◀────│  Protocols) │
└─────────┘     └──────────────┘     └────────────┘
```

- **Views** are pure SwiftUI with `@StateObject` bindings to ViewModels.
- **ViewModels** are `@MainActor ObservableObject` classes with `@Published` properties. They accept protocol-typed dependencies via initializer injection for testability.
- **Services** are singletons conforming to protocols defined in `ServiceProtocols.swift` (`AyahFetching`, `HadithFetching`, `PrayerTimesFetching`, `CacheManaging`).

### Services Layer

| Service | Responsibility |
|---------|---------------|
| `APIService` | HTTP requests to Quran Cloud, Aladhan, and Hadith APIs |
| `AudioPlayerService` | AVPlayer lifecycle, Now Playing metadata, remote commands |
| `CacheManager` | Thread-safe JSON persistence (NSCache + disk), App Group sync |
| `LocationService` | CLLocationManager wrapper for coordinates and heading |
| `PrayerTimesService` | Prayer calculation — API-first with Adhan library fallback |
| `NotificationService` | UNUserNotificationCenter scheduling for prayer reminders |
| `QiblaService` | Haversine bearing calculation to the Kaaba |
| `AppSettings` | `@AppStorage`-backed user preferences |

### Concurrency Model

- **`async/await`** for all network calls and asynchronous operations — no Combine for networking.
- **`@MainActor`** isolation on all ViewModels to guarantee UI state mutations happen on the main thread.
- **Serial `DispatchQueue`** (`ioQueue`) inside `CacheManager` for thread-safe disk I/O.
- **`Sendable`** conformance on service protocols to enable safe cross-isolation usage.

### Widget Extension

The `KheirWidgetExtension` shares data with the main app via **App Groups** (`group.com.kheir.shared`):

1. Main app writes daily Ayah data to shared `UserDefaults`.
2. Widget's `TimelineProvider` reads from the same `UserDefaults`.
3. Timeline refreshes daily at midnight.
4. Tapping the widget deep-links into the app via the `kheir://home/ayah` URL scheme.

---

## Testing

### Running Tests

```bash
# Unit tests
xcodebuild test -project Revenge.xcodeproj \
  -scheme Revenge \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:RevengeTests

# UI tests
xcodebuild test -project Revenge.xcodeproj \
  -scheme Revenge \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:RevengeUITests
```

Or run from Xcode: **⌘U** to execute all tests.

### Test Framework

Unit tests use **Swift Testing** (`@Test` macro, `#expect`, `@Suite`) — the modern Swift-native test framework. UI tests use **XCUITest**.

### Test Coverage

| Area | Tests |
|------|-------|
| **HomeViewModel** | Daily content loading, caching behavior, state transitions |
| **CacheManager** | Read/write/delete, thread safety, App Group migration |
| **Bookmarks** | Toggle on/off, persistence, duplicate handling |
| **Journal** | Entry creation, editing, deletion |
| **Prayer Countdown** | Next-prayer rollover (Isha → tomorrow's Fajr) |
| **Formatting** | Date/time formatters, Hijri conversion |
| **Performance** | Baseline benchmarks for cache and API operations |
| **UI** | Launch tests, tab navigation, accessibility identifiers |

Mock services (`MockAPIService`, `MockCacheManager`) are provided in `ServiceMocks.swift` for isolated unit testing via protocol-based dependency injection.

---

## Security & Best Practices

- **No hardcoded secrets** — API endpoints are public (Quran Cloud, Aladhan) and require no keys.
- **HTTPS only** — All network requests use `https://` endpoints.
- **Thread-safe persistence** — `CacheManager` uses a serial dispatch queue to prevent data races.
- **Input validation** — API responses are decoded through typed `Codable` models; malformed data fails safely.
- **Minimal permissions** — The app requests only Location (for prayer times and Qibla) and Notifications (for prayer reminders). No tracking, no analytics, no third-party SDKs.
- **App Transport Security** — Default ATS configuration enforced (HTTPS required).
- **Sendable compliance** — Service protocols are `Sendable`; ViewModels are `@MainActor`-isolated to prevent data races in Swift's strict concurrency model.

---

## Quality Assurance

- **Protocol-driven DI** enables isolated unit testing of all ViewModels without network or disk dependencies.
- **Swift Testing macros** (`@Test`, `@Suite`, `#expect`) provide expressive, maintainable test code.
- **Accessibility identifiers** are set on key UI elements for reliable UI test automation.
- **Xcode build warnings** treated as guidance — strict concurrency checking is enabled (`SWIFT_APPROACHABLE_CONCURRENCY`).
- **Manual QA** — Test on physical devices for Location, Compass, and Audio features that require hardware.

> **Note:** No CI/CD pipeline is currently configured. Adding GitHub Actions for automated builds and tests on pull requests is recommended.

---

## Contributing

Contributions are welcome. To get started:

1. **Fork** the repository and create a feature branch from `main`:

   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Follow the existing patterns:**
   - MVVM with protocol-typed dependencies
   - `@MainActor` on ViewModels
   - `async/await` for asynchronous work
   - Swift Testing (`@Test`) for new unit tests

3. **Write tests** for new features or bug fixes.

4. **Keep commits focused** — one logical change per commit, with a clear message.

5. **Open a Pull Request** against `main` with:
   - A summary of what changed and why
   - Steps to test the change
   - Screenshots for UI changes

### Code Style

- SwiftUI views in the `Features/` directory, grouped by feature
- Shared infrastructure in `Core/`
- Services are singletons conforming to protocols in `ServiceProtocols.swift`
- Use `@Published` properties in ViewModels — no Combine publishers for new code
- Prefer `async/await` over callbacks or Combine chains

---

## License

This project is currently unlicensed (all rights reserved). Contact the repository owner for licensing inquiries.

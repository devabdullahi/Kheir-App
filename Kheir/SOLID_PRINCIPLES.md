# SOLID Principles — Swift Coding Instructions

## 1. Single Responsibility Principle (SRP)

**Rule: Every class/struct does ONE thing.**

Bad — ViewModel handles networking, parsing, AND UI state:

```swift
class UserViewModel {
    func fetchUser() {
        let url = URL(string: "https://api.example.com/user")!
        URLSession.shared.dataTask(with: url) { data, _, _ in
            let user = try? JSONDecoder().decode(User.self, from: data!)
            // update UI state
        }.resume()
    }
}
```

Good — split into focused types:

```swift
// Networking only
struct APIClient {
    func fetch<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        let (data, _) = try await URLSession.shared.data(from: endpoint.url)
        return try JSONDecoder().decode(T.self, from: data)
    }
}

// UI state only
@Observable
class UserViewModel {
    private let api: APIClient
    var user: User?

    func loadUser() async {
        user = try? await api.fetch(.user)
    }
}
```

**How to apply:**
- If you describe a class with "and" — split it
- Services handle one domain (network, cache, location, audio)
- ViewModels own state + coordinate services, not implement business logic
- Views render state, don't compute it

---

## 2. Open/Closed Principle (OCP)

**Rule: Open for extension, closed for modification.**

Add new behavior without changing existing code.

Bad — adding new prayer notification type requires modifying existing switch:

```swift
func scheduleNotification(type: String) {
    switch type {
    case "fajr": // schedule fajr
    case "dhuhr": // schedule dhuhr
    case "custom": // schedule custom — had to edit this function
    default: break
    }
}
```

Good — use protocols to extend without modifying:

```swift
protocol NotificationSchedulable {
    var title: String { get }
    var triggerTime: DateComponents { get }
}

struct FajrNotification: NotificationSchedulable {
    var title: String { "Fajr Prayer" }
    var triggerTime: DateComponents { /* ... */ }
}

struct CustomNotification: NotificationSchedulable {
    let title: String
    let triggerTime: DateComponents
}

// Never changes — works with any NotificationSchedulable
func schedule(_ notification: NotificationSchedulable) {
    let content = UNMutableNotificationContent()
    content.title = notification.title
    let trigger = UNCalendarNotificationTrigger(dateMatching: notification.triggerTime, repeats: true)
    // ...
}
```

**How to apply:**
- Use protocols to define behavior contracts
- Use enums with associated values for finite, known variants
- Use protocol conformance for open-ended extension
- Prefer composition over inheritance

---

## 3. Liskov Substitution Principle (LSP)

**Rule: Subtypes must be substitutable for their base types without breaking behavior.**

Bad — subclass violates parent contract:

```swift
class Bird {
    func fly() -> Double { return 10.0 }
}

class Penguin: Bird {
    override func fly() -> Double {
        fatalError("Penguins can't fly") // violates contract
    }
}
```

Good — separate capabilities into protocols:

```swift
protocol Bird {
    var name: String { get }
}

protocol Flyable {
    func fly() -> Double
}

struct Eagle: Bird, Flyable {
    let name = "Eagle"
    func fly() -> Double { 50.0 }
}

struct Penguin: Bird {
    let name = "Penguin"
    // No fly — no violation
}
```

**How to apply:**
- Never throw `fatalError` or return dummy values in overrides
- If subclass can't fulfill parent contract, hierarchy is wrong
- Prefer protocol composition over deep inheritance
- Any function accepting `Protocol` type must work with ALL conformers
- Test by mentally substituting every conforming type — does it still make sense?

---

## 4. Interface Segregation Principle (ISP)

**Rule: No type should be forced to implement methods it doesn't use.**

Bad — fat protocol:

```swift
protocol Worker {
    func code()
    func test()
    func design()
    func manageSprints()
}

// Designer forced to implement code() and test() with empty bodies
struct Designer: Worker {
    func code() {} // unused
    func test() {} // unused
    func design() { /* actual work */ }
    func manageSprints() {} // unused
}
```

Good — split into focused protocols:

```swift
protocol Coding {
    func code()
}

protocol Testing {
    func test()
}

protocol Designing {
    func design()
}

struct Developer: Coding, Testing {
    func code() { /* ... */ }
    func test() { /* ... */ }
}

struct Designer: Designing {
    func design() { /* ... */ }
}
```

Real-world Swift example for services:

```swift
// Instead of one massive ServiceProtocol
protocol PrayerTimesFetching {
    func fetchTimes(for date: Date, location: Coordinates) async throws -> [PrayerTime]
}

protocol PrayerTimesCalculating {
    func calculateTimes(for date: Date, location: Coordinates) -> [PrayerTime]
}

// Service conforms to both, but consumers only depend on what they need
class PrayerTimesService: PrayerTimesFetching, PrayerTimesCalculating { ... }

// ViewModel only needs fetching
class PrayerTimesViewModel {
    let fetcher: PrayerTimesFetching  // doesn't know about calculation
}
```

**How to apply:**
- Protocols should have 1-5 methods max
- If a conformer has empty method bodies — protocol too fat
- Compose small protocols: `typealias FullService = Fetching & Caching & Validating`
- Function parameters take smallest protocol that covers needs

---

## 5. Dependency Inversion Principle (DIP)

**Rule: High-level modules depend on abstractions, not concrete implementations.**

Bad — ViewModel tightly coupled to concrete service:

```swift
class HomeViewModel {
    let service = PrayerTimesService() // concrete dependency — can't test, can't swap

    func load() async {
        let times = try? await service.fetchTimes()
    }
}
```

Good — depend on protocol, inject concrete type:

```swift
protocol PrayerTimesFetching {
    func fetchTimes() async throws -> [PrayerTime]
}

class PrayerTimesService: PrayerTimesFetching {
    func fetchTimes() async throws -> [PrayerTime] { /* real API call */ }
}

class HomeViewModel {
    private let fetcher: PrayerTimesFetching

    init(fetcher: PrayerTimesFetching) {
        self.fetcher = fetcher
    }

    func load() async {
        let times = try? await fetcher.fetchTimes()
    }
}

// Production
let vm = HomeViewModel(fetcher: PrayerTimesService())

// Testing
struct MockFetcher: PrayerTimesFetching {
    func fetchTimes() async throws -> [PrayerTime] {
        return [PrayerTime.mock]
    }
}
let testVM = HomeViewModel(fetcher: MockFetcher())
```

**How to apply:**
- Constructor injection over property assignment or singletons
- Define protocols in same module as consumer, not provider
- ViewModels never instantiate their own services
- Services never instantiate other services — receive them via init

---

## Summary Checklist

| Principle | Quick Test |
|-----------|-----------|
| **SRP** | Can you describe class without "and"? |
| **OCP** | Can you add behavior without editing existing code? |
| **LSP** | Can every subtype replace parent without crashes? |
| **ISP** | Does every conformer use every protocol method? |
| **DIP** | Can you swap implementations without changing consumer? |

## Swift-Specific Additions

- Prefer `struct` over `class` unless you need reference semantics or inheritance
- Use `@Observable` + protocols over concrete class dependencies
- Mark service protocols `Sendable` for Swift 6 concurrency safety
- Use `async/await` over callback-based APIs
- Keep protocols in a shared location (e.g., `ServiceProtocols.swift`) when multiple types depend on them

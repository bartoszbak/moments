# Countdown Glass — iOS App Implementation Plan

A high-performance countdown app with Liquid Glass UI, custom background wallpapers, and WidgetKit integration. Built on a single unified timer architecture to handle multiple concurrent countdowns safely and efficiently.

---

## Phase 1: Core Architecture & Data Model

### 1.1 Project Setup
- Create new iOS app (Xcode 16+, iOS 17 minimum for glass effects)
- Enable App Groups capability from the start (required later for widget data sharing)
- Configure Core Data stack with lightweight migration support

### 1.2 Core Data Entity

```
CountdownEntity
├── id: UUID
├── title: String
├── targetDate: Date
├── backgroundImagePath: String? (file URL string, not raw image data)
└── createdDate: Date
```

**Image Storage Strategy:**
- Store background images as files in the app's Documents directory
- Keep only the file path string in Core Data — never store raw image data as a BLOB
- Generate a compressed thumbnail for list display, keep full resolution for detail view
- Clean up orphaned image files on delete

### 1.3 Swift Struct (SwiftUI-facing Model)

```swift
struct Countdown: Identifiable {
    let id: UUID
    let title: String
    let targetDate: Date
    let backgroundImageURL: URL?

    var timeRemaining: TimeInterval {
        max(0, targetDate.timeIntervalSinceNow)
    }

    var isExpired: Bool {
        targetDate <= Date()
    }
}
```

---

## Phase 2: Single Unified Timer System

> The #1 performance rule: never create one timer per countdown. Use one shared timer that drives all countdowns simultaneously.

### 2.1 TimerManager

```swift
@MainActor
final class TimerManager: ObservableObject {
    @Published var currentTime: Date = Date()
    @Published var countdowns: [Countdown] = []

    private var cancellable: AnyCancellable?

    func start() {
        cancellable = Timer
            .publish(every: 1, tolerance: 0.3, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.currentTime = Date()
            }
    }

    func stop() {
        cancellable?.cancel()
    }
}
```

- `tolerance: 0.3` allows iOS to coalesce this timer with others — saves battery
- `weak self` in closure prevents retain cycles
- `currentTime` publishing once per second triggers SwiftUI to re-evaluate all countdown rows from a single source of truth
- No individual timer instances per countdown — ever

### 2.2 Countdown Row Isolation
- Extract each row into its own `CountdownRowView` struct
- Pass only the values it needs, not the whole manager
- Use `.id(countdown.id)` on list rows to prevent full list re-renders
- Disable animations on the time digit text to avoid animation overhead on every tick

---

## Phase 3: UI Layer — Liquid Glass Design

### 3.1 Glass Effect

For iOS 17+:
```swift
extension View {
    func glassCard() -> some View {
        self
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 4)
    }
}
```

Use `.thinMaterial` or `.regularMaterial` for more opacity where needed. For iOS 26+ (Liquid Glass), Apple's native glass materials will apply automatically.

### 3.2 Main List View

```
NavigationStack
└── List of CountdownRowViews
    ├── Background image (scaledToFill, clipped)
    ├── Dark gradient overlay (for text readability)
    ├── Title
    └── Remaining time display (d / h / m / s)
Plus button → triggers AddCountdownSheet
```

### 3.3 Countdown Row

- Background: full-bleed custom wallpaper with a dark gradient overlay
- Time display: `3d 14h 22m 09s` — monospaced font to prevent layout jumping
- Secondary text: target date in readable format
- Tap → navigate to detail/full-screen view

### 3.4 Detail View

- Full-screen background image
- Large glass countdown display centered
- Edit button → sheet to change title or target date
- Delete with confirmation alert

---

## Phase 4: Add New Countdown Sheet

### 4.1 Sheet Contents

```
Sheet
├── Title TextField
├── DatePicker (date + time)
├── Background Picker
│   ├── Choose from Photos (PHPickerViewController)
│   └── Solid color presets (fallback)
└── Create / Cancel buttons
```

### 4.2 Image Handling

- Use `PhotosUI.PhotosPicker` (native SwiftUI, iOS 16+)
- On selection: compress to max ~1.5MB, generate 200px thumbnail
- Save full image to `Documents/backgrounds/<uuid>.jpg`
- Save thumbnail to `Documents/thumbnails/<uuid>.jpg`
- Store both paths in Core Data

### 4.3 Validation

- Empty title → inline error, disable Create button
- Target date in the past → inline warning
- No background selected → use default solid color / gradient

---

## Phase 5: Core Data Persistence Layer

### 5.1 Repository Pattern

Create a `CountdownRepository` to keep Core Data logic out of views:

```swift
final class CountdownRepository {
    func fetchAll() -> [Countdown]
    func create(title: String, targetDate: Date, imagePath: String?) throws
    func update(_ countdown: Countdown) throws
    func delete(_ countdown: Countdown) throws  // also removes image files
}
```

### 5.2 Reactive Updates

- Use `NSFetchedResultsController` to observe Core Data changes
- Push updates to `TimerManager.countdowns` automatically
- All Core Data writes happen on a background context, never on the main thread

### 5.3 App Launch Flow

```
App launches
→ Core Data loads async
→ TimerManager.countdowns populated
→ Timer starts
→ UI renders
```

---

## Phase 6: Background & Lifecycle Handling

### 6.1 App Backgrounding

- Timer pauses automatically when app enters background (iOS behavior)
- On `scenePhase` returning to `.active`, recalculate all time remaining from stored `targetDate`
- No background processing needed — countdowns are purely date-math based

### 6.2 Scene Phase Handling

```swift
.onChange(of: scenePhase) { phase in
    switch phase {
    case .active:
        timerManager.start()
    case .background, .inactive:
        timerManager.stop()
    default: break
    }
}
```

### 6.3 Completed Countdowns

- Show "Completed" state with distinct UI treatment
- Optionally trigger local notification when a countdown reaches zero using `UNUserNotificationCenter`

---

## Phase 7: Testing & Polish

### 7.1 Performance Testing

- Test with 20+ simultaneous countdowns in Simulator
- Profile with Instruments → Time Profiler, Main Thread Checker
- Verify timer coalescing is working (check battery impact in Instruments)
- Check memory footprint with large background images

### 7.2 Edge Cases

- System clock changes mid-countdown
- Images deleted from Photos after being used as background
- Very long countdown titles
- Countdowns expiring while the app is open

### 7.3 Polish Details

- Monospaced digit font for time to prevent layout jumping
- Haptic feedback on create and delete
- Smooth transition when a countdown hits zero
- Accessibility: VoiceOver labels on time remaining, Dynamic Type support
- Dark mode: glass effect inherits from system automatically

---

## Phase 8: WidgetKit Integration

### 8.1 Widget Extension Setup

- Add new WidgetKit Extension target to the Xcode project
- Enable App Groups on both the main app target and widget target
- Use shared `UserDefaults(suiteName: "group.yourapp.countdowns")` for data exchange

### 8.2 Data Sharing Architecture

When a countdown is created or updated in the main app:
1. Serialize a lightweight array of `WidgetCountdown` structs to JSON
2. Write JSON to the shared App Groups UserDefaults
3. Call `WidgetCenter.shared.reloadAllTimelines()` to push updates to widgets

```swift
struct WidgetCountdown: Codable {
    let id: UUID
    let title: String
    let targetDate: Date
    let thumbnailPath: String?
}
```

### 8.3 Widget Sizes

| Size | Content |
|------|---------|
| Small | Single countdown — title + time remaining |
| Medium | One countdown with background image visible |
| Lock Screen | Inline or circular: time remaining only |

### 8.4 Widget Configuration (AppIntent)

Allow users to pin a specific countdown to a widget:

```swift
struct SelectCountdownIntent: AppIntent {
    @Parameter(title: "Countdown")
    var countdownID: String
}
```

### 8.5 Timeline Provider

```swift
struct CountdownProvider: AppIntentTimelineProvider {
    func timeline(for intent: SelectCountdownIntent, in context: Context) async -> Timeline<CountdownEntry> {
        // Generate entries every minute for the next hour
        // WidgetKit handles the refresh automatically
    }
}
```

### 8.6 Widget Display

- Match the glass card aesthetic of the main app using `.containerBackground`
- Show background thumbnail image behind glass overlay
- Display time remaining with large, legible typography
- Handle expired state gracefully ("Time's up 🎉")

---

## Recommended Build Order

1. Data model + Core Data stack
2. TimerManager (no UI yet — test in isolation)
3. Main list view + static mock data
4. CountdownRowView with live timer
5. Add Countdown sheet + image picker
6. Core Data integration (replace mocks)
7. Detail view + edit/delete
8. Polish, animations, accessibility
9. Local notifications for completed countdowns
10. WidgetKit extension

---

## Tech Stack Summary

| Layer | Choice |
|-------|--------|
| UI Framework | SwiftUI |
| State Management | @StateObject / @ObservedObject / @EnvironmentObject |
| Persistence | Core Data |
| Timer | Combine `Timer.publish` (single shared instance) |
| Image Storage | Documents directory (path stored in Core Data) |
| Image Picker | PhotosUI `PhotosPicker` |
| Widgets | WidgetKit + AppIntents |
| Data Sharing | App Groups + shared UserDefaults |
| Min iOS | iOS 17 |

# Calendar Integration + Settings Sheet — Implementation Plan

## Overview

Two features implemented together:
1. **Settings Sheet** — accessible from the main view, with appearance and calendar options
2. **Calendar Integration** — automatically creates/updates/deletes EventKit events when countdowns are managed

---

## New Files

| File | Purpose |
|------|---------|
| `Moments/Features/Settings/SettingsView.swift` | Form-based sheet (mirrors DeveloperMenuView pattern) with appearance picker + calendar toggle |
| `Moments/Services/CalendarService.swift` | EventKit singleton — request permission, create/update/delete events |

---

## Modified Files

| File | Change |
|------|--------|
| `Moments/Features/List/CountdownListView.swift` | Add gear icon button in toolbar + `.sheet` for `SettingsView` |
| `Moments/MomentsApp.swift` | `@AppStorage("settings.appearance")` → `.preferredColorScheme()` on root view (reactive, no restart needed) |
| `Moments/Models/Countdown.swift` | Add `var calendarEventIdentifier: String?` |
| `Moments/Persistence/CountdownEntity+Mapping.swift` | Map new Core Data attribute in `toCountdown()` |
| `Moments/Persistence/CountdownRepository.swift` | Hook `CalendarService` into create/update/delete |
| `Moments/Persistence/PersistenceController.swift` | Explicit lightweight migration options |
| `Moments/Info.plist` | Add `NSCalendarsFullAccessUsageDescription` (iOS 17+ key) |

---

## SettingsView

Form-based `NavigationStack`, following the exact `DeveloperMenuView` pattern.

**Appearance section:**
- `Picker` with three options: System (default), Light, Dark
- Stored in `@AppStorage("settings.appearance")` as a raw `String` ("system"/"light"/"dark")
- Changes apply instantly across the app

**Calendar section:**
- `Toggle` for "Add to Calendar"
- Stored in `@AppStorage("settings.calendarIntegration.enabled")`
- On toggle ON → triggers `CalendarService.shared.requestAccess()` immediately
- If denied → toggle rolls back to `false`, footer shows warning + "Open Settings" link
- On `SettingsView.onAppear` → re-check auth status; if externally revoked, auto-disable toggle

**Footer states for Calendar section:**
- `.notDetermined` → no footer shown
- `.fullAccess` → "Calendar access granted" (green)
- `.denied` / `.restricted` → "Access denied — open Settings to allow access" + `Button("Open Settings")`

**AppStorage key constants** live in a `SettingsKeys` enum at the bottom of `SettingsView.swift`.

---

## CalendarService

`@MainActor final class CalendarService` singleton (`static let shared`).

```swift
// Key API surface
func requestAccess() async -> Bool
func createEvent(for countdown: Countdown) async -> String?  // returns eventIdentifier
func updateEvent(identifier: String, for countdown: Countdown) async
func deleteEvent(identifier: String) async
func currentAuthorizationStatus() -> EKAuthorizationStatus
@Published private(set) var authorizationStatus: EKAuthorizationStatus
```

- Uses `EKEventStore().requestFullAccessToEvents()` (iOS 17+ API)
- Creates **all-day events** on `countdown.targetDate` with title matching countdown title
- All action methods guard on `authorizationStatus == .fullAccess`
- `NSCalendarsFullAccessUsageDescription` is the required Info.plist key (iOS 17+)

---

## Appearance Setting

`AppStorage` key: `"settings.appearance"` — values: `"system"` (default), `"light"`, `"dark"`

In `MomentsApp.swift`:

```swift
@AppStorage("settings.appearance") private var appearanceSetting = "system"

private var preferredColorScheme: ColorScheme? {
    switch appearanceSetting {
    case "light": return .light
    case "dark":  return .dark
    default:      return nil
    }
}
```

Applied as `.preferredColorScheme(preferredColorScheme)` on the root `WindowGroup` content view. Because `@AppStorage` is a `DynamicProperty`, changes are reactive — no app restart needed.

---

## Core Data Migration

### New model version: Moments 2

1. In Xcode: **Editor → Add Model Version** → name it "Moments 2"
2. Copy all existing attributes from the current model
3. Add one new attribute to `CountdownEntity`:
   - Name: `calendarEventIdentifier`
   - Type: `String`
   - Optional: `YES`
4. Set "Moments 2" as the current model version

### Migration strategy

**Lightweight migration** — Core Data infers the mapping automatically. No `NSMappingModel` needed.

Add explicit options to `PersistenceController` for clarity:

```swift
container.persistentStoreDescriptions.first?.setOption(
    true as NSNumber,
    forKey: NSMigratePersistentStoresAutomaticallyOption
)
container.persistentStoreDescriptions.first?.setOption(
    true as NSNumber,
    forKey: NSInferMappingModelAutomaticallyOption
)
```

---

## Calendar Event Behavior in Repository

| Repository method | Calendar action |
|-------------------|----------------|
| `create()` | `createEvent(for:)` → store returned ID via `updateCalendarIdentifier()` |
| `update()` | `updateEvent(identifier:for:)` if ID exists; else `createEvent()` if toggle is on |
| `delete()` | `deleteEvent(identifier:)` if ID exists — **always, regardless of toggle state** |
| `deleteAll()` | Inherits per-item `delete()` behavior |
| Seed data (dev menu) | **No calendar call** — seed data bypasses `create()` to avoid polluting real calendar |

### Key implementation detail — async ID write

`create()` runs synchronously on `backgroundContext`. The calendar event ID comes back asynchronously. A fire-and-forget `Task` writes it back:

```swift
Task { @MainActor in
    if let eventID = await calendarService.createEvent(for: newCountdown) {
        try? self.updateCalendarIdentifier(id: capturedID, eventIdentifier: eventID)
    }
}
```

Calendar sync is **best-effort** — errors are silently swallowed. The countdown save has already succeeded. This matches the existing widget reload pattern in `syncCountdowns()`.

### Delete always cleans up

If a calendar event was created while the toggle was on, then the toggle is turned off, the event still lives in the calendar. When the countdown is later deleted, `deleteEvent()` is still called (using the stored `calendarEventIdentifier`). This prevents orphaned calendar events regardless of settings changes.

---

## Info.plist

Add the EventKit usage description (iOS 17+ key):

```xml
<key>NSCalendarsFullAccessUsageDescription</key>
<string>Moments creates calendar events on your countdown dates so you never miss an important day.</string>
```

> Note: `NSCalendarsFullAccessUsageDescription` is required for `requestFullAccessToEvents()` (iOS 17+). The older `NSCalendarsUsageDescription` key is for write-only access and is not needed.

---

## File Structure

```
Moments/
  Features/
    Settings/
      SettingsView.swift                  [NEW]
    Developer/
      DeveloperMenuView.swift             [unchanged]
    List/
      CountdownListView.swift             [MODIFY — gear button + settings sheet]
  Services/
    CalendarService.swift                 [NEW]
  Models/
    Countdown.swift                       [MODIFY — add calendarEventIdentifier]
  Persistence/
    CountdownEntity+Mapping.swift         [MODIFY — new NSManaged property + toCountdown()]
    CountdownRepository.swift             [MODIFY — calendar hooks in create/update/delete]
    PersistenceController.swift           [MODIFY — explicit migration options]
  Moments.xcdatamodeld/
    Moments.xcdatamodel/                  [existing — do not touch]
    Moments 2.xcdatamodel/               [NEW version — add calendarEventIdentifier]
  MomentsApp.swift                        [MODIFY — preferredColorScheme + @AppStorage]
  Info.plist                              [MODIFY — NSCalendarsFullAccessUsageDescription]
```

---

## Scope Summary

- **2 new files**
- **7 modified files**
- **1 new Core Data model version** (lightweight migration, no mapping model)
- Total: ~9 files touched

# Refinement Plan — TillApp

**Date:** 2026-04-08

---

## Overview

Five concrete defects: one crash-on-launch regression, two silent file leaks, one distorted image, and one wired-but-inactive preference. Each section states which files change, exactly what changes, and why. Issues requiring Xcode GUI interaction are clearly called out.

---

## Issue 1 (Critical) — Core Data schema change without versioning

### Impact
Crash on launch for any user who already has data on disk. Core Data compares the compiled model hash against the persistent store metadata. When the hashes differ and no migration option is provided, `loadPersistentStores` calls `fatalError`.

### Root cause
`showDate` was appended directly to the single existing model version (`TillApp.xcdatamodel/contents`). There is only one model version in the `.xcdatamodeld` bundle, so Core Data has no migration path for existing stores.

### Xcode GUI steps (cannot be done via file editing alone)

1. Open `TillApp.xcdatamodeld` in the Xcode model editor
2. Choose **Editor → Add Model Version…** — name it **TillApp 2**
3. Xcode creates `TillApp 2.xcdatamodel/contents` and updates `.xccurrentversion`
4. Confirm `showDate` is present in the new version (copied from source)
5. Select the **original** `TillApp.xcdatamodel` and **remove** `showDate` from it — leave the nine original attributes
6. In the inspector, set the **current model version** to **TillApp 2**

After this:
- `TillApp.xcdatamodel` — original 9 attributes, no `showDate`
- `TillApp 2.xcdatamodel` — all 10 attributes including `showDate` (optional Boolean, default YES)
- `.xccurrentversion` — points to `TillApp 2`

### File edit — `PersistenceController.swift`

Lightweight migration options must be set **before** `loadPersistentStores` is called:

```swift
let description = container.persistentStoreDescriptions.first
description?.setOption(true as NSNumber,
    forKey: NSMigratePersistentStoresAutomaticallyOption)
description?.setOption(true as NSNumber,
    forKey: NSInferMappingModelAutomaticallyOption)

container.loadPersistentStores { _, error in
    if let error {
        fatalError("Core Data failed to load: \(error.localizedDescription)")
    }
}
```

Adding an optional Boolean attribute with a default value is a lightweight-compatible change — no custom mapping model is needed.

### Files
- **Xcode GUI** — `TillApp/TillApp.xcdatamodeld`
- **File edit** — `TillApp/Persistence/PersistenceController.swift`

---

## Issue 2 (High) — Thumbnail is squashed, not cropped

### Impact
All photo thumbnails are distorted. The widget then applies `scaledToFill` on top of an already-squashed image, compounding the distortion.

### Root cause
`ImageStorageService.resized(to:)` draws the full image into the target rect without preserving aspect ratio. A 16:9 landscape photo becomes a distorted 1:1 square.

### Fix — `ImageStorageService.swift`

Replace the `resized(to:)` extension with an aspect-fill (scale-to-fill, crop-center) implementation:

**Current:**
```swift
private extension UIImage {
    func resized(to size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
```

**Replacement:**
```swift
private extension UIImage {
    func resized(to size: CGSize) -> UIImage {
        let scale = max(size.width / self.size.width,
                        size.height / self.size.height)
        let scaledSize = CGSize(width: self.size.width * scale,
                                height: self.size.height * scale)
        let origin = CGPoint(
            x: (size.width  - scaledSize.width)  / 2,
            y: (size.height - scaledSize.height) / 2
        )
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            draw(in: CGRect(origin: origin, size: scaledSize))
        }
    }
}
```

`scale` is the larger of the two axis ratios so the shorter source dimension exactly fills the target and the longer dimension overflows. `origin` is negative on the overflowing axis, centering the crop. `UIGraphicsImageRenderer` clips to its canvas automatically.

### Files
- **File edit** — `TillApp/Services/ImageStorageService.swift`

---

## Issue 3 (High) — Widget shared-group images leak on delete

### Impact
Each deleted countdown leaves a `widget_<UUID>.jpg` file in the app group container permanently. On devices with many add/delete cycles these accumulate without bound.

### Root cause
`syncCountdowns()` only iterates the **current** countdown list when copying thumbnails. A deleted countdown's file is never visited again.

### Fix — `CountdownRepository.swift`, inside `syncCountdowns()`

After building `widgetData`, sweep the app group directory and remove any `widget_*.jpg` file whose UUID is not in the current list:

```swift
// Sweep stale widget images from the app group
if let groupURL {
    let activeFileNames = Set(countdowns.map { "widget_\($0.id.uuidString).jpg" })
    let contents = (try? FileManager.default.contentsOfDirectory(
        at: groupURL,
        includingPropertiesForKeys: nil
    )) ?? []
    for fileURL in contents
    where fileURL.lastPathComponent.hasPrefix("widget_")
       && fileURL.pathExtension == "jpg"
       && !activeFileNames.contains(fileURL.lastPathComponent)
    {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
```

Insert this block after the `widgetData` array is fully built and before `SharedDataStore.save(widgetData)`. The `hasPrefix("widget_") && pathExtension == "jpg"` guard ensures no other files in the app group are touched (e.g., the JSON written by `SharedDataStore`).

### Files
- **File edit** — `TillApp/Persistence/CountdownRepository.swift`

---

## Issue 4 (Medium) — Original photo orphaned when background is changed in edit

### Impact
Every countdown created with a photo leaks two files on disk (full-size + thumbnail) if the photo is ever changed in the edit sheet. The files are named after a random UUID that no entity ever tracks.

### Root cause
`AddCountdownView.create()` calls `ImageStorageService.save(image: image, id: UUID())` with a freshly-generated random UUID. `repository.create()` then generates **another** UUID for the entity. The image files and the countdown entity never share the same ID. When the photo is later changed in edit, new files are written under `countdown.id` — the originals are invisible to the cleanup code.

### Fix

Generate the countdown's UUID in `AddCountdownView` before writing images, then pass it to `repository.create()` so both use the same ID.

**`AddCountdownView.swift` — `create()` method**

Before the `switch background` block, generate the ID:
```swift
let newID = UUID()
```

In the `.photo` case, use it:
```swift
case .photo(let image):
    if let paths = ImageStorageService.save(image: image, id: newID) {
        imagePath = paths.backgroundPath
        thumbPath = paths.thumbnailPath
    }
```

Pass it to the repository:
```swift
try repository.create(
    id: newID,
    title: trimmed, targetDate: targetDate,
    ...
)
```

**`CountdownRepository.swift` — `create()` method**

Add an `id` parameter with a default so all existing callers (seed functions, developer menu) continue to compile without changes:

```swift
func create(
    id: UUID = UUID(),
    title: String,
    targetDate: Date,
    ...
) throws {
    ...
    entity.id = id  // was: entity.id = UUID()
    ...
}
```

### Files
- **File edit** — `TillApp/Features/Add/AddCountdownView.swift`
- **File edit** — `TillApp/Persistence/CountdownRepository.swift`

---

## Issue 5 (Medium) — Appearance setting not wired up

### Impact
The appearance toggle in the settings sheet persists a value to `UserDefaults` but nothing reads it. Light/Dark/System selection has zero effect.

### Root cause
`TillAppApp.swift` has no `@AppStorage` for `settings.appearance` and no `.preferredColorScheme` modifier on the root view.

### Fix — `TillAppApp.swift`

Add the stored property alongside the existing `@StateObject` declarations:
```swift
@AppStorage("settings.appearance") private var appearanceSetting = "system"
```

Add a computed property to map the string to `ColorScheme?`:
```swift
private var preferredColorScheme: ColorScheme? {
    switch appearanceSetting {
    case "light": return .light
    case "dark":  return .dark
    default:      return nil
    }
}
```

Apply it to the root view in `WindowGroup`:
```swift
CountdownListView()
    .environmentObject(repository)
    .environmentObject(timerManager)
    .preferredColorScheme(preferredColorScheme)
```

`@AppStorage` is a `DynamicProperty`, so SwiftUI re-evaluates the body whenever the value changes — appearance updates instantly without restart. `nil` defers to the OS setting, which is the correct default.

### Files
- **File edit** — `TillApp/TillAppApp.swift`

---

## Implementation order

| Order | Issue | Reason |
|-------|-------|--------|
| 1 | Core Data versioning | Crash; nothing can be tested on device until resolved |
| 2 | Issue 4 + Issue 3 | Both touch `CountdownRepository.swift` — do in one pass |
| 3 | Issue 2 | Self-contained to `ImageStorageService.swift` |
| 4 | Issue 5 | Additive only; safe at any point |

---

## File summary

| File | Issues |
|------|--------|
| `TillApp.xcdatamodeld` (Xcode GUI) | 1 |
| `Persistence/PersistenceController.swift` | 1 |
| `Persistence/CountdownRepository.swift` | 3, 4 |
| `Services/ImageStorageService.swift` | 2 |
| `Features/Add/AddCountdownView.swift` | 4 |
| `TillAppApp.swift` | 5 |

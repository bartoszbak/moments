# Future Manifestation Notifications — Implementation Plan

## Architecture Recommendation

**Recommendation:** MVVM-style feature modules on top of the existing repository/service architecture  
**Fit:** `fit`

Why this fits the current app:
- The codebase is already SwiftUI-first with `@State`, `@StateObject`, `@EnvironmentObject`, singleton services, and `@AppStorage` rather than reducers or scoped stores.
- This feature is medium-sized: one new service, a small settings surface, and a manifestation-specific detail card. That does not justify a TCA migration by itself.

Closest alternative:
- **TCA** would be the closest strict-flow alternative if the app later moves more feature state into reducers.
- Tradeoff: it would improve determinism and testing, but it is a mismatch for this feature in isolation because the rest of the app is not TCA-based yet.

Reference:
- `/Users/bartbak/.agents/skills/swift-architecture-skill/references/selection-guide.md`

## Product Goal

Allow **future manifestations** to opt into local notifications **after creation**, so users can read the generated manifestation first and then choose the reminder style that fits them.

This changes the current flow in one important way:
- Turning on **Future manifestation** in add/edit only marks the moment as **eligible** for manifestation reminders.
- It does **not** immediately schedule notifications or ask for permission.
- The actual notification decision happens later from the manifestation detail screen and can also be managed globally from Settings.

## Recommended UX

### 1. Add/Edit flow

Keep [AddCountdownView.swift](/Users/bartbak/Repo/Moments/Moments/Features/Add/AddCountdownView.swift:1) and [EditCountdownView.swift](/Users/bartbak/Repo/Moments/Moments/Features/Add/EditCountdownView.swift:1) lightweight.

When `Future manifestation` is enabled:
- Keep the current date-hiding behavior.
- Add a short footer below the toggle:
  - `You can choose reminder settings after you create this manifestation.`
- Do not request notification permission here.

Reason:
- Creation should stay fast.
- Permission prompts are better when the user is explicitly choosing reminders.

### 2. Manifestation detail / preview

Add a new **Manifest Notifications** card to [MomentPreviewView.swift](/Users/bartbak/Repo/Moments/Moments/Features/Preview/MomentPreviewView.swift:1) for `countdown.isFutureManifestation == true`.

This card should appear:
- after the manifestation text / anchor is available
- even if notifications are currently off

Card contents:
- current reminder status
- a short explainer about how reminders work
- a primary action to manage reminders

Suggested copy:
- Title: `Manifest Notifications`
- Body when off: `Read the manifestation first, then choose whether this moment should gently return to you.`
- Body when on: `This manifestation will remind you on your chosen rhythm.`

Primary actions:
- `Turn On`
- `Change Rhythm`
- `Turn Off`

This is the best place to “talk about notifications” because the user has already read the manifestation and has enough context to choose.

### 3. Settings

Extend [SettingsView.swift](/Users/bartbak/Repo/Moments/Moments/Features/Settings/SettingsView.swift:1) with a new **Manifestations** section.

This section should hold **global defaults**, not the only control surface.

Recommended settings:
- `Allow Manifestation Notifications` master toggle
- `Default Rhythm` picker
- `Reminder Time` picker

Recommended default rhythm options:
- `Off`
- `Daily`
- `Weekly`

Reason for this scope:
- simple enough for V1
- avoids over-scheduling
- easy to explain
- easy to reconcile

## Notification Model

### Global settings

Add new `@AppStorage` keys in [SettingsView.swift](/Users/bartbak/Repo/Moments/Moments/Features/Settings/SettingsView.swift:1):

- `settings.manifestNotifications.enabled`
- `settings.manifestNotifications.defaultRhythm`
- `settings.manifestNotifications.hour`
- `settings.manifestNotifications.minute`

Defaults:
- enabled: `false`
- default rhythm: `"daily"`
- hour: `9`
- minute: `0`

### Per-manifestation settings

Add notification-specific fields to [Countdown.swift](/Users/bartbak/Repo/Moments/Moments/Models/Countdown.swift:1):

- `manifestNotificationRhythm: ManifestNotificationRhythm?`
- `manifestNotificationsEnabled: Bool`

Recommended enum:

```swift
enum ManifestNotificationRhythm: String, Codable, CaseIterable {
    case daily
    case weekly
}
```

Behavior:
- Non-manifestation moments ignore these fields.
- Future manifestations default to:
  - `manifestNotificationsEnabled = false`
  - `manifestNotificationRhythm = nil`
- When the user turns reminders on from the manifestation detail screen:
  - use the global default rhythm if the moment has no explicit rhythm yet

Why store both fields:
- `enabled` cleanly answers whether a moment should schedule anything
- `rhythm` stores the user’s explicit preference once enabled

## Persistence Changes

### Core Data

Add new optional attributes to `CountdownEntity` in a new model version:
- `manifestNotificationsEnabled` (`Boolean`, default `NO`)
- `manifestNotificationRhythmRaw` (`String`, optional)

Update:
- [CountdownEntity+Mapping.swift](/Users/bartbak/Repo/Moments/Moments/Persistence/CountdownEntity+Mapping.swift:1)
- [CountdownRepository.swift](/Users/bartbak/Repo/Moments/Moments/Persistence/CountdownRepository.swift:1)
- [PersistenceController.swift](/Users/bartbak/Repo/Moments/Moments/Persistence/PersistenceController.swift:1) already supports inferred lightweight migration

Migration behavior:
- Existing moments migrate with notifications off.
- Existing manifestations remain manifestations, but do not schedule reminders until the user opts in.

## Service Design

Create:
- `Moments/Services/ManifestNotificationService.swift`

Primary responsibilities:
- request local-notification authorization
- schedule reminders for eligible manifestations
- cancel reminders when disabled or deleted
- reconcile all reminders from persisted state

Suggested surface:

```swift
@MainActor
final class ManifestNotificationService: ObservableObject {
    static let shared = ManifestNotificationService()

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    func refreshAuthorizationStatus() async
    func requestAuthorization() async -> Bool
    func schedule(for countdown: Countdown) async
    func cancel(for countdownID: UUID) async
    func reconcile(countdowns: [Countdown]) async
}
```

Identifier format:
- `manifest.<uuid>`

Scheduling rules:
- only schedule when `countdown.isFutureManifestation == true`
- only schedule when `manifestNotificationsEnabled == true`
- only schedule when the global master toggle is on
- use a repeating `UNCalendarNotificationTrigger`

Content strategy for V1:
- title: countdown title
- body:
  - prefer `reflectionGuidanceText`
  - otherwise use a short generic fallback like `Return to your manifestation and reinforce it.`

Why not use the full manifestation text in notifications:
- too long for notification surfaces
- brittle if the manifestation content changes
- guidance text is a cleaner reminder payload

## Repository Integration

Hook notification reconciliation into [CountdownRepository.swift](/Users/bartbak/Repo/Moments/Moments/Persistence/CountdownRepository.swift:1), similar to the existing calendar integration.

### On create

When creating a future manifestation:
- persist with notifications off by default
- do not schedule anything yet

### On update

If a moment changes:
- manifestation -> non-manifestation: cancel notification
- non-manifestation -> manifestation: remain off until user enables
- manifestation notification settings changed: reschedule
- title / guidance changed while notifications are enabled: reschedule content

### On delete

Always cancel the notification for that countdown ID.

### On app sync / launch

After `syncCountdowns()` updates the in-memory list, trigger a background reconcile:

```swift
Task { @MainActor in
    await manifestNotificationService.reconcile(countdowns: countdowns)
}
```

This keeps pending notifications aligned with:
- stored countdown state
- global settings
- permission changes made outside the app

## View Model Boundary

Create a small view model for the manifestation reminder card rather than pushing permission and scheduling logic into the view.

Suggested file:
- `Moments/Features/Preview/ManifestNotificationCardModel.swift`

Responsibilities:
- map `Countdown` + global settings + notification auth into UI state
- expose button actions:
  - enable reminders
  - disable reminders
  - change rhythm
  - open app settings when permission is denied

This is the main MVVM boundary for the feature.

Keep [MomentPreviewView.swift](/Users/bartbak/Repo/Moments/Moments/Features/Preview/MomentPreviewView.swift:1) as the composition layer only.

## Liquid Glass Guidance

Reference:
- `/Users/bartbak/.agents/skills/swiftui-liquid-glass/references/liquid-glass.md`

Use Liquid Glass only on the manifestation-specific reminder surfaces that benefit from emphasis.

### Recommended surfaces

1. The **Manifest Notifications** card in the detail screen
2. The `Change Rhythm` and `Turn On` primary actions
3. Optional segmented rhythm chips if the design moves beyond a plain `Picker`

### Recommended implementation

For iOS 26+:
- wrap related reminder controls in `GlassEffectContainer`
- apply `.glassEffect(.regular, in: .rect(cornerRadius: 24))` to the card
- use `.buttonStyle(.glassProminent)` for the primary action
- use `.buttonStyle(.glass)` for secondary actions

For earlier iOS versions:
- continue using the existing helpers from [View+Glass.swift](/Users/bartbak/Repo/Moments/Moments/Extensions/View+Glass.swift:1)

Important constraints:
- do not apply glass to every row in `SettingsView`; system settings UI already has enough visual structure
- keep the glass treatment local to the manifestation detail experience
- apply `.glassEffect()` after layout modifiers

## File Plan

### New files

- `Moments/Services/ManifestNotificationService.swift`
- `Moments/Features/Preview/ManifestNotificationCardModel.swift`
- `Moments/Features/Preview/ManifestNotificationCard.swift`

### Modified files

- [Moments/Models/Countdown.swift](/Users/bartbak/Repo/Moments/Moments/Models/Countdown.swift:1)
- [Moments/Persistence/CountdownEntity+Mapping.swift](/Users/bartbak/Repo/Moments/Moments/Persistence/CountdownEntity+Mapping.swift:1)
- [Moments/Persistence/CountdownRepository.swift](/Users/bartbak/Repo/Moments/Moments/Persistence/CountdownRepository.swift:1)
- [Moments/Features/Add/AddCountdownView.swift](/Users/bartbak/Repo/Moments/Moments/Features/Add/AddCountdownView.swift:1)
- [Moments/Features/Add/EditCountdownView.swift](/Users/bartbak/Repo/Moments/Moments/Features/Add/EditCountdownView.swift:1)
- [Moments/Features/Preview/MomentPreviewView.swift](/Users/bartbak/Repo/Moments/Moments/Features/Preview/MomentPreviewView.swift:1)
- [Moments/Features/Settings/SettingsView.swift](/Users/bartbak/Repo/Moments/Moments/Features/Settings/SettingsView.swift:1)
- `Moments/Info.plist`
- `Moments/Moments.xcdatamodeld/...` new model version

## Rollout Phases

### Phase 1: Data + scheduling infrastructure

- add model fields
- add Core Data migration
- add `ManifestNotificationService`
- add repository reconcile hooks

### Phase 2: Settings defaults

- add Manifestations section to Settings
- add permission handling and fallback footer
- add reminder time and default rhythm

### Phase 3: Per-manifestation control

- add manifestation reminder card to the detail view
- let users enable/disable and change rhythm after reading the manifestation

### Phase 4: Polish

- add Liquid Glass treatment on the detail card
- refine notification copy
- verify VoiceOver and Dynamic Type

## Testing Strategy

### Unit-level

Add tests for:
- rhythm -> `DateComponents` trigger mapping
- repository decision logic for create/update/delete
- reconcile behavior when global settings are off
- reconcile behavior when a manifestation becomes a standard moment

### Manual verification

1. Create a future manifestation.
2. Confirm no notification prompt appears during creation.
3. Open the manifestation detail screen.
4. Turn reminders on.
5. Confirm the app asks for notification permission at that moment.
6. Change rhythm from daily to weekly.
7. Edit the manifestation into a non-manifest moment.
8. Confirm the reminder is removed.
9. Delete the manifestation.
10. Confirm the reminder is removed.

## Risks and Guardrails

### Risk: permission prompt too early

Guardrail:
- request authorization only from an explicit reminder action

### Risk: settings become confusing

Guardrail:
- split responsibilities clearly:
  - Add/Edit marks manifestation eligibility
  - Detail screen decides per-moment reminders
  - Settings defines defaults

### Risk: notification content feels generic

Guardrail:
- prefer stored manifestation guidance text for the notification body
- keep payload short and readable

### Risk: architecture drift

Guardrail:
- keep scheduling logic in a service
- keep view-specific decision logic in a view model
- keep repository responsible only for persistence and synchronization triggers

## Recommended V1 Scope

Build this first:
- global master toggle
- global default rhythm
- per-manifestation on/off
- per-manifestation rhythm: `daily` or `weekly`
- manifestation detail card as the main control surface

Do not build yet:
- multiple reminders per day
- AI-generated reminder cadence
- separate notification copy editors
- notification inbox/history

That keeps the first version understandable and aligned with the existing app architecture.

<img width="128" height="128" alt="till-icon" src="https://github.com/user-attachments/assets/5e7e77b2-506a-4f52-8601-14b3df612aae" />

# Moments

Moments is an iOS app for keeping upcoming events, meaningful past dates, and date-free future manifestations in one place. It combines a visual timeline, per-moment customization, Home Screen widgets, and AI-generated reflection or manifestation copy.

## Product Snapshot

Moments currently supports:

- Upcoming moments with days until the event
- Past moments with days since the event
- Future manifestations with no target date
- iPhone and iPad layouts
- Add, edit, preview, and delete flows
- Small, medium, and accessory widgets
- Deep links from widgets into a specific moment
- Onboarding, settings, theming, and alternate app icons
- Calendar sync for dated moments
- Manifestation reminder notifications
- A paywall and RevenueCat-based purchase/restore plumbing

## How The Product Works

### Library

- The main screen shows moments in a grid.
- Users can filter by `All`, `Past`, `Upcoming`, or `Present` (manifestations).
- The app supports both empty-state onboarding and seeded sample content on first launch.

### Moment Creation

Each moment can include:

- Title
- Optional description
- Date, or `Future manifestation` mode
- Preset color, custom color, or photo background
- Optional SF Symbol
- Widget options such as showing the date
- Optional progress bar start state for future dated moments

Manifestations can also enable reminder notifications with a daily or weekly rhythm.

### Moment Preview

- Dated moments show a large day count and relative label such as `Days until`, `Days since`, or `Today`.
- Manifestations use a different hero treatment and typography.
- The primary CTA changes based on context:
  - Upcoming: `Set Intention`
  - Past: `Look Back`
  - Manifestation: `Get Manifestation`
- AI text is revealed progressively and then stored back onto the moment.
- Editing a moment's title, date, mode, or description clears previously generated AI so it can be regenerated against the new context.

### First-Run Behavior

When the store is empty, the app seeds a small set of example moments:

- one upcoming date
- one future manifestation

It also presents an intro sheet the first time the app is opened.

## Widgets And System Integrations

### Widgets

The widget extension supports:

- `systemSmall`
- `systemMedium`
- `accessoryCircular`
- `accessoryRectangular`
- `accessoryInline`

Each widget can be configured with App Intents to show a specific moment. Tapping a widget deep-links into the app with the `moments://preview?countdownID=...` URL scheme.

### Calendar Sync

- Calendar sync is configured from Settings.
- It requests full EventKit access.
- Only dated moments are synced.
- Synced items are created as all-day calendar events.
- The app prefers iCloud/CalDAV calendars when available, otherwise it falls back to the default writable calendar.

### Manifestation Reminders

- Reminder authorization is handled separately from calendar access.
- Reminders are opt-in globally and per manifestation.
- The app schedules repeating local notifications using the stored default time.
- Weekly reminders preserve a weekday for the manifestation.

## AI Behavior

Moments uses OpenRouter chat completions and expects strict JSON output.

Normal moments produce:

- `surface`
- `reflection`
- `guidance`

Future manifestations produce:

- `instruction`
- `anchor`

The generated content is persisted with the moment so it can be reopened later without regenerating it.

## Premium / Monetization Status

The codebase already includes:

- a premium upsell card in Settings
- a paywall UI
- RevenueCat configuration, offering loading, purchase, and restore flows
- developer overrides for simulating entitlement and offering states

Current gated behavior:

- free users can create up to `3` user-generated moments before add attempts are stopped by the paywall
- free users can generate up to `3` new AI reflections / manifestations before preview routes them into the paywall
- free users see Plus-pill locked rows instead of live controls for calendar sync, manifestation reminders, and alternate app icons
- paywall prices, trial CTA text, and billing notes now resolve from RevenueCat package data when live offerings load
- Apple subscription management remains available from the paywall for active subscribers
- the app-specific privacy policy URL remains configurable through `PRIVACY_POLICY_URL`

Implementation note: premium infrastructure is now live for a soft creation upsell, a hard AI-generation limit, and settings-level premium locks, but other planned premium gates are still not broadly rolled out yet.

## UI And Platform Notes

- Deployment target: iOS 17
- Supports iPhone and iPad
- Uses iOS 26 glass/material enhancements when available, with fallback UI on earlier supported versions
- Supports system, light, and dark appearance modes
- Supports custom accent color and optional background gradient
- Supports alternate app icons: `Original`, `Fog`, `Dark`, `Rainbow`
- Uses a custom bundled font treatment for manifestations

## Setup

### Requirements

- A recent Xcode version that can build an iOS 17 target and Swift Package dependencies
- An Apple developer team for signing the app and widget extension

### Local Configuration

1. Clone the repo.
2. Open `Moments.xcodeproj` in Xcode.
3. Set your development team for both targets:
   - `Moments`
   - `MomentsWidgetExtension`
4. Enable the shared App Group on both targets:
   - `group.com.tillappcounter.Moments`
5. Copy `Moments/Config.xcconfig.example` to `Moments/Config.xcconfig`.
6. Fill in the keys you need:
   - `OPENROUTER_API_KEY_*` for live AI generation
   - `REVENUECAT_API_KEY_*` for live paywall purchases
   - `REVENUECAT_ENTITLEMENT_PREMIUM` if your entitlement name differs
7. Build and run.

Notes:

- The app can still launch without OpenRouter keys, but AI generation will fail with a configuration error.
- The app can still launch without RevenueCat keys, but live purchase flows will remain unavailable.
- `Moments/Config.xcconfig` is gitignored and intended for local secrets only.

## Project Structure

- `Moments/MomentsApp.swift` - app entry point and global environment wiring
- `Moments/Features/List` - main library grid and filtering
- `Moments/Features/Add` - add/edit flows, backgrounds, symbols, widget options
- `Moments/Features/Preview` - moment preview and staged AI reveal flow
- `Moments/Features/Onboarding` - intro sheet
- `Moments/Features/Settings` - appearance, icons, calendar sync, notifications, paywall entry
- `Moments/Features/Premium` - paywall UI
- `Moments/Features/Developer` - seed data, preview toggles, paywall simulation
- `Moments/Services` - AI, calendar, notifications, image storage, subscriptions, timers
- `Moments/Persistence` - Core Data store and repository layer
- `MomentsWidgetExtension` - widget provider, widget views, App Intent configuration
- `Shared` - widget handoff models, shared defaults storage, deep links, shared helpers
- `doc` - implementation and product planning notes

## Architecture

- SwiftUI app
- Core Data persistence
- `NSFetchedResultsController`-driven repository updates
- WidgetKit + App Intents
- App Group shared storage for widget data handoff
- OpenRouter-based AI generation with schema-constrained JSON responses
- RevenueCat-based subscription plumbing

## Development Notes

- The repository currently has no XCTest or UI test targets.
- The app reloads widget timelines whenever repository data changes.
- First-launch sample data is inserted automatically if the local store is empty.
- Some planning docs in `doc/` describe future work and do not necessarily match the exact shipped implementation.

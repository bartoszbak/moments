<img width="128" height="128" alt="till-icon" src="https://github.com/user-attachments/assets/5e7e77b2-506a-4f52-8601-14b3df612aae" />

# Moments

Moments is a minimal iOS app for tracking upcoming events, past memories, and future manifestations. It includes Home Screen widgets, customizable visuals, and AI-generated reflection or manifestation copy inside each moment.

## What the app does

- Create a moment with a title, optional description, date, colors, photo, widget options, and optional symbol.
- Track upcoming and past moments in a grid.
- Support **future manifestations** as a separate mode with no fixed date.
- Open any moment into a dedicated preview screen.
- Generate AI reflection content for normal moments.
- Generate AI manifestation content for manifestation moments.
- Show small, medium, and accessory widgets with per-widget selection.
- Open a specific moment directly from a widget tap.

## Current product behavior

- **Upcoming moments** show days until the event.
- **Past moments** show days since the event.
- **Future manifestations** behave differently:
  - no target date in the main preview hero
  - no progress bar in widgets
  - simplified manifestation-specific widget layout
  - AI button label becomes `Get Manifestation`
- **Description** is edited in a dedicated screen from the add/edit flow.
- **Moment preview** reveals AI content progressively and ends with a centered sparkle icon when the full text is shown.

## Core features

- **Moments grid** with iPhone and iPad layouts
- **Moment preview** with a dedicated detail screen
- **Future manifestation mode**
- **Custom widget background**
  - preset colors
  - custom color
  - photo from library
- **Widget options**
  - optional date
  - optional SF Symbol
- **Home Screen widgets**
  - small
  - medium
  - accessory circular
  - accessory rectangular
  - accessory inline
- **Per-widget moment picker** via App Intents
- **Widget deep links** into the specific moment preview
- **Developer tools** in Settings for preview/testing flows

## AI behavior

The app uses OpenRouter for AI generation.

- Normal moments expect structured reflection output:
  - `surface`
  - `reflection`
  - `guidance`
- Future manifestations expect structured manifestation output:
  - `instruction`
  - `anchor`

These responses are rendered in the preview screen and persisted with the moment.

## Requirements

- iOS 17+
- Xcode 26 recommended

## Setup

1. Clone the repo.
2. Open `Moments.xcodeproj` in Xcode.
3. Set your development team for both:
   - `Moments`
   - `MomentsWidgetExtension`
4. Ensure the App Group `group.com.tillappcounter.Moments` is enabled on both targets.
5. For AI generation, create a local config file:
   - copy `Moments/Config.xcconfig.example` to `Moments/Config.xcconfig`
   - set a real `OPENROUTER_API_KEY`
6. Build and run.

## Project structure

- `Moments/Features/List` — main grid and list presentation
- `Moments/Features/Preview` — moment preview and AI reveal flow
- `Moments/Features/Add` — add/edit forms, background picker, symbol picker
- `Moments/Features/Settings` — settings surface
- `Moments/Features/Developer` — internal developer tools
- `Moments/Services` — AI, calendar, timers, image storage
- `Moments/Persistence` — Core Data and repository layer
- `MomentsWidgetExtension` — widget timelines and widget UI
- `Shared` — shared code used by app and widget

## Architecture

- SwiftUI app with repository-driven state
- Core Data persistence with `NSFetchedResultsController`
- WidgetKit + App Intents for widget configuration
- App Group shared storage for widget data handoff
- Dedicated preview view model for AI reveal flow
- OpenRouter chat completions with strict JSON schema responses

## Tech stack

Swift · SwiftUI · WidgetKit · App Intents · Core Data · Combine · PhotosUI · OpenRouter

## Possible admin features

Ideas only. Not implemented.

- Admin view for inspecting all stored moments and their AI state
- Re-generate AI content in bulk for selected moments
- Flag moments with missing widget assets or broken image paths
- Prompt/version audit screen showing which AI prompt produced each stored response
- Internal analytics for widget usage, manifestation usage, and reflection generation success rate
- Content moderation / quality review queue for AI outputs
- Import/export tools for backing up or restoring the local moment database

<img width="128" height="128" alt="till-icon" src="https://github.com/user-attachments/assets/5e7e77b2-506a-4f52-8601-14b3df612aae" />

# Till

A clean, minimal iOS countdown app. Add events, see how many days remain, and put a live countdown on your home screen.

## Features

- **Countdown list** — days remaining and event title at a glance
- **Home screen widget** — small and medium sizes with a shrinking progress bar
- **Custom backgrounds** — pick one of six curated colors or any color from the system picker; add a photo from your library
- **Widget countdown picker** — long-press the widget and tap Edit to choose which event to display
- **Accessory widgets** — circular, rectangular, and inline complications for Lock Screen and watch faces

## Requirements

- iOS 17+
- Xcode 16+

## Setup

1. Clone the repo
2. Open `TillApp.xcodeproj` in Xcode
3. Set your development team in Signing & Capabilities for both the **TillApp** and **TillAppWidgetExtension** targets
4. Ensure the App Group `group.com.tillappcounter.TillApp` is enabled on both targets
5. Build and run

## Architecture

- **MVVM** with `@ObservableObject` view models and `@EnvironmentObject` injection
- **Core Data** persistence via `NSFetchedResultsController` for reactive updates
- **WidgetKit** with `AppIntentConfiguration` for per-widget countdown selection
- **App Groups** shared `UserDefaults` for passing data between the app and widget extension
- Single `Timer.publish` instance driving all countdown rows — no per-row timers

## Tech Stack

Swift · SwiftUI · WidgetKit · AppIntents · Core Data · Combine · PhotosUI

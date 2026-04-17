# About Modal And Manifest Regeneration Plan

## Goal

Add an app-wide About modal, make it reachable from Settings above Developer Tools, add a developer option to show it on startup, and allow manifestations to regenerate once per day with wording that changes on each regeneration.

## Plan

1. Centralize app-level modal routing in `Moments/MomentsApp.swift` instead of keeping the intro-sheet flow local to `Moments/Features/List/CountdownListView.swift`.
   Create a shared presenter with routes like `.intro` and `.about` so the About modal can be opened from Settings now and from other screens later.

2. Add a dedicated `AboutSheetView` with only a title and description.
   Wire an `About` row into `Moments/Features/Settings/SettingsView.swift` above the existing `Developer Tools` link.

3. Add a new developer toggle in `Moments/Features/Developer/DeveloperMenuView.swift` and a stored key in `DeveloperSettingsKeys` for `forceAboutSheetOnLaunch`.
   Keep the existing `forceIntroSheetOnLaunch` unless product wants About to replace the intro flow entirely.

4. Reuse the existing manifestation persistence fields instead of adding new storage.
   `Countdown.reflectionGeneratedAt` already exists in `Moments/Models/Countdown.swift` and is already persisted through the repository, so add helper logic that answers whether a manifestation can be regenerated on the current calendar day.

5. Split manifestation generation behavior from standard reflection behavior in `Moments/Features/Preview/MomentPreviewViewModel.swift` and `Moments/Features/Preview/MomentPreviewScrollEdgeView.swift`.
   Normal reflections can keep their current expand behavior, while `isFutureManifestation` should allow one regeneration per day and overwrite the stored manifestation text when regeneration is allowed.

6. Make regenerated manifestations come back meaningfully different in `Moments/Services/ReflectionService.swift`.
   Pass the previously generated manifestation into the prompt, add an explicit instruction to avoid repeating prior phrasing and structure, and include a nonce or variation hint per request.

7. Add a lightweight similarity guard in the manifestation generation path.
   If the new output is too similar to the previous manifestation, retry once with a stronger diversification instruction before returning the result.

8. Update the manifestation CTA and state handling in the preview UI.
   Show `Get Manifestation` on first generation, `Regenerate` when the daily window is open, and a disabled or explanatory state when regeneration is still locked for the current day.

9. Verify the full flow end to end.
   Check Settings -> About, launch with `forceAboutSheetOnLaunch`, launch with `forceIntroSheetOnLaunch`, opening About from a non-settings entry point through the shared presenter, and manifestation regeneration before and after a day rollover.

## Assumption

`Open this page on startup as intro sheet` is interpreted as presenting the new About modal using the same sheet-style app-level presentation pattern as the existing intro sheet, not replacing `IntroSheetView`.

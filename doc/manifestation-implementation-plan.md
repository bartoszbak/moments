# Manifestation feature implementation plan

## Goal
Add a new "Future manifestation" moment type that behaves like a normal moment, but has no date and always stays in upcoming state.

## Product behavior
1. In Add/Edit flow, user can toggle **Future manifestation** above the date picker.
2. When enabled, the moment is stored as a manifestation and treated as always-upcoming.
3. Reflection generation uses `system.txt` + `manifest.txt` prompts.
4. UI replaces date with **Manifest** label in preview and widget surfaces.

## Data model and persistence
- Add `isFutureManifestation: Bool` to `Countdown`.
- Persist via Core Data `CountdownEntity.isFutureManifestation`.
- Sync to widget payload via `WidgetCountdown.isFutureManifestation`.

## Generation pipeline
- Keep existing JSON response contract (`surface`, `reflection`, `guidance`).
- For manifestation mode, load `manifest.txt` and combine with `system.txt`.
- Send user prompt without fixed date context.

## UX and rendering
- Add/Edit forms include new toggle in Target Date section.
- Date picker is disabled in manifestation mode.
- Progress section hidden in manifestation mode.
- List tile + widget show manifestation-specific labels.

## Follow-ups
- Add explicit migration test around old stores without `isFutureManifestation` data.
- Consider dedicated manifestation badge chip in grid card body.

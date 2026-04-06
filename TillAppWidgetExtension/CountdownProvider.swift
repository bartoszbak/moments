import WidgetKit
import AppIntents

struct CountdownEntry: TimelineEntry {
    let date: Date
    let countdown: WidgetCountdown?
}

struct CountdownProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> CountdownEntry {
        CountdownEntry(date: .now, countdown: .placeholder)
    }

    func snapshot(for configuration: SelectCountdownIntent, in context: Context) async -> CountdownEntry {
        CountdownEntry(date: .now, countdown: resolve(for: configuration))
    }

    func timeline(for configuration: SelectCountdownIntent, in context: Context) async -> Timeline<CountdownEntry> {
        let now = Date()
        let countdown = resolve(for: configuration)
        let entry = CountdownEntry(date: now, countdown: countdown)

        // Refresh at next midnight — days only change once per day
        let nextMidnight = Calendar.current.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) ?? now.addingTimeInterval(86400)

        return Timeline(entries: [entry], policy: .after(nextMidnight))
    }

    private func resolve(for configuration: SelectCountdownIntent) -> WidgetCountdown? {
        let all = SharedDataStore.countdowns
        if let selected = configuration.countdown {
            return all.first { $0.id == selected.id }
        }
        return all.first
    }
}

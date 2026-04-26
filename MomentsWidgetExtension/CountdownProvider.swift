import WidgetKit
import AppIntents

struct CountdownEntry: TimelineEntry {
    let date: Date
    let countdown: WidgetCountdown?
    let relevance: TimelineEntryRelevance?
}

struct CountdownProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> CountdownEntry {
        CountdownEntry(date: .now, countdown: .placeholder, relevance: nil)
    }

    func snapshot(for configuration: SelectCountdownIntent, in context: Context) async -> CountdownEntry {
        let now = Date()
        let countdown = resolve(for: configuration, now: now)
        return CountdownEntry(
            date: now,
            countdown: countdown,
            relevance: relevance(for: countdown, now: now)
        )
    }

    func timeline(for configuration: SelectCountdownIntent, in context: Context) async -> Timeline<CountdownEntry> {
        let now = Date()
        let countdown = resolve(for: configuration, now: now)
        let entry = CountdownEntry(
            date: now,
            countdown: countdown,
            relevance: relevance(for: countdown, now: now)
        )

        // Refresh at next midnight — days only change once per day
        let nextMidnight = Calendar.current.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) ?? now.addingTimeInterval(86400)

        return Timeline(entries: [entry], policy: .after(nextMidnight))
    }

    private func resolve(for configuration: SelectCountdownIntent, now: Date) -> WidgetCountdown? {
        let all = SharedDataStore.countdowns
        if let selected = configuration.countdown {
            if let resolvedSelection = all.first(where: { $0.id == selected.id }) {
                return resolvedSelection
            }
        }
        return defaultCountdown(from: all, now: now)
    }

    private func defaultCountdown(from countdowns: [WidgetCountdown], now: Date) -> WidgetCountdown? {
        if let today = countdowns.first(where: { $0.isToday(at: now) }) {
            return today
        }

        let upcoming = countdowns
            .filter { !$0.isFutureManifestation && !$0.isExpired(at: now) }
            .min { $0.targetDate < $1.targetDate }
        if let upcoming {
            return upcoming
        }

        if let manifestation = countdowns.first(where: \.isFutureManifestation) {
            return manifestation
        }

        return countdowns.max { $0.targetDate < $1.targetDate }
    }

    private func relevance(for countdown: WidgetCountdown?, now: Date) -> TimelineEntryRelevance? {
        guard let countdown else { return nil }

        if countdown.isFutureManifestation {
            return TimelineEntryRelevance(score: 70, duration: 24 * 60 * 60)
        }

        if countdown.isToday(at: now) {
            return TimelineEntryRelevance(score: 100, duration: 24 * 60 * 60)
        }

        if countdown.isExpired(at: now) {
            let daysSince = countdown.daysSince(from: now)
            let score = max(5, 40 - Float(daysSince))
            return TimelineEntryRelevance(score: score, duration: 12 * 60 * 60)
        }

        let daysUntil = countdown.daysUntil(from: now)
        switch daysUntil {
        case 0...1:
            return TimelineEntryRelevance(score: 95, duration: 24 * 60 * 60)
        case 2...7:
            return TimelineEntryRelevance(score: 80, duration: 24 * 60 * 60)
        case 8...30:
            return TimelineEntryRelevance(score: 60, duration: 24 * 60 * 60)
        default:
            return TimelineEntryRelevance(score: 35, duration: 24 * 60 * 60)
        }
    }
}

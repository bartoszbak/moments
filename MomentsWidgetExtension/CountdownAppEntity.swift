import AppIntents
import Foundation

struct CountdownAppEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Moment"
    static var defaultQuery = CountdownEntityQuery()

    var id: UUID
    var title: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }
}

struct CountdownEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [CountdownAppEntity] {
        SharedDataStore.countdowns
            .filter { identifiers.contains($0.id) }
            .map { CountdownAppEntity(id: $0.id, title: $0.title) }
    }

    func suggestedEntities() async throws -> [CountdownAppEntity] {
        let now = Date()

        return SharedDataStore.countdowns
            .sorted { lhs, rhs in
                sortKey(for: lhs, now: now) < sortKey(for: rhs, now: now)
            }
            .map { CountdownAppEntity(id: $0.id, title: $0.title) }
    }

    private func sortKey(for countdown: WidgetCountdown, now: Date) -> (Int, Date) {
        if countdown.isToday(at: now) {
            return (0, countdown.targetDate)
        }

        if !countdown.isFutureManifestation && !countdown.isExpired(at: now) {
            return (1, countdown.targetDate)
        }

        if countdown.isFutureManifestation {
            return (2, countdown.targetDate)
        }

        return (3, countdown.targetDate)
    }
}

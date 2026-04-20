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
        SharedDataStore.countdowns
            .map { CountdownAppEntity(id: $0.id, title: $0.title) }
    }
}

import CoreData
import Combine
import WidgetKit

@MainActor
final class CountdownRepository: NSObject, ObservableObject {
    @Published private(set) var countdowns: [Countdown] = []

    private static let initialSeedDefaultsKey = "countdowns.initialSeed.v1"

    private let viewContext: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext
    private var fetchedResultsController: NSFetchedResultsController<CountdownEntity>!

    init(viewContext: NSManagedObjectContext, backgroundContext: NSManagedObjectContext) {
        self.viewContext = viewContext
        self.backgroundContext = backgroundContext
        super.init()
        setupFRC()
    }

    private func setupFRC() {
        let request = CountdownEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "targetDate", ascending: true)]

        fetchedResultsController = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: viewContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        fetchedResultsController.delegate = self

        try? fetchedResultsController.performFetch()
        syncCountdowns()
        ensureInitialSeedIfNeeded()
    }

    private func syncCountdowns() {
        countdowns = fetchedResultsController.fetchedObjects?.compactMap { $0.toCountdown() } ?? []
        let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.tillappcounter.TillApp")
        let widgetData = countdowns.map { countdown -> WidgetCountdown in
            var sharedImagePath: String? = nil
            if let thumbURL = countdown.thumbnailImageURL, let groupURL {
                let dest = groupURL.appendingPathComponent("widget_\(countdown.id.uuidString).jpg")
                try? FileManager.default.removeItem(at: dest)
                try? FileManager.default.copyItem(at: thumbURL, to: dest)
                sharedImagePath = dest.path
            }
            return WidgetCountdown(
                id: countdown.id,
                title: countdown.title,
                targetDate: countdown.targetDate,
                createdDate: countdown.createdDate,
                backgroundColorHex: countdown.backgroundColorHex,
                backgroundImagePath: sharedImagePath,
                startPercentage: countdown.startPercentage
            )
        }
        SharedDataStore.save(widgetData)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func ensureInitialSeedIfNeeded() {
        let defaults = UserDefaults.standard
        let defaultsKey = Self.initialSeedDefaultsKey

        guard !defaults.bool(forKey: defaultsKey) else { return }

        guard countdowns.isEmpty else {
            defaults.set(true, forKey: defaultsKey)
            return
        }

        do {
            try seedInitialCountdowns()
            defaults.set(true, forKey: defaultsKey)
            try? fetchedResultsController.performFetch()
            syncCountdowns()
        } catch {
            assertionFailure("Failed to seed initial countdowns: \(error)")
        }
    }

    func seedFreshInstallData() throws {
        try seedCountdowns(items: initialSeedItems(now: Date()))
    }

    private func seedInitialCountdowns() throws {
        try seedCountdowns(items: initialSeedItems(now: Date()))
    }

    private func initialSeedItems(now: Date) -> [(title: String, targetDate: Date, backgroundColorIndex: Int)] {
        let calendar = Calendar.current

        return [
            ("Picnic", calendar.date(byAdding: .day, value: 7, to: now)!, 0),
            ("Weekend Treasure Hunt", calendar.date(byAdding: .day, value: 14, to: now)!, 1),
            ("The Super Duper Neighborhood Picnic With Way Too Many Snacks", calendar.date(byAdding: .day, value: 21, to: now)!, 2),
        ]
    }

    private func seedCountdowns(items: [(title: String, targetDate: Date, backgroundColorIndex: Int)]) throws {
        let now = Date()
        let context = viewContext

        for item in items {
            let entity = CountdownEntity(context: context)
            entity.id = UUID()
            entity.title = item.title
            entity.targetDate = item.targetDate
            entity.backgroundColorIndex = Int16(item.backgroundColorIndex)
            entity.backgroundColorHex = ColorPalette.presets[item.backgroundColorIndex].hexString
            entity.startPercentage = 1.0
            entity.createdDate = now
        }

        if context.hasChanges {
            try context.save()
        }
    }

    // MARK: - Create

    func create(
        title: String,
        targetDate: Date,
        backgroundImagePath: String? = nil,
        thumbnailImagePath: String? = nil,
        backgroundColorIndex: Int? = nil,
        backgroundColorHex: String? = nil,
        startPercentage: Double = 1.0
    ) throws {
        let context = backgroundContext
        let colorIndex = backgroundColorIndex
        let colorHex = backgroundColorHex
        try context.performAndWait {
            let entity = CountdownEntity(context: context)
            entity.id = UUID()
            entity.title = title
            entity.targetDate = targetDate
            entity.backgroundImagePath = backgroundImagePath
            entity.thumbnailImagePath = thumbnailImagePath
            entity.backgroundColorIndex = colorIndex.map { Int16($0) } ?? -1
            entity.backgroundColorHex = colorHex
            entity.startPercentage = startPercentage
            entity.createdDate = Date()
            try context.save()
        }
    }

    // MARK: - Update

    func update(
        _ countdown: Countdown,
        title: String? = nil,
        targetDate: Date? = nil,
        backgroundImagePath: String? = nil,
        thumbnailImagePath: String? = nil,
        backgroundColorIndex: Int?? = nil,
        backgroundColorHex: String?? = nil,
        startPercentage: Double? = nil
    ) throws {
        let id = countdown.id
        let context = backgroundContext
        let newColorIndex = backgroundColorIndex
        let newColorHex = backgroundColorHex
        try context.performAndWait {
            let request = CountdownEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            guard let entity = try context.fetch(request).first else { return }
            if let title { entity.title = title }
            if let targetDate { entity.targetDate = targetDate }
            if let backgroundImagePath { entity.backgroundImagePath = backgroundImagePath }
            if let thumbnailImagePath { entity.thumbnailImagePath = thumbnailImagePath }
            if let newColorIndex { entity.backgroundColorIndex = newColorIndex.map { Int16($0) } ?? -1 }
            if let newColorHex { entity.backgroundColorHex = newColorHex }
            if let startPercentage { entity.startPercentage = startPercentage }
            try context.save()
        }
    }

    // MARK: - Delete

    func deleteAll() throws {
        for countdown in countdowns {
            try delete(countdown)
        }
    }

    func delete(_ countdown: Countdown) throws {
        let id = countdown.id
        let context = backgroundContext
        try context.performAndWait {
            let request = CountdownEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            guard let entity = try context.fetch(request).first else { return }
            if let path = entity.backgroundImagePath {
                try? FileManager.default.removeItem(atPath: path)
            }
            if let path = entity.thumbnailImagePath {
                try? FileManager.default.removeItem(atPath: path)
            }
            context.delete(entity)
            try context.save()
        }
    }
}

// MARK: - NSFetchedResultsControllerDelegate

extension CountdownRepository: NSFetchedResultsControllerDelegate {
    nonisolated func controllerDidChangeContent(
        _ controller: NSFetchedResultsController<NSFetchRequestResult>
    ) {
        Task { @MainActor in
            self.syncCountdowns()
        }
    }
}

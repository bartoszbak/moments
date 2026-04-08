import CoreData
import Combine
import WidgetKit

@MainActor
final class CountdownRepository: NSObject, ObservableObject {
    @Published private(set) var countdowns: [Countdown] = []

    private static let initialSeedDefaultsKey = "countdowns.initialSeed.v1"

    private let viewContext: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext
    private let calendarService = CalendarService.shared
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
            if let groupURL {
                let dest = groupURL.appendingPathComponent("widget_\(countdown.id.uuidString).jpg")
                if let thumbURL = countdown.thumbnailImageURL,
                   FileManager.default.fileExists(atPath: thumbURL.path)
                {
                    try? FileManager.default.removeItem(at: dest)
                    try? FileManager.default.copyItem(at: thumbURL, to: dest)
                    sharedImagePath = dest.path
                } else if FileManager.default.fileExists(atPath: dest.path) {
                    // Keep the existing shared thumbnail if the original path is temporarily unavailable.
                    sharedImagePath = dest.path
                }
            }
            return WidgetCountdown(
                id: countdown.id,
                title: countdown.title,
                targetDate: countdown.targetDate,
                createdDate: countdown.createdDate,
                backgroundColorHex: countdown.backgroundColorHex,
                backgroundImagePath: sharedImagePath,
                startPercentage: countdown.startPercentage,
                showDate: countdown.showDate
            )
        }

        if let groupURL {
            let activeFileNames = Set(countdowns.map { "widget_\($0.id.uuidString).jpg" })
            let contents = (try? FileManager.default.contentsOfDirectory(
                at: groupURL,
                includingPropertiesForKeys: nil
            )) ?? []

            for fileURL in contents
            where fileURL.lastPathComponent.hasPrefix("widget_")
                && fileURL.pathExtension == "jpg"
                && !activeFileNames.contains(fileURL.lastPathComponent)
            {
                try? FileManager.default.removeItem(at: fileURL)
            }
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
            entity.targetDate = normalizedTargetDate(item.targetDate)
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
        id: UUID = UUID(),
        title: String,
        targetDate: Date,
        backgroundImagePath: String? = nil,
        thumbnailImagePath: String? = nil,
        backgroundColorIndex: Int? = nil,
        backgroundColorHex: String? = nil,
        startPercentage: Double = 1.0,
        showDate: Bool = true
    ) throws {
        let context = backgroundContext
        let colorIndex = backgroundColorIndex
        let colorHex = backgroundColorHex
        let createdDate = Date()
        let normalizedDate = normalizedTargetDate(targetDate)
        try context.performAndWait {
            let entity = CountdownEntity(context: context)
            entity.id = id
            entity.title = title
            entity.targetDate = normalizedDate
            entity.backgroundImagePath = backgroundImagePath
            entity.thumbnailImagePath = thumbnailImagePath
            entity.backgroundColorIndex = colorIndex.map { Int16($0) } ?? -1
            entity.backgroundColorHex = colorHex
            entity.startPercentage = startPercentage
            entity.showDate = showDate
            entity.createdDate = createdDate
            try context.save()
        }

        guard isCalendarIntegrationEnabled else { return }

        let countdown = Countdown(
            id: id,
            title: title,
            targetDate: normalizedDate,
            backgroundImageURL: backgroundImagePath.map { URL(fileURLWithPath: $0) },
            thumbnailImageURL: thumbnailImagePath.map { URL(fileURLWithPath: $0) },
            backgroundColorIndex: backgroundColorIndex,
            backgroundColorHex: backgroundColorHex,
            createdDate: createdDate,
            startPercentage: startPercentage,
            showDate: showDate,
            calendarEventIdentifier: nil
        )

        Task { @MainActor in
            if let eventIdentifier = await calendarService.createEvent(for: countdown) {
                try? self.updateCalendarIdentifier(id: id, eventIdentifier: eventIdentifier)
            }
        }
    }

    // MARK: - Update

    func update(
        _ countdown: Countdown,
        title: String? = nil,
        targetDate: Date? = nil,
        backgroundImagePath: String?? = nil,
        thumbnailImagePath: String?? = nil,
        backgroundColorIndex: Int?? = nil,
        backgroundColorHex: String?? = nil,
        startPercentage: Double? = nil,
        showDate: Bool? = nil
    ) throws {
        let id = countdown.id
        let context = backgroundContext
        let newColorIndex = backgroundColorIndex
        let newColorHex = backgroundColorHex
        let newImagePath = backgroundImagePath
        let newThumbPath = thumbnailImagePath
        let normalizedDate = targetDate.map(normalizedTargetDate)
        let updatedCreatedDate = normalizedDate == nil ? countdown.createdDate : Date()
        try context.performAndWait {
            let request = CountdownEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            guard let entity = try context.fetch(request).first else { return }
            if let title { entity.title = title }
            if let normalizedDate {
                entity.targetDate = normalizedDate
                entity.createdDate = updatedCreatedDate
            }
            if let newImagePath { entity.backgroundImagePath = newImagePath }
            if let newThumbPath { entity.thumbnailImagePath = newThumbPath }
            if let newColorIndex { entity.backgroundColorIndex = newColorIndex.map { Int16($0) } ?? -1 }
            if let newColorHex { entity.backgroundColorHex = newColorHex }
            if let startPercentage { entity.startPercentage = startPercentage }
            if let showDate { entity.showDate = showDate }
            try context.save()
        }

        let updatedCountdown = Countdown(
            id: countdown.id,
            title: title ?? countdown.title,
            targetDate: normalizedDate ?? countdown.targetDate,
            backgroundImageURL: resolvedFileURL(
                existing: countdown.backgroundImageURL,
                update: backgroundImagePath
            ),
            thumbnailImageURL: resolvedFileURL(
                existing: countdown.thumbnailImageURL,
                update: thumbnailImagePath
            ),
            backgroundColorIndex: resolvedValue(
                existing: countdown.backgroundColorIndex,
                update: backgroundColorIndex
            ),
            backgroundColorHex: resolvedValue(
                existing: countdown.backgroundColorHex,
                update: backgroundColorHex
            ),
            createdDate: updatedCreatedDate,
            startPercentage: startPercentage ?? countdown.startPercentage,
            showDate: showDate ?? countdown.showDate,
            calendarEventIdentifier: countdown.calendarEventIdentifier
        )

        if let eventIdentifier = countdown.calendarEventIdentifier {
            Task { @MainActor in
                await calendarService.updateEvent(identifier: eventIdentifier, for: updatedCountdown)
            }
        } else if isCalendarIntegrationEnabled {
            Task { @MainActor in
                if let eventIdentifier = await calendarService.createEvent(for: updatedCountdown) {
                    try? self.updateCalendarIdentifier(id: countdown.id, eventIdentifier: eventIdentifier)
                }
            }
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
        let calendarEventIdentifier = countdown.calendarEventIdentifier
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

        if let calendarEventIdentifier {
            Task { @MainActor in
                await calendarService.deleteEvent(identifier: calendarEventIdentifier)
            }
        }
    }

    private func updateCalendarIdentifier(id: UUID, eventIdentifier: String?) throws {
        let context = backgroundContext
        try context.performAndWait {
            let request = CountdownEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            guard let entity = try context.fetch(request).first else { return }
            entity.calendarEventIdentifier = eventIdentifier
            try context.save()
        }
    }

    private var isCalendarIntegrationEnabled: Bool {
        UserDefaults.standard.bool(forKey: AppSettingsKeys.calendarIntegrationEnabled)
    }

    private func resolvedValue<T>(existing: T?, update: T??) -> T? {
        guard let update else { return existing }
        return update
    }

    private func resolvedFileURL(existing: URL?, update: String??) -> URL? {
        guard let update else { return existing }
        return update.map { URL(fileURLWithPath: $0) }
    }

    private func normalizedTargetDate(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
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

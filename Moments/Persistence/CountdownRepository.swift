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
    private let manifestNotificationService = ManifestNotificationService.shared
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
        let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.tillappcounter.Moments")
        let widgetData = countdowns.map { countdown -> WidgetCountdown in
            var sharedImagePath: String? = nil
            if let groupURL {
                let dest = groupURL.appendingPathComponent("widget_\(countdown.id.uuidString).jpg")
                if let thumbURL = countdown.thumbnailImageURL {
                    if FileManager.default.fileExists(atPath: thumbURL.path) {
                        try? FileManager.default.removeItem(at: dest)
                        try? FileManager.default.copyItem(at: thumbURL, to: dest)
                        sharedImagePath = dest.path
                    } else if FileManager.default.fileExists(atPath: dest.path) {
                        // Keep the existing shared thumbnail if the original path is temporarily unavailable.
                        sharedImagePath = dest.path
                    }
                } else {
                    try? FileManager.default.removeItem(at: dest)
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
                showProgress: countdown.showProgress,
                showDate: countdown.showDate,
                isMinimalisticWidget: countdown.isMinimalisticWidget,
                minimalWidgetProgressStyle: countdown.minimalWidgetProgressStyle,
                widgetFontOption: countdown.widgetFontOption,
                sfSymbolName: countdown.sfSymbolName,
                isFutureManifestation: countdown.isFutureManifestation
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

        Task { @MainActor in
            await manifestNotificationService.reconcile(countdowns: countdowns)
        }
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

    private func initialSeedItems(now: Date) -> [SeedCountdownItem] {
        let calendar = Calendar.current

        return [
            SeedCountdownItem(
                title: "Move Into the New Place",
                detailsText: "You are a few months away from unpacking the essentials, arranging the first evening, and making the space feel like yours.",
                targetDate: calendar.date(byAdding: .month, value: 6, to: now)!,
                backgroundColorIndex: 2,
                sfSymbolName: "sailboat.fill",
                widgetFontOption: .rounded
            ),
            SeedCountdownItem(
                title: "Supportive People Around Me",
                detailsText: "You naturally build relationships that are calm, reciprocal, and easy to trust.",
                targetDate: now,
                backgroundColorIndex: 5,
                sfSymbolName: "sun.max.fill",
                widgetFontOption: .serif,
                isFutureManifestation: true
            ),
        ]
    }

    private func seedCountdowns(items: [SeedCountdownItem]) throws {
        let now = Date()
        let context = viewContext

        for item in items {
            let entity = CountdownEntity(context: context)
            entity.id = UUID()
            entity.title = item.title
            entity.detailsText = item.detailsText
            entity.targetDate = normalizedTargetDate(item.targetDate)
            entity.backgroundColorIndex = Int16(item.backgroundColorIndex)
            entity.backgroundColorHex = ColorPalette.presets[item.backgroundColorIndex].hexString
            entity.startPercentage = WidgetProgressDefaults.startPercentage
            entity.createdDate = now
            entity.sfSymbolName = MomentSymbolPolicy.normalized(item.sfSymbolName)
            entity.widgetFontOptionRaw = item.widgetFontOption.rawValue
            entity.isFutureManifestation = item.isFutureManifestation
        }

        if context.hasChanges {
            try context.save()
        }
    }

    private struct SeedCountdownItem {
        let title: String
        let detailsText: String?
        let targetDate: Date
        let backgroundColorIndex: Int
        let sfSymbolName: String?
        let widgetFontOption: WidgetFontOption
        let isFutureManifestation: Bool

        init(
            title: String,
            detailsText: String? = nil,
            targetDate: Date,
            backgroundColorIndex: Int,
            sfSymbolName: String? = nil,
            widgetFontOption: WidgetFontOption = .defaultOption,
            isFutureManifestation: Bool = false
        ) {
            self.title = title
            self.detailsText = detailsText
            self.targetDate = targetDate
            self.backgroundColorIndex = backgroundColorIndex
            self.sfSymbolName = sfSymbolName
            self.widgetFontOption = widgetFontOption
            self.isFutureManifestation = isFutureManifestation
        }
    }

    // MARK: - Create

    func create(
        id: UUID = UUID(),
        title: String,
        detailsText: String? = nil,
        targetDate: Date,
        backgroundImagePath: String? = nil,
        thumbnailImagePath: String? = nil,
        backgroundColorIndex: Int? = nil,
        backgroundColorHex: String? = nil,
        startPercentage: Double = WidgetProgressDefaults.startPercentage,
        showProgress: Bool = true,
        showDate: Bool = true,
        isMinimalisticWidget: Bool = false,
        minimalWidgetProgressStyle: MinimalWidgetProgressStyle = .defaultStyle,
        widgetFontOption: WidgetFontOption = .defaultOption,
        sfSymbolName: String? = nil,
        reflectionSurfaceText: String? = nil,
        reflectionText: String? = nil,
        reflectionGuidanceText: String? = nil,
        reflectionPrimaryText: String? = nil,
        reflectionExpandedText: String? = nil,
        reflectionGeneratedAt: Date? = nil,
        isFutureManifestation: Bool = false,
        manifestNotificationsEnabled: Bool = false,
        manifestNotificationRhythm: ManifestNotificationRhythm? = nil,
        manifestNotificationWeekday: Int? = nil
    ) throws {
        let context = backgroundContext
        let colorIndex = backgroundColorIndex
        let colorHex = backgroundColorHex
        let createdDate = Date()
        let normalizedDate = normalizedTargetDate(targetDate)
        let normalizedSymbolName = MomentSymbolPolicy.normalized(sfSymbolName)
        try context.performAndWait {
            let entity = CountdownEntity(context: context)
            entity.id = id
            entity.title = title
            entity.detailsText = detailsText
            entity.targetDate = normalizedDate
            entity.backgroundImagePath = backgroundImagePath
            entity.thumbnailImagePath = thumbnailImagePath
            entity.backgroundColorIndex = colorIndex.map { Int16($0) } ?? -1
            entity.backgroundColorHex = colorHex
            entity.startPercentage = startPercentage
            entity.showProgress = showProgress
            entity.showDate = showDate
            entity.isMinimalisticWidget = isMinimalisticWidget
            entity.minimalWidgetProgressStyleRaw = minimalWidgetProgressStyle.rawValue
            entity.widgetFontOptionRaw = widgetFontOption.rawValue
            entity.sfSymbolName = normalizedSymbolName
            entity.createdDate = createdDate
            entity.reflectionSurfaceText = reflectionSurfaceText
            entity.reflectionText = reflectionText
            entity.reflectionGuidanceText = reflectionGuidanceText
            entity.reflectionPrimaryText = reflectionPrimaryText
            entity.reflectionExpandedText = reflectionExpandedText
            entity.reflectionGeneratedAt = reflectionGeneratedAt
            entity.isFutureManifestation = isFutureManifestation
            entity.manifestNotificationsEnabled = manifestNotificationsEnabled
            entity.manifestNotificationRhythmRaw = manifestNotificationRhythm?.rawValue
            entity.manifestNotificationWeekday = Int16(manifestNotificationWeekday ?? -1)
            try context.save()
        }

        guard isCalendarIntegrationEnabled, !isFutureManifestation else { return }

        let countdown = Countdown(
            id: id,
            title: title,
            detailsText: detailsText,
            targetDate: normalizedDate,
            backgroundImageURL: backgroundImagePath.map { URL(fileURLWithPath: $0) },
            thumbnailImageURL: thumbnailImagePath.map { URL(fileURLWithPath: $0) },
            backgroundColorIndex: backgroundColorIndex,
            backgroundColorHex: backgroundColorHex,
            createdDate: createdDate,
            startPercentage: startPercentage,
            showProgress: showProgress,
            showDate: showDate,
            isMinimalisticWidget: isMinimalisticWidget,
            minimalWidgetProgressStyle: minimalWidgetProgressStyle,
            widgetFontOption: widgetFontOption,
            sfSymbolName: normalizedSymbolName,
            calendarEventIdentifier: nil,
            reflectionSurfaceText: reflectionSurfaceText,
            reflectionText: reflectionText,
            reflectionGuidanceText: reflectionGuidanceText,
            reflectionPrimaryText: reflectionPrimaryText,
            reflectionExpandedText: reflectionExpandedText,
            reflectionGeneratedAt: reflectionGeneratedAt,
            isFutureManifestation: isFutureManifestation,
            manifestNotificationsEnabled: manifestNotificationsEnabled,
            manifestNotificationRhythm: manifestNotificationRhythm,
            manifestNotificationWeekday: manifestNotificationWeekday
        )

        Task { @MainActor in
            await self.syncManifestNotifications(for: countdown)
        }

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
        detailsText: String?? = nil,
        targetDate: Date? = nil,
        backgroundImagePath: String?? = nil,
        thumbnailImagePath: String?? = nil,
        backgroundColorIndex: Int?? = nil,
        backgroundColorHex: String?? = nil,
        startPercentage: Double? = nil,
        showProgress: Bool? = nil,
        showDate: Bool? = nil,
        isMinimalisticWidget: Bool? = nil,
        minimalWidgetProgressStyle: MinimalWidgetProgressStyle? = nil,
        widgetFontOption: WidgetFontOption? = nil,
        sfSymbolName: String?? = nil,
        reflectionSurfaceText: String?? = nil,
        reflectionText: String?? = nil,
        reflectionGuidanceText: String?? = nil,
        reflectionPrimaryText: String?? = nil,
        reflectionExpandedText: String?? = nil,
        reflectionGeneratedAt: Date?? = nil,
        isFutureManifestation: Bool? = nil,
        manifestNotificationsEnabled: Bool? = nil,
        manifestNotificationRhythm: ManifestNotificationRhythm?? = nil,
        manifestNotificationWeekday: Int?? = nil
    ) throws {
        let id = countdown.id
        let context = backgroundContext
        let newColorIndex = backgroundColorIndex
        let newColorHex = backgroundColorHex
        let newImagePath = backgroundImagePath
        let newThumbPath = thumbnailImagePath
        let normalizedDate = targetDate.map(normalizedTargetDate)
        let newReflectionSurfaceText = reflectionSurfaceText
        let newReflectionText = reflectionText
        let newReflectionGuidanceText = reflectionGuidanceText
        let newReflectionPrimaryText = reflectionPrimaryText
        let newReflectionExpandedText = reflectionExpandedText
        let newReflectionGeneratedAt = reflectionGeneratedAt
        let newDetailsText = detailsText
        let normalizedSymbolName = sfSymbolName.map(MomentSymbolPolicy.normalized)
        let updatedCreatedDate = normalizedDate.map {
            createdDatePreservingProgress(for: countdown, newTargetDate: $0)
        } ?? countdown.createdDate
        try context.performAndWait {
            let request = CountdownEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            guard let entity = try context.fetch(request).first else { return }
            if let title { entity.title = title }
            if let newDetailsText { entity.detailsText = newDetailsText }
            if let normalizedDate {
                entity.targetDate = normalizedDate
                entity.createdDate = updatedCreatedDate
            }
            if let newImagePath { entity.backgroundImagePath = newImagePath }
            if let newThumbPath { entity.thumbnailImagePath = newThumbPath }
            if let newColorIndex { entity.backgroundColorIndex = newColorIndex.map { Int16($0) } ?? -1 }
            if let newColorHex { entity.backgroundColorHex = newColorHex }
            if let startPercentage { entity.startPercentage = startPercentage }
            if let showProgress { entity.showProgress = showProgress }
            if let showDate { entity.showDate = showDate }
            if let isMinimalisticWidget { entity.isMinimalisticWidget = isMinimalisticWidget }
            if let minimalWidgetProgressStyle { entity.minimalWidgetProgressStyleRaw = minimalWidgetProgressStyle.rawValue }
            if let widgetFontOption { entity.widgetFontOptionRaw = widgetFontOption.rawValue }
            if let normalizedSymbolName { entity.sfSymbolName = normalizedSymbolName }
            if let newReflectionSurfaceText { entity.reflectionSurfaceText = newReflectionSurfaceText }
            if let newReflectionText { entity.reflectionText = newReflectionText }
            if let newReflectionGuidanceText { entity.reflectionGuidanceText = newReflectionGuidanceText }
            if let newReflectionPrimaryText { entity.reflectionPrimaryText = newReflectionPrimaryText }
            if let newReflectionExpandedText { entity.reflectionExpandedText = newReflectionExpandedText }
            if let newReflectionGeneratedAt { entity.reflectionGeneratedAt = newReflectionGeneratedAt }
            if let isFutureManifestation { entity.isFutureManifestation = isFutureManifestation }
            if let manifestNotificationsEnabled {
                entity.manifestNotificationsEnabled = manifestNotificationsEnabled
            }
            if let manifestNotificationRhythm {
                entity.manifestNotificationRhythmRaw = manifestNotificationRhythm?.rawValue
            }
            if let manifestNotificationWeekday {
                entity.manifestNotificationWeekday = Int16(manifestNotificationWeekday ?? -1)
            }
            try context.save()
        }

        let updatedCountdown = Countdown(
            id: countdown.id,
            title: title ?? countdown.title,
            detailsText: resolvedValue(
                existing: countdown.detailsText,
                update: detailsText
            ),
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
            showProgress: showProgress ?? countdown.showProgress,
            showDate: showDate ?? countdown.showDate,
            isMinimalisticWidget: isMinimalisticWidget ?? countdown.isMinimalisticWidget,
            minimalWidgetProgressStyle: minimalWidgetProgressStyle ?? countdown.minimalWidgetProgressStyle,
            widgetFontOption: widgetFontOption ?? countdown.widgetFontOption,
            sfSymbolName: normalizedSymbolName != nil ? normalizedSymbolName! : countdown.sfSymbolName,
            calendarEventIdentifier: countdown.calendarEventIdentifier,
            reflectionSurfaceText: resolvedValue(
                existing: countdown.reflectionSurfaceText,
                update: reflectionSurfaceText
            ),
            reflectionText: resolvedValue(
                existing: countdown.reflectionText,
                update: reflectionText
            ),
            reflectionGuidanceText: resolvedValue(
                existing: countdown.reflectionGuidanceText,
                update: reflectionGuidanceText
            ),
            reflectionPrimaryText: resolvedValue(
                existing: countdown.reflectionPrimaryText,
                update: reflectionPrimaryText
            ),
            reflectionExpandedText: resolvedValue(
                existing: countdown.reflectionExpandedText,
                update: reflectionExpandedText
            ),
            reflectionGeneratedAt: resolvedValue(
                existing: countdown.reflectionGeneratedAt,
                update: reflectionGeneratedAt
            ),
            isFutureManifestation: isFutureManifestation ?? countdown.isFutureManifestation,
            manifestNotificationsEnabled: manifestNotificationsEnabled ?? countdown.manifestNotificationsEnabled,
            manifestNotificationRhythm: resolvedValue(
                existing: countdown.manifestNotificationRhythm,
                update: manifestNotificationRhythm
            ),
            manifestNotificationWeekday: resolvedValue(
                existing: countdown.manifestNotificationWeekday,
                update: manifestNotificationWeekday
            )
        )

        Task { @MainActor in
            await self.syncManifestNotifications(for: updatedCountdown)
        }

        if updatedCountdown.isFutureManifestation {
            if let eventIdentifier = countdown.calendarEventIdentifier {
                Task { @MainActor in
                    await calendarService.deleteEvent(identifier: eventIdentifier)
                    try? self.updateCalendarIdentifier(id: countdown.id, eventIdentifier: nil)
                }
            }
        } else if let eventIdentifier = countdown.calendarEventIdentifier {
            Task { @MainActor in
                let shouldSync = self.shouldSyncToCalendar(updatedCountdown)

                if shouldSync {
                    let updatedIdentifier = await calendarService.updateEvent(
                        identifier: eventIdentifier,
                        for: updatedCountdown
                    )

                    if updatedIdentifier != eventIdentifier {
                        try? self.updateCalendarIdentifier(id: countdown.id, eventIdentifier: updatedIdentifier)
                    }
                } else {
                    await calendarService.deleteEvent(identifier: eventIdentifier)
                    try? self.updateCalendarIdentifier(id: countdown.id, eventIdentifier: nil)
                }
            }
        } else if shouldSyncToCalendar(updatedCountdown) {
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

        Task { @MainActor in
            await manifestNotificationService.cancel(for: id)
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

    func reconcileCalendarEvents() async {
        let enabled = isCalendarIntegrationEnabled

        for countdown in countdowns {
            let shouldSync = enabled && shouldSyncToCalendar(countdown)

            if shouldSync {
                if let eventIdentifier = countdown.calendarEventIdentifier {
                    let updatedIdentifier = await calendarService.updateEvent(
                        identifier: eventIdentifier,
                        for: countdown
                    )

                    if updatedIdentifier != eventIdentifier {
                        try? updateCalendarIdentifier(id: countdown.id, eventIdentifier: updatedIdentifier)
                    }
                } else if let newIdentifier = await calendarService.createEvent(for: countdown) {
                    try? updateCalendarIdentifier(id: countdown.id, eventIdentifier: newIdentifier)
                }
            } else if let eventIdentifier = countdown.calendarEventIdentifier {
                await calendarService.deleteEvent(identifier: eventIdentifier)
                try? updateCalendarIdentifier(id: countdown.id, eventIdentifier: nil)
            }
        }
    }

    private func syncManifestNotifications(for countdown: Countdown) async {
        if countdown.isFutureManifestation {
            await manifestNotificationService.schedule(for: countdown)
        } else {
            await manifestNotificationService.cancel(for: countdown.id)
        }
    }

    private func shouldSyncToCalendar(_ countdown: Countdown) -> Bool {
        !countdown.isFutureManifestation && !countdown.isExpired(at: Date())
    }

    private func resolvedValue<T>(existing: T?, update: T??) -> T? {
        guard let update else { return existing }
        return update
    }

    private func resolvedFileURL(existing: URL?, update: String??) -> URL? {
        guard let update else { return existing }
        return update.map { URL(fileURLWithPath: $0) }
    }

    private func createdDatePreservingProgress(
        for countdown: Countdown,
        newTargetDate: Date,
        now: Date = Date()
    ) -> Date {
        guard !countdown.isFutureManifestation else { return countdown.createdDate }

        let originalTotalDuration = countdown.targetDate.timeIntervalSince(countdown.createdDate)
        guard originalTotalDuration > 0 else { return countdown.createdDate }

        let originalElapsedDuration = now.timeIntervalSince(countdown.createdDate)
        let progress = min(1, max(0, originalElapsedDuration / originalTotalDuration))
        let denominator = 1 - progress

        // Preserve the current progress ratio when the target date moves.
        guard denominator > .ulpOfOne else { return countdown.createdDate }

        let nowReference = now.timeIntervalSinceReferenceDate
        let targetReference = newTargetDate.timeIntervalSinceReferenceDate
        let createdReference = (nowReference - (progress * targetReference)) / denominator
        let adjustedCreatedDate = Date(timeIntervalSinceReferenceDate: createdReference)

        guard adjustedCreatedDate <= newTargetDate else { return countdown.createdDate }
        return adjustedCreatedDate
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

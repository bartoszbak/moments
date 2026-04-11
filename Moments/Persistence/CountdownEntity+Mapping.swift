import CoreData

@objc(CountdownEntity)
final class CountdownEntity: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var title: String?
    @NSManaged var targetDate: Date?
    @NSManaged var backgroundImagePath: String?
    @NSManaged var thumbnailImagePath: String?
    @NSManaged var backgroundColorIndex: Int16
    @NSManaged var backgroundColorHex: String?
    @NSManaged var startPercentage: Double
    @NSManaged var showDate: Bool
    @NSManaged var sfSymbolName: String?
    @NSManaged var calendarEventIdentifier: String?
    @NSManaged var createdDate: Date?
    @NSManaged var reflectionPrimaryText: String?
    @NSManaged var reflectionExpandedText: String?
    @NSManaged var reflectionGeneratedAt: Date?

    @nonobjc static func fetchRequest() -> NSFetchRequest<CountdownEntity> {
        NSFetchRequest<CountdownEntity>(entityName: "CountdownEntity")
    }

    func toCountdown() -> Countdown? {
        guard let id, let title, let targetDate, let createdDate else { return nil }
        let normalizedTargetDate = Calendar.current.startOfDay(for: targetDate)
        return Countdown(
            id: id,
            title: title,
            targetDate: normalizedTargetDate,
            backgroundImageURL: backgroundImagePath.map { URL(fileURLWithPath: $0) },
            thumbnailImageURL: thumbnailImagePath.map { URL(fileURLWithPath: $0) },
            backgroundColorIndex: backgroundColorIndex >= 0 ? Int(backgroundColorIndex) : nil,
            backgroundColorHex: backgroundColorHex,
            createdDate: createdDate,
            startPercentage: startPercentage > 0 ? startPercentage : 1.0,
            showDate: showDate,
            sfSymbolName: sfSymbolName,
            calendarEventIdentifier: calendarEventIdentifier,
            reflectionPrimaryText: reflectionPrimaryText,
            reflectionExpandedText: reflectionExpandedText,
            reflectionGeneratedAt: reflectionGeneratedAt
        )
    }
}

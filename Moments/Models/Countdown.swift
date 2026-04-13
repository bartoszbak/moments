import Foundation

struct Countdown: Identifiable, Hashable {
    let id: UUID
    var title: String
    var detailsText: String?
    var targetDate: Date
    var backgroundImageURL: URL?
    var thumbnailImageURL: URL?
    var backgroundColorIndex: Int?   // preset index in ColorPalette.presets
    var backgroundColorHex: String?  // custom color hex; overrides preset if set
    let createdDate: Date
    var startPercentage: Double      // progress bar starting fill (0.5 – 1.0)
    var showDate: Bool               // whether to show the target date in the widget
    var sfSymbolName: String?        // optional SF Symbol shown on the widget
    var calendarEventIdentifier: String?
    var reflectionSurfaceText: String?
    var reflectionText: String?
    var reflectionGuidanceText: String?
    var reflectionPrimaryText: String?
    var reflectionExpandedText: String?
    var reflectionGeneratedAt: Date?
    var isFutureManifestation: Bool

    func timeRemaining(from now: Date) -> TimeInterval {
        if isFutureManifestation { return .infinity }
        let startOfNow = Calendar.current.startOfDay(for: now)
        let startOfTarget = Calendar.current.startOfDay(for: targetDate)
        return max(0, startOfTarget.timeIntervalSince(startOfNow))
    }

    func isToday(at now: Date, calendar: Calendar = .current) -> Bool {
        if isFutureManifestation { return false }
        calendar.isDate(targetDate, inSameDayAs: now)
    }

    func isExpired(at now: Date, calendar: Calendar = .current) -> Bool {
        if isFutureManifestation { return false }
        let startOfNow = calendar.startOfDay(for: now)
        let startOfTarget = calendar.startOfDay(for: targetDate)
        return startOfTarget < startOfNow
    }

    func daysUntil(from now: Date, calendar: Calendar = .current) -> Int {
        if isFutureManifestation { return 0 }
        guard !isToday(at: now, calendar: calendar) else { return 0 }
        let startOfNow = calendar.startOfDay(for: now)
        let startOfTarget = calendar.startOfDay(for: targetDate)
        return max(0, calendar.dateComponents([.day], from: startOfNow, to: startOfTarget).day ?? 0)
    }

    func daysSince(from now: Date, calendar: Calendar = .current) -> Int {
        if isFutureManifestation { return 0 }
        guard !isToday(at: now, calendar: calendar) else { return 0 }
        let startOfNow = calendar.startOfDay(for: now)
        let startOfTarget = calendar.startOfDay(for: targetDate)
        return max(0, calendar.dateComponents([.day], from: startOfTarget, to: startOfNow).day ?? 0)
    }

    func components(from now: Date) -> (days: Int, hours: Int, minutes: Int, seconds: Int) {
        (daysUntil(from: now), 0, 0, 0)
    }
}

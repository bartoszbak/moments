import Foundation

struct Countdown: Identifiable, Hashable {
    let id: UUID
    var title: String
    var targetDate: Date
    var backgroundImageURL: URL?
    var thumbnailImageURL: URL?
    var backgroundColorIndex: Int?   // preset index in ColorPalette.presets
    var backgroundColorHex: String?  // custom color hex; overrides preset if set
    let createdDate: Date
    var startPercentage: Double      // progress bar starting fill (0.5 – 1.0)
    var showDate: Bool               // whether to show the target date in the widget

    func timeRemaining(from now: Date) -> TimeInterval {
        max(0, targetDate.timeIntervalSince(now))
    }

    func isToday(at now: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(targetDate, inSameDayAs: now)
    }

    func isExpired(at now: Date) -> Bool {
        targetDate <= now
    }

    func daysUntil(from now: Date, calendar: Calendar = .current) -> Int {
        guard !isToday(at: now, calendar: calendar) else { return 0 }
        let startOfNow = calendar.startOfDay(for: now)
        let startOfTarget = calendar.startOfDay(for: targetDate)
        return max(0, calendar.dateComponents([.day], from: startOfNow, to: startOfTarget).day ?? 0)
    }

    func daysSince(from now: Date, calendar: Calendar = .current) -> Int {
        guard !isToday(at: now, calendar: calendar) else { return 0 }
        let startOfNow = calendar.startOfDay(for: now)
        let startOfTarget = calendar.startOfDay(for: targetDate)
        return max(0, calendar.dateComponents([.day], from: startOfTarget, to: startOfNow).day ?? 0)
    }

    func components(from now: Date) -> (days: Int, hours: Int, minutes: Int, seconds: Int) {
        let total = Int(timeRemaining(from: now))
        return (total / 86400, (total % 86400) / 3600, (total % 3600) / 60, total % 60)
    }
}

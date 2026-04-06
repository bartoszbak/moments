import Foundation

struct Countdown: Identifiable, Hashable {
    let id: UUID
    var title: String
    var targetDate: Date
    var backgroundImageURL: URL?
    var thumbnailImageURL: URL?
    var backgroundColorIndex: Int?   // preset index (0-5)
    var backgroundColorHex: String?  // custom color hex; overrides preset if set
    let createdDate: Date

    func timeRemaining(from now: Date) -> TimeInterval {
        max(0, targetDate.timeIntervalSince(now))
    }

    func isExpired(at now: Date) -> Bool {
        targetDate <= now
    }

    func components(from now: Date) -> (days: Int, hours: Int, minutes: Int, seconds: Int) {
        let total = Int(timeRemaining(from: now))
        return (total / 86400, (total % 86400) / 3600, (total % 3600) / 60, total % 60)
    }
}

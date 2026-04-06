import Foundation

struct WidgetCountdown: Codable, Identifiable {
    let id: UUID
    let title: String
    let targetDate: Date
    let createdDate: Date
    let backgroundColorHex: String?
    let backgroundImagePath: String?

    var daysRemaining: Int {
        max(0, Int(targetDate.timeIntervalSinceNow) / 86400)
    }

    var isExpired: Bool { targetDate <= Date() }
    var isToday: Bool { !isExpired && daysRemaining == 0 }

    /// 0.0 (just created) → 1.0 (reached target)
    var progress: Double {
        let total = targetDate.timeIntervalSince(createdDate)
        guard total > 0 else { return 1 }
        let elapsed = Date().timeIntervalSince(createdDate)
        return min(1, max(0, elapsed / total))
    }
}

extension WidgetCountdown {
    static let placeholder = WidgetCountdown(
        id: UUID(),
        title: "Example Event",
        targetDate: Date().addingTimeInterval(42 * 86400),
        createdDate: Date().addingTimeInterval(-14 * 86400),
        backgroundColorHex: nil,
        backgroundImagePath: nil
    )
}

import Foundation

struct WidgetCountdown: Codable, Identifiable {
    let id: UUID
    let title: String
    let targetDate: Date
    let createdDate: Date
    let backgroundColorHex: String?
    let backgroundImagePath: String?
    let startPercentage: Double
    let showDate: Bool

    var isExpired: Bool { targetDate <= Date() }
    var isToday: Bool { Calendar.current.isDateInToday(targetDate) }

    var daysUntil: Int {
        guard !isToday else { return 0 }
        let calendar = Calendar.current
        let now = Date()
        let startOfNow = calendar.startOfDay(for: now)
        let startOfTarget = calendar.startOfDay(for: targetDate)
        return max(0, calendar.dateComponents([.day], from: startOfNow, to: startOfTarget).day ?? 0)
    }

    var daysSince: Int {
        guard !isToday else { return 0 }
        let calendar = Calendar.current
        let now = Date()
        let startOfNow = calendar.startOfDay(for: now)
        let startOfTarget = calendar.startOfDay(for: targetDate)
        return max(0, calendar.dateComponents([.day], from: startOfTarget, to: startOfNow).day ?? 0)
    }

    /// 0.0 (just created) → 1.0 (reached target)
    var progress: Double {
        let total = targetDate.timeIntervalSince(createdDate)
        guard total > 0 else { return 1 }
        let elapsed = Date().timeIntervalSince(createdDate)
        return min(1, max(0, elapsed / total))
    }

    /// Width fraction to pass to the progress bar (accounts for startPercentage)
    var barProgress: Double { startPercentage * (1 - progress) }
}

extension WidgetCountdown {
    static let placeholder = WidgetCountdown(
        id: UUID(),
        title: "Example Event",
        targetDate: Date().addingTimeInterval(42 * 86400),
        createdDate: Date().addingTimeInterval(-14 * 86400),
        backgroundColorHex: nil,
        backgroundImagePath: nil,
        startPercentage: 1.0,
        showDate: true
    )
}

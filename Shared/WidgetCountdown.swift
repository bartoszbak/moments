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
    let sfSymbolName: String?
    let isFutureManifestation: Bool

    enum CodingKeys: String, CodingKey {
        case id, title, targetDate, createdDate, backgroundColorHex, backgroundImagePath
        case startPercentage, showDate, sfSymbolName, isFutureManifestation
    }

    init(
        id: UUID,
        title: String,
        targetDate: Date,
        createdDate: Date,
        backgroundColorHex: String?,
        backgroundImagePath: String?,
        startPercentage: Double,
        showDate: Bool,
        sfSymbolName: String?,
        isFutureManifestation: Bool
    ) {
        self.id = id
        self.title = title
        self.targetDate = targetDate
        self.createdDate = createdDate
        self.backgroundColorHex = backgroundColorHex
        self.backgroundImagePath = backgroundImagePath
        self.startPercentage = startPercentage
        self.showDate = showDate
        self.sfSymbolName = MomentSymbolPolicy.normalized(sfSymbolName)
        self.isFutureManifestation = isFutureManifestation
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        targetDate = try container.decode(Date.self, forKey: .targetDate)
        createdDate = try container.decode(Date.self, forKey: .createdDate)
        backgroundColorHex = try container.decodeIfPresent(String.self, forKey: .backgroundColorHex)
        backgroundImagePath = try container.decodeIfPresent(String.self, forKey: .backgroundImagePath)
        startPercentage = try container.decode(Double.self, forKey: .startPercentage)
        showDate = try container.decode(Bool.self, forKey: .showDate)
        sfSymbolName = MomentSymbolPolicy.normalized(
            try container.decodeIfPresent(String.self, forKey: .sfSymbolName)
        )
        isFutureManifestation = try container.decodeIfPresent(Bool.self, forKey: .isFutureManifestation) ?? false
    }

    var isExpired: Bool {
        if isFutureManifestation { return false }
        let calendar = Calendar.current
        return calendar.startOfDay(for: targetDate) < calendar.startOfDay(for: Date())
    }
    var isToday: Bool {
        if isFutureManifestation { return false }
        return Calendar.current.isDateInToday(targetDate)
    }

    var daysUntil: Int {
        if isFutureManifestation { return 0 }
        guard !isToday else { return 0 }
        let calendar = Calendar.current
        let now = Date()
        let startOfNow = calendar.startOfDay(for: now)
        let startOfTarget = calendar.startOfDay(for: targetDate)
        return max(0, calendar.dateComponents([.day], from: startOfNow, to: startOfTarget).day ?? 0)
    }

    var daysSince: Int {
        if isFutureManifestation { return 0 }
        guard !isToday else { return 0 }
        let calendar = Calendar.current
        let now = Date()
        let startOfNow = calendar.startOfDay(for: now)
        let startOfTarget = calendar.startOfDay(for: targetDate)
        return max(0, calendar.dateComponents([.day], from: startOfTarget, to: startOfNow).day ?? 0)
    }

    /// 0.0 (just created) → 1.0 (reached target)
    var progress: Double {
        if isFutureManifestation { return 0 }
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
        showDate: true,
        sfSymbolName: nil,
        isFutureManifestation: false
    )
}

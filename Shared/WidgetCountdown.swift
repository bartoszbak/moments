import Foundation

struct WidgetCountdown: Codable, Identifiable {
    let id: UUID
    let title: String
    let targetDate: Date
    let createdDate: Date
    let backgroundColorHex: String?
    let backgroundImagePath: String?
    let startPercentage: Double
    let showProgress: Bool
    let showDate: Bool
    let isMinimalisticWidget: Bool
    let minimalWidgetProgressStyleRaw: String?
    let widgetFontOptionRaw: String?
    let sfSymbolName: String?
    let isFutureManifestation: Bool

    enum CodingKeys: String, CodingKey {
        case id, title, targetDate, createdDate, backgroundColorHex, backgroundImagePath
        case startPercentage, showProgress, showDate, isMinimalisticWidget, minimalWidgetProgressStyleRaw, widgetFontOptionRaw, sfSymbolName, isFutureManifestation
    }

    init(
        id: UUID,
        title: String,
        targetDate: Date,
        createdDate: Date,
        backgroundColorHex: String?,
        backgroundImagePath: String?,
        startPercentage: Double,
        showProgress: Bool,
        showDate: Bool,
        isMinimalisticWidget: Bool,
        minimalWidgetProgressStyle: MinimalWidgetProgressStyle,
        widgetFontOption: WidgetFontOption,
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
        self.showProgress = showProgress
        self.showDate = showDate
        self.isMinimalisticWidget = isMinimalisticWidget
        self.minimalWidgetProgressStyleRaw = minimalWidgetProgressStyle.rawValue
        self.widgetFontOptionRaw = widgetFontOption.rawValue
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
        showProgress = try container.decodeIfPresent(Bool.self, forKey: .showProgress) ?? true
        showDate = try container.decode(Bool.self, forKey: .showDate)
        isMinimalisticWidget = try container.decodeIfPresent(Bool.self, forKey: .isMinimalisticWidget) ?? false
        minimalWidgetProgressStyleRaw = try container.decodeIfPresent(String.self, forKey: .minimalWidgetProgressStyleRaw)
        widgetFontOptionRaw = try container.decodeIfPresent(String.self, forKey: .widgetFontOptionRaw)
        sfSymbolName = MomentSymbolPolicy.normalized(
            try container.decodeIfPresent(String.self, forKey: .sfSymbolName)
        )
        isFutureManifestation = try container.decodeIfPresent(Bool.self, forKey: .isFutureManifestation) ?? false
    }

    var widgetFontOption: WidgetFontOption {
        WidgetFontOption(rawValue: widgetFontOptionRaw ?? "") ?? .defaultOption
    }

    var minimalWidgetProgressStyle: MinimalWidgetProgressStyle {
        MinimalWidgetProgressStyle(rawValue: minimalWidgetProgressStyleRaw ?? "") ?? .defaultStyle
    }

    func isExpired(at now: Date, calendar: Calendar = .current) -> Bool {
        if isFutureManifestation { return false }
        let startOfNow = calendar.startOfDay(for: now)
        let startOfTarget = calendar.startOfDay(for: targetDate)
        return startOfTarget < startOfNow
    }

    func isToday(at now: Date, calendar: Calendar = .current) -> Bool {
        if isFutureManifestation { return false }
        return calendar.isDate(targetDate, inSameDayAs: now)
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

    var isExpired: Bool {
        isExpired(at: Date())
    }

    var isToday: Bool {
        isToday(at: Date())
    }

    var daysUntil: Int {
        daysUntil(from: Date())
    }

    var daysSince: Int {
        daysSince(from: Date())
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
        startPercentage: WidgetProgressDefaults.startPercentage,
        showProgress: true,
        showDate: true,
        isMinimalisticWidget: false,
        minimalWidgetProgressStyle: .defaultStyle,
        widgetFontOption: .defaultOption,
        sfSymbolName: nil,
        isFutureManifestation: false
    )
}

import Foundation

enum WidgetFontOption: String, CaseIterable, Identifiable {
    case `default`
    case rounded
    case serif

    var id: String { rawValue }

    static let defaultOption: WidgetFontOption = .default

    var displayName: String {
        switch self {
        case .default:
            return "Default"
        case .rounded:
            return "Rounded"
        case .serif:
            return "Serif"
        }
    }
}

enum MinimalWidgetProgressStyle: String, CaseIterable, Identifiable, Codable {
    case linear
    case circular
    case verticalBars

    var id: String { rawValue }

    static let defaultStyle: MinimalWidgetProgressStyle = .linear

    var displayName: String {
        switch self {
        case .linear:
            return "Linear"
        case .circular:
            return "Circular"
        case .verticalBars:
            return "Vertical Bars"
        }
    }
}

enum WidgetProgressDefaults {
    static let startPercentage: Double = 0.9
}

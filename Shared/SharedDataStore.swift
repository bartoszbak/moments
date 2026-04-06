import Foundation

enum SharedDataStore {
    static let groupID = "group.com.tillapp.TillApp"
    private static let key = "widget_countdowns"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: groupID)
    }

    static func save(_ countdowns: [WidgetCountdown]) {
        guard let data = try? JSONEncoder().encode(countdowns) else { return }
        defaults?.set(data, forKey: key)
    }

    static var countdowns: [WidgetCountdown] {
        guard
            let data = defaults?.data(forKey: key),
            let decoded = try? JSONDecoder().decode([WidgetCountdown].self, from: data)
        else { return [] }
        return decoded
    }
}

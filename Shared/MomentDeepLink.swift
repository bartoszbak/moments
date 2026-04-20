import Foundation

enum MomentDeepLink {
    private static let scheme = "moments"
    private static let previewHost = "preview"
    private static let countdownQueryItem = "countdownID"
    private static let deepLinkURLUserInfoKey = "deepLinkURL"

    static func previewURL(for countdownID: UUID) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = previewHost
        components.queryItems = [
            URLQueryItem(name: countdownQueryItem, value: countdownID.uuidString)
        ]
        return components.url
    }

    static func countdownID(from url: URL) -> UUID? {
        guard url.scheme?.lowercased() == scheme,
              url.host?.lowercased() == previewHost,
              let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == countdownQueryItem })?
                .value
        else {
            return nil
        }

        return UUID(uuidString: value)
    }

    static func notificationUserInfo(for countdownID: UUID) -> [AnyHashable: Any] {
        var userInfo: [AnyHashable: Any] = [
            countdownQueryItem: countdownID.uuidString
        ]

        if let url = previewURL(for: countdownID) {
            userInfo[deepLinkURLUserInfoKey] = url.absoluteString
        }

        return userInfo
    }

    static func countdownID(from userInfo: [AnyHashable: Any]) -> UUID? {
        if let urlString = userInfo[deepLinkURLUserInfoKey] as? String,
           let url = URL(string: urlString),
           let countdownID = countdownID(from: url) {
            return countdownID
        }

        guard let value = userInfo[countdownQueryItem] as? String else {
            return nil
        }

        return UUID(uuidString: value)
    }
}

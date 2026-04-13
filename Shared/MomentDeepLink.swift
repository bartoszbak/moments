import Foundation

enum MomentDeepLink {
    private static let scheme = "moments"
    private static let previewHost = "preview"
    private static let countdownQueryItem = "countdownID"

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
}

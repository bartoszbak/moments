import Foundation
import UserNotifications

@MainActor
final class ManifestNotificationService: ObservableObject {
    static let shared = ManifestNotificationService()

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let notificationCenter = UNUserNotificationCenter.current()
    private let calendar = Calendar.current

    private init() {
        Task { @MainActor in
            await refreshAuthorizationStatus()
        }
    }

    func refreshAuthorizationStatus() async {
        authorizationStatus = await currentAuthorizationStatus()
    }

    func requestAuthorization() async -> Bool {
        await refreshAuthorizationStatus()

        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            let granted = (try? await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            await refreshAuthorizationStatus()
            return granted && isAuthorizedForDelivery
        @unknown default:
            return false
        }
    }

    func schedule(for countdown: Countdown) async {
        await refreshAuthorizationStatus()

        guard isAuthorizedForDelivery, shouldSchedule(countdown) else {
            await cancel(for: countdown.id)
            return
        }

        let request = UNNotificationRequest(
            identifier: identifier(for: countdown.id),
            content: notificationContent(for: countdown),
            trigger: UNCalendarNotificationTrigger(
                dateMatching: triggerDateComponents(for: countdown),
                repeats: true
            )
        )

        notificationCenter.removePendingNotificationRequests(withIdentifiers: [request.identifier])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [request.identifier])

        try? await notificationCenter.add(request)
    }

    func sendDebugNotification(for countdown: Countdown) async -> Bool {
        let authorized = await requestAuthorization()
        guard authorized else { return false }

        let request = UNNotificationRequest(
            identifier: debugIdentifier(for: countdown.id),
            content: notificationContent(for: countdown),
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )

        notificationCenter.removePendingNotificationRequests(withIdentifiers: [request.identifier])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [request.identifier])

        do {
            try await notificationCenter.add(request)
            return true
        } catch {
            return false
        }
    }

    func cancel(for countdownID: UUID) async {
        let notificationID = identifier(for: countdownID)
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [notificationID])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [notificationID])
    }

    func reconcile(countdowns: [Countdown]) async {
        await refreshAuthorizationStatus()

        let eligibleIDs = Set(
            countdowns
                .filter { shouldSchedule($0) && isAuthorizedForDelivery }
                .map { identifier(for: $0.id) }
        )

        let existingManifestRequestIDs = Set(
            await pendingManifestNotificationIdentifiers()
        )

        let staleRequestIDs = existingManifestRequestIDs.subtracting(eligibleIDs)
        if !staleRequestIDs.isEmpty {
            let ids = Array(staleRequestIDs)
            notificationCenter.removePendingNotificationRequests(withIdentifiers: ids)
            notificationCenter.removeDeliveredNotifications(withIdentifiers: ids)
        }

        guard isAuthorizedForDelivery else { return }

        for countdown in countdowns where shouldSchedule(countdown) {
            await schedule(for: countdown)
        }
    }

    private var isAuthorizedForDelivery: Bool {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    private func shouldSchedule(_ countdown: Countdown) -> Bool {
        countdown.isFutureManifestation &&
            countdown.manifestNotificationsEnabled &&
            globalNotificationsEnabled
    }

    private var globalNotificationsEnabled: Bool {
        UserDefaults.standard.object(forKey: AppSettingsKeys.manifestNotificationsEnabled) as? Bool
            ?? AppSettingsDefaults.manifestNotificationsEnabled
    }

    private var reminderHour: Int {
        if UserDefaults.standard.object(forKey: AppSettingsKeys.manifestNotificationsHour) == nil {
            return AppSettingsDefaults.manifestNotificationsHour
        }
        return UserDefaults.standard.integer(forKey: AppSettingsKeys.manifestNotificationsHour)
    }

    private var reminderMinute: Int {
        if UserDefaults.standard.object(forKey: AppSettingsKeys.manifestNotificationsMinute) == nil {
            return AppSettingsDefaults.manifestNotificationsMinute
        }
        return UserDefaults.standard.integer(forKey: AppSettingsKeys.manifestNotificationsMinute)
    }

    private func triggerDateComponents(for countdown: Countdown) -> DateComponents {
        var components = DateComponents()
        components.hour = reminderHour
        components.minute = reminderMinute

        if countdown.manifestNotificationRhythm == .weekly {
            components.weekday = countdown.manifestNotificationWeekday
                ?? calendar.component(.weekday, from: countdown.createdDate)
        }

        return components
    }

    private func notificationContent(for countdown: Countdown) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = countdown.title
        content.body = notificationBody(for: countdown)
        content.sound = .default
        content.userInfo = MomentDeepLink.notificationUserInfo(for: countdown.id)
        return content
    }

    private func notificationBody(for countdown: Countdown) -> String {
        let guidance = countdown.reflectionGuidanceText?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let guidance, !guidance.isEmpty {
            return guidance
        }

        return "Return to your manifestation and reinforce it."
    }

    private func identifier(for countdownID: UUID) -> String {
        "manifest.\(countdownID.uuidString)"
    }

    private func debugIdentifier(for countdownID: UUID) -> String {
        "debug.manifest.\(countdownID.uuidString)"
    }

    private func currentAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await notificationSettings()
        return settings.authorizationStatus
    }

    private func notificationSettings() async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            notificationCenter.getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }

    private func pendingManifestNotificationIdentifiers() async -> [String] {
        let requests = await withCheckedContinuation { continuation in
            notificationCenter.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }

        return requests
            .map(\.identifier)
            .filter { $0.hasPrefix("manifest.") }
    }
}

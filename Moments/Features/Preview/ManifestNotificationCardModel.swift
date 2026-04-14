import Foundation
import UserNotifications

struct ManifestNotificationCardModel {
    let statusTitle: String
    let message: String
    let rhythmTitle: String
    let timeTitle: String
    let isEnabled: Bool
    let isDenied: Bool
    let isGlobalEnabled: Bool

    init(
        countdown: Countdown,
        globalNotificationsEnabled: Bool,
        authorizationStatus: UNAuthorizationStatus,
        defaultRhythm: ManifestNotificationRhythm,
        reminderDate: Date
    ) {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none

        let rhythm = countdown.manifestNotificationRhythm ?? defaultRhythm

        self.rhythmTitle = rhythm.title
        self.timeTitle = formatter.string(from: reminderDate)
        self.isEnabled = countdown.manifestNotificationsEnabled
        self.isGlobalEnabled = globalNotificationsEnabled
        self.isDenied = authorizationStatus == .denied

        if authorizationStatus == .denied {
            self.statusTitle = "Notifications blocked"
            self.message = "Open Settings to allow this manifestation to return to you."
        } else if countdown.manifestNotificationsEnabled {
            self.statusTitle = "Reminders on"
            self.message = "This manifestation will return on a \(rhythm.title.lowercased()) rhythm at \(timeTitle)."
        } else if !globalNotificationsEnabled {
            self.statusTitle = "Global reminders off"
            self.message = "Turn them on here when you want this manifestation to gently return to you."
        } else {
            self.statusTitle = "Reminders off"
            self.message = "Choose a rhythm that fits this manifestation, then turn it on when ready."
        }
    }
}

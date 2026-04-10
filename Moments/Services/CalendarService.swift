import EventKit
import Foundation

@MainActor
final class CalendarService: ObservableObject {
    static let shared = CalendarService()

    @Published private(set) var authorizationStatus: EKAuthorizationStatus

    private let eventStore = EKEventStore()

    private init() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }

    func currentAuthorizationStatus() -> EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    func refreshAuthorizationStatus() {
        authorizationStatus = currentAuthorizationStatus()
    }

    func requestAccess() async -> Bool {
        refreshAuthorizationStatus()

        switch authorizationStatus {
        case .fullAccess:
            return true
        case .denied, .restricted, .writeOnly:
            return false
        case .notDetermined:
            let granted = await withCheckedContinuation { continuation in
                eventStore.requestFullAccessToEvents { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
            refreshAuthorizationStatus()
            return granted && authorizationStatus == .fullAccess
        @unknown default:
            return false
        }
    }

    func createEvent(for countdown: Countdown) async -> String? {
        refreshAuthorizationStatus()
        guard authorizationStatus == .fullAccess else { return nil }
        guard let calendar = eventStore.defaultCalendarForNewEvents else { return nil }

        let startOfDay = Calendar.current.startOfDay(for: countdown.targetDate)
        let event = EKEvent(eventStore: eventStore)
        event.calendar = calendar
        event.title = countdown.title
        event.startDate = startOfDay
        event.endDate = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)
        event.isAllDay = true

        do {
            try eventStore.save(event, span: .thisEvent)
            return event.eventIdentifier
        } catch {
            return nil
        }
    }

    func updateEvent(identifier: String, for countdown: Countdown) async {
        refreshAuthorizationStatus()
        guard authorizationStatus == .fullAccess else { return }
        guard let event = eventStore.event(withIdentifier: identifier) else { return }

        let startOfDay = Calendar.current.startOfDay(for: countdown.targetDate)
        event.title = countdown.title
        event.startDate = startOfDay
        event.endDate = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)
        event.isAllDay = true

        do {
            try eventStore.save(event, span: .thisEvent)
        } catch {
            return
        }
    }

    func deleteEvent(identifier: String) async {
        refreshAuthorizationStatus()
        guard authorizationStatus == .fullAccess else { return }
        guard let event = eventStore.event(withIdentifier: identifier) else { return }

        do {
            try eventStore.remove(event, span: .thisEvent)
        } catch {
            return
        }
    }
}

import EventKit
import Foundation

struct CalendarSyncOption: Identifiable, Hashable {
    let id: String
    let title: String
    let sourceTitle: String

    var displayName: String {
        if sourceTitle.isEmpty || sourceTitle == title {
            return title
        }

        return "\(title) (\(sourceTitle))"
    }
}

@MainActor
final class CalendarService: ObservableObject {
    static let shared = CalendarService()

    @Published private(set) var authorizationStatus: EKAuthorizationStatus
    @Published private(set) var availableCalendars: [CalendarSyncOption] = []

    private let eventStore = EKEventStore()

    private init() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        refreshAvailableCalendars()
    }

    func currentAuthorizationStatus() -> EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    func refreshAuthorizationStatus() {
        authorizationStatus = currentAuthorizationStatus()
        refreshAvailableCalendars()
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

    func refreshAvailableCalendars() {
        guard authorizationStatus == .fullAccess else {
            availableCalendars = []
            return
        }

        let modifiableCalendars = eventStore.calendars(for: .event)
            .filter(\.allowsContentModifications)

        let preferredCalendars = modifiableCalendars.filter {
            $0.source.title.localizedCaseInsensitiveContains("iCloud")
                || $0.source.sourceType == .calDAV
        }

        let calendars = (preferredCalendars.isEmpty ? modifiableCalendars : preferredCalendars)
            .map { calendar in
                CalendarSyncOption(
                    id: calendar.calendarIdentifier,
                    title: calendar.title,
                    sourceTitle: calendar.source.title
                )
            }
            .sorted { lhs, rhs in
                lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }

        availableCalendars = calendars
    }

    func selectedCalendarName(for identifier: String?) -> String? {
        refreshAvailableCalendars()

        if let identifier, !identifier.isEmpty,
           let selected = availableCalendars.first(where: { $0.id == identifier }) {
            return selected.displayName
        }

        return defaultCalendarOption?.displayName
    }

    func createEvent(for countdown: Countdown) async -> String? {
        refreshAuthorizationStatus()
        guard authorizationStatus == .fullAccess else { return nil }
        guard let calendar = selectedCalendar() else { return nil }

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

    func updateEvent(identifier: String, for countdown: Countdown) async -> String? {
        refreshAuthorizationStatus()
        guard authorizationStatus == .fullAccess else { return nil }
        guard let calendar = selectedCalendar() else { return nil }
        guard let event = eventStore.event(withIdentifier: identifier) else {
            return await createEvent(for: countdown)
        }

        let startOfDay = Calendar.current.startOfDay(for: countdown.targetDate)
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

    private func selectedCalendar() -> EKCalendar? {
        if let selectedIdentifier = selectedCalendarIdentifier,
           let calendar = eventStore.calendar(withIdentifier: selectedIdentifier) {
            return calendar
        }

        return eventStore.defaultCalendarForNewEvents
    }

    private var selectedCalendarIdentifier: String? {
        let identifier = UserDefaults.standard.string(forKey: AppSettingsKeys.calendarSyncCalendarIdentifier)
        guard let identifier, !identifier.isEmpty else { return nil }
        return identifier
    }

    private var defaultCalendarOption: CalendarSyncOption? {
        guard let calendar = eventStore.defaultCalendarForNewEvents else { return nil }
        return CalendarSyncOption(
            id: calendar.calendarIdentifier,
            title: calendar.title,
            sourceTitle: calendar.source.title
        )
    }
}

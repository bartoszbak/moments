import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var repository: CountdownRepository
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage(AppSettingsKeys.appearance) private var appearanceSetting = AppSettingsDefaults.appearance
    @AppStorage(AppSettingsKeys.calendarIntegrationEnabled) private var isCalendarIntegrationEnabled = AppSettingsDefaults.calendarIntegrationEnabled
    @AppStorage(DeveloperSettingsKeys.showEmptyStatePreview) private var showEmptyStatePreview = false

    @StateObject private var calendarService = CalendarService.shared
    @State private var isReconcilingCalendarToggle = false
    @State private var statusMessage: String? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Mode", selection: $appearanceSetting) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                } header: {
                    Text("Appearance")
                }

                Section {
                    Toggle("Add moments to Calendar", isOn: $isCalendarIntegrationEnabled)
                        .tint(interfaceTintColor)
                } header: {
                    Text("Calendar")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Moments will appear as events in your Apple calendar.")
                        calendarFooter
                    }
                }

#if DEBUG
                developerSection
#endif
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .tint(interfaceTintColor)
            .task {
                reconcileCalendarAccessState()
            }
            .onChange(of: isCalendarIntegrationEnabled) { _, isEnabled in
                guard !isReconcilingCalendarToggle else { return }
                handleCalendarToggleChange(isEnabled)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(doneButtonColor)
                }
            }
        }
        .id(appearanceSetting)
        .preferredColorScheme(preferredColorScheme)
    }

    private var interfaceTintColor: Color {
        AppTheme.defaultInterfaceTintColor(for: effectiveColorScheme)
    }

    private var preferredColorScheme: ColorScheme? {
        AppTheme.preferredColorScheme(for: appearanceSetting)
    }

    private var effectiveColorScheme: ColorScheme {
        preferredColorScheme ?? colorScheme
    }

    private var doneButtonColor: Color {
        effectiveColorScheme == .dark ? .white : .black
    }

    @ViewBuilder
    private var calendarFooter: some View {
        switch calendarService.authorizationStatus {
        case .notDetermined:
            EmptyView()
        case .fullAccess:
            EmptyView()
        case .denied, .restricted, .writeOnly:
            VStack(alignment: .leading, spacing: 8) {
                Text("Access denied. Open Settings to allow calendar access.")
                Button("Open Settings", action: openAppSettings)
            }
        @unknown default:
            EmptyView()
        }
    }

#if DEBUG
    @ViewBuilder
    private var developerSection: some View {
        Section {
            Button("Seed Fresh Install Data") { seedFreshInstallData() }
            Button("Seed All States") { seed(.allStates) }
            Button("Seed Expired Events") { seed(.expired) }
            Button("Seed Upcoming Events") { seed(.upcoming) }
            Button("Stress Test (30 items)") { seed(.stress) }
            Toggle("Show Empty State", isOn: $showEmptyStatePreview)

            Button("Delete All Countdowns", role: .destructive) {
                try? repository.deleteAll()
                flash("Deleted all countdowns")
            }
        } header: {
            Text("Developer")
        } footer: {
            VStack(alignment: .leading, spacing: 8) {
                Text("Developer tools are only available in debug builds.")

                if let msg = statusMessage {
                    Label(msg, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }

        Section("Developer Info") {
            let now = Date()
            let expired = repository.countdowns.filter { $0.isExpired(at: now) }
            let today = repository.countdowns.filter { !$0.isExpired(at: now) && $0.components(from: now).days == 0 }
            let upcoming = repository.countdowns.filter { !$0.isExpired(at: now) && $0.components(from: now).days > 0 }

            LabeledContent("Total countdowns", value: "\(repository.countdowns.count)")
            LabeledContent("Expired", value: "\(expired.count)")
            LabeledContent("Today", value: "\(today.count)")
            LabeledContent("Upcoming", value: "\(upcoming.count)")
        }
    }

    private enum SeedSet {
        case allStates
        case expired
        case upcoming
        case stress
    }

    private func seed(_ set: SeedSet) {
        let items = seedItems(for: set)
        for (title, date, colorIdx) in items {
            let hex = colorIdx.map { ColorPalette.presets[$0].hexString }
            try? repository.create(
                title: title,
                targetDate: date,
                backgroundColorIndex: colorIdx,
                backgroundColorHex: hex,
                startPercentage: 1.0
            )
        }
        flash("Added \(items.count) items")
    }

    private func seedItems(for set: SeedSet) -> [(String, Date, Int?)] {
        let cal = Calendar.current
        let now = Date()

        switch set {
        case .allStates:
            return [
                ("Winter Holidays", cal.date(byAdding: .month, value: -6, to: now)!, 0),
                ("Team Offsite", cal.date(byAdding: .day, value: -30, to: now)!, 4),
                ("Sprint Review", cal.date(byAdding: .day, value: -3, to: now)!, 1),
                ("Product Launch", cal.date(byAdding: .day, value: -1, to: now)!, 3),
                ("Daily Standup", now, nil),
                ("Code Freeze", cal.date(byAdding: .day, value: 1, to: now)!, 2),
                ("Beta Release", cal.date(byAdding: .day, value: 4, to: now)!, 0),
                ("App Store Review", cal.date(byAdding: .day, value: 14, to: now)!, 1),
                ("WWDC", cal.date(byAdding: .month, value: 2, to: now)!, 5),
                ("New Year", cal.date(byAdding: .month, value: 6, to: now)!, 3),
            ]
        case .expired:
            return [
                ("Last Christmas", cal.date(byAdding: .year, value: -1, to: now)!, 3),
                ("Summer Vacation", cal.date(byAdding: .month, value: -4, to: now)!, 0),
                ("Conference Talk", cal.date(byAdding: .month, value: -2, to: now)!, 1),
                ("App v1.0 Launch", cal.date(byAdding: .day, value: -60, to: now)!, 4),
                ("Sprint End", cal.date(byAdding: .day, value: -2, to: now)!, 2),
            ]
        case .upcoming:
            return [
                ("Tomorrow", cal.date(byAdding: .day, value: 1, to: now)!, 2),
                ("This Weekend", cal.date(byAdding: .day, value: 3, to: now)!, 0),
                ("Next Week", cal.date(byAdding: .day, value: 7, to: now)!, 1),
                ("End of Month", cal.date(byAdding: .day, value: 20, to: now)!, 5),
                ("Next Quarter", cal.date(byAdding: .month, value: 3, to: now)!, 3),
                ("End of Year", cal.date(byAdding: .month, value: 8, to: now)!, 4),
            ]
        case .stress:
            let titles = ["Sprint", "Release", "Meeting", "Review", "Launch",
                          "Demo", "Deadline", "Holiday", "Event", "Milestone"]
            return (0..<30).map { i in
                let days = Int.random(in: -90...365)
                let title = "\(titles[i % titles.count]) \(i + 1)"
                let date = cal.date(byAdding: .day, value: days, to: now)!
                let colorIdx = Int.random(in: 0..<ColorPalette.presets.count)
                return (title, date, colorIdx)
            }
        }
    }

    private func flash(_ message: String) {
        statusMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            statusMessage = nil
        }
    }

    private func seedFreshInstallData() {
        do {
            try repository.seedFreshInstallData()
            flash("Added 3 fresh install items")
        } catch {
            flash("Failed to seed fresh install data")
        }
    }
#endif

    private func handleCalendarToggleChange(_ isEnabled: Bool) {
        guard isEnabled else { return }

        Task { @MainActor in
            let granted = await calendarService.requestAccess()
            if !granted {
                setCalendarIntegrationEnabled(false)
            }
        }
    }

    private func reconcileCalendarAccessState() {
        calendarService.refreshAuthorizationStatus()
        if isCalendarIntegrationEnabled && calendarService.authorizationStatus != .fullAccess {
            setCalendarIntegrationEnabled(false)
        }
    }

    private func setCalendarIntegrationEnabled(_ isEnabled: Bool) {
        isReconcilingCalendarToggle = true
        isCalendarIntegrationEnabled = isEnabled
        isReconcilingCalendarToggle = false
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

enum AppSettingsKeys {
    static let appearance = "settings.appearance"
    static let interfaceTintHex = "settings.interfaceTintHex"
    static let calendarIntegrationEnabled = "settings.calendarIntegration.enabled"
}

enum AppSettingsDefaults {
    static let appearance = "system"
    static let interfaceTintHex = "#0A84FF"
    static let calendarIntegrationEnabled = false
}

import SwiftUI

struct DeveloperMenuView: View {
    @EnvironmentObject private var repository: CountdownRepository

    @AppStorage(DeveloperSettingsKeys.showEmptyStatePreview) private var showEmptyStatePreview = false
    @AppStorage(DeveloperSettingsKeys.forceIntroSheetOnLaunch) private var forceIntroSheetOnLaunch = false
    @State private var statusMessage: String? = nil

    var body: some View {
        NavigationStack {
            Form {

                // MARK: - Seed Data

                Section {
                    Button("Seed Fresh Install Data") { seedFreshInstallData() }
                    Button("Seed All States") { seed(.allStates) }
                    Button("Seed Expired Events") { seed(.expired) }
                    Button("Seed Upcoming Events") { seed(.upcoming) }
                    Button("Stress Test (30 items)") { seed(.stress) }
                } header: {
                    Text("Generate Data")
                } footer: {
                    Text("Adds items without clearing existing ones.")
                }

                // MARK: - Danger

                Section {
                    Button("Delete All Countdowns", role: .destructive) {
                        try? repository.deleteAll()
                        flash("Deleted all countdowns")
                    }
                } header: {
                    Text("Danger Zone")
                }

                // MARK: - Preview

                Section {
                    Toggle("Show Empty State", isOn: $showEmptyStatePreview)
                    Toggle("Force Intro Sheet on Launch", isOn: $forceIntroSheetOnLaunch)
                } header: {
                    Text("Preview")
                } footer: {
                    Text("Use these to force preview flows without changing stored countdowns.")
                }

                // MARK: - Info

                Section {
                    let now = Date()
                    let expired = repository.countdowns.filter { $0.isExpired(at: now) }
                    let today = repository.countdowns.filter { !$0.isExpired(at: now) && $0.components(from: now).days == 0 }
                    let upcoming = repository.countdowns.filter { !$0.isExpired(at: now) && $0.components(from: now).days > 0 }
                    LabeledContent("Total countdowns", value: "\(repository.countdowns.count)")
                    LabeledContent("Expired", value: "\(expired.count)")
                    LabeledContent("Today", value: "\(today.count)")
                    LabeledContent("Upcoming", value: "\(upcoming.count)")
                } header: {
                    Text("Store Info")
                }

                // MARK: - Status

                if let msg = statusMessage {
                    Section {
                        Label(msg, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }
            .navigationTitle("Developer Menu")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Seed helpers

    private enum SeedSet { case allStates, expired, upcoming, stress }

    private func seed(_ set: SeedSet) {
        let items: [(String, Date, Int?)] = seedItems(for: set)
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
                ("Winter Holidays",   cal.date(byAdding: .month, value: -6, to: now)!, 0),
                ("Team Offsite",      cal.date(byAdding: .day,   value: -30, to: now)!, 4),
                ("Sprint Review",     cal.date(byAdding: .day,   value: -3,  to: now)!, 1),
                ("Product Launch",    cal.date(byAdding: .day,   value: -1,  to: now)!, 3),
                ("Daily Standup",     now,                                               nil),
                ("Code Freeze",       cal.date(byAdding: .day,   value: 1,   to: now)!, 2),
                ("Beta Release",      cal.date(byAdding: .day,   value: 4,   to: now)!, 0),
                ("App Store Review",  cal.date(byAdding: .day,   value: 14,  to: now)!, 1),
                ("WWDC",              cal.date(byAdding: .month, value: 2,   to: now)!, 5),
                ("New Year",          cal.date(byAdding: .month, value: 6,   to: now)!, 3),
            ]
        case .expired:
            return [
                ("Last Christmas",    cal.date(byAdding: .year,  value: -1,  to: now)!, 3),
                ("Summer Vacation",   cal.date(byAdding: .month, value: -4,  to: now)!, 0),
                ("Conference Talk",   cal.date(byAdding: .month, value: -2,  to: now)!, 1),
                ("App v1.0 Launch",   cal.date(byAdding: .day,   value: -60, to: now)!, 4),
                ("Sprint End",        cal.date(byAdding: .day,   value: -2,  to: now)!, 2),
            ]
        case .upcoming:
            return [
                ("Tomorrow",          cal.date(byAdding: .day,   value: 1,   to: now)!, 2),
                ("This Weekend",      cal.date(byAdding: .day,   value: 3,   to: now)!, 0),
                ("Next Week",         cal.date(byAdding: .day,   value: 7,   to: now)!, 1),
                ("End of Month",      cal.date(byAdding: .day,   value: 20,  to: now)!, 5),
                ("Next Quarter",      cal.date(byAdding: .month, value: 3,   to: now)!, 3),
                ("End of Year",       cal.date(byAdding: .month, value: 8,   to: now)!, 4),
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
}

enum DeveloperSettingsKeys {
    static let showEmptyStatePreview = "developer.showEmptyStatePreview"
    static let forceIntroSheetOnLaunch = "developer.forceIntroSheetOnLaunch"
}

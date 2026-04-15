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
                    Button("Seed Manifestation") { seed(.manifestation) }
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

    private enum SeedSet { case allStates, expired, upcoming, manifestation, stress }

    private func seed(_ set: SeedSet) {
        let items = seedItems(for: set)
        for item in items {
            let hex = item.backgroundColorIndex.map { ColorPalette.presets[$0].hexString }
            try? repository.create(
                title: item.title,
                detailsText: item.detailsText,
                targetDate: item.targetDate,
                backgroundColorIndex: item.backgroundColorIndex,
                backgroundColorHex: hex,
                startPercentage: 1.0,
                sfSymbolName: item.resolvedSymbolName,
                isFutureManifestation: item.isFutureManifestation
            )
        }
        flash("Added \(items.count) items")
    }

    private func seedItems(for set: SeedSet) -> [SeedDraft] {
        let cal = Calendar.current
        let now = Date()

        switch set {
        case .allStates:
            return [
                SeedDraft(
                    title: "Sofia's birthday dinner",
                    targetDate: cal.date(byAdding: .month, value: -6, to: now)!,
                    backgroundColorIndex: 0,
                    symbolCandidates: ["birthday.cake.fill", "balloon.2.fill", "party.popper.fill"]
                ),
                SeedDraft(
                    title: "Milan design weekend",
                    targetDate: cal.date(byAdding: .day, value: -30, to: now)!,
                    backgroundColorIndex: 4,
                    symbolCandidates: ["tram.fill", "camera.fill", "building.2.fill"]
                ),
                SeedDraft(
                    title: "Dinner at Nora's place",
                    targetDate: cal.date(byAdding: .day, value: -3, to: now)!,
                    backgroundColorIndex: 1,
                    symbolCandidates: ["fork.knife", "wineglass.fill", "figure.seated.side"]
                ),
                SeedDraft(
                    title: "Launch day for the new site",
                    targetDate: cal.date(byAdding: .day, value: -1, to: now)!,
                    backgroundColorIndex: 3,
                    symbolCandidates: ["paperplane.fill", "sparkles", "rocket.fill"]
                ),
                SeedDraft(
                    title: "Slow Sunday morning",
                    targetDate: now,
                    backgroundColorIndex: 5,
                    symbolCandidates: ["sun.max.fill", "cup.and.saucer.fill", "book.fill"]
                ),
                SeedDraft(
                    title: "Weekend hike above the lake",
                    targetDate: cal.date(byAdding: .day, value: 1, to: now)!,
                    backgroundColorIndex: 2,
                    symbolCandidates: ["figure.hiking", "mountain.2.fill", "leaf.fill"]
                ),
                SeedDraft(
                    title: "Train to Vienna",
                    targetDate: cal.date(byAdding: .day, value: 4, to: now)!,
                    backgroundColorIndex: 0,
                    symbolCandidates: ["train.side.front.car", "suitcase.fill", "globe.europe.africa.fill"]
                ),
                SeedDraft(
                    title: "Apartment keys handover",
                    targetDate: cal.date(byAdding: .day, value: 14, to: now)!,
                    backgroundColorIndex: 1,
                    symbolCandidates: ["key.fill", "house.fill", "door.left.hand.open"]
                ),
                SeedDraft(
                    title: "Weekend in Lisbon",
                    targetDate: cal.date(byAdding: .month, value: 2, to: now)!,
                    backgroundColorIndex: 5,
                    symbolCandidates: ["airplane", "sun.max.fill", "camera.fill"]
                ),
                SeedDraft(
                    title: "Amazing people around me",
                    detailsText: "I keep meeting warm, genuine people who make life feel full of possibility.",
                    targetDate: now,
                    backgroundColorIndex: 3,
                    symbolCandidates: ["sparkles", "heart.fill", "person.2.fill"],
                    isFutureManifestation: true
                ),
            ]
        case .expired:
            return [
                SeedDraft(
                    title: "Noah's graduation",
                    targetDate: cal.date(byAdding: .year, value: -1, to: now)!,
                    backgroundColorIndex: 3,
                    symbolCandidates: ["graduationcap.fill", "party.popper.fill", "book.fill"]
                ),
                SeedDraft(
                    title: "Summer on the coast",
                    targetDate: cal.date(byAdding: .month, value: -4, to: now)!,
                    backgroundColorIndex: 0,
                    symbolCandidates: ["sun.max.fill", "beach.umbrella.fill", "ferry.fill"]
                ),
                SeedDraft(
                    title: "Talk at product meetup",
                    targetDate: cal.date(byAdding: .month, value: -2, to: now)!,
                    backgroundColorIndex: 1,
                    symbolCandidates: ["mic.fill", "person.3.fill", "bubble.left.and.bubble.right.fill"]
                ),
                SeedDraft(
                    title: "Version 1.0 release",
                    targetDate: cal.date(byAdding: .day, value: -60, to: now)!,
                    backgroundColorIndex: 4,
                    symbolCandidates: ["app.badge.fill", "paperplane.fill", "sparkles"]
                ),
                SeedDraft(
                    title: "Sunday family lunch",
                    targetDate: cal.date(byAdding: .day, value: -2, to: now)!,
                    backgroundColorIndex: 2,
                    symbolCandidates: ["fork.knife", "figure.2.and.child.holdinghands", "house.fill"]
                ),
            ]
        case .upcoming:
            return [
                SeedDraft(
                    title: "Morning run with Elia",
                    targetDate: cal.date(byAdding: .day, value: 1, to: now)!,
                    backgroundColorIndex: 2,
                    symbolCandidates: ["figure.run", "heart.fill", "bolt.fill"]
                ),
                SeedDraft(
                    title: "Cabin weekend",
                    targetDate: cal.date(byAdding: .day, value: 3, to: now)!,
                    backgroundColorIndex: 0,
                    symbolCandidates: ["tree.fill", "flame.fill", "moon.stars.fill"]
                ),
                SeedDraft(
                    title: "Dinner with Jordan's parents",
                    targetDate: cal.date(byAdding: .day, value: 7, to: now)!,
                    backgroundColorIndex: 1,
                    symbolCandidates: ["fork.knife", "person.2.fill", "heart.fill"]
                ),
                SeedDraft(
                    title: "Studio photo shoot",
                    targetDate: cal.date(byAdding: .day, value: 20, to: now)!,
                    backgroundColorIndex: 5,
                    symbolCandidates: ["camera.fill", "sparkles", "photo.fill"]
                ),
                SeedDraft(
                    title: "Move into the new place",
                    targetDate: cal.date(byAdding: .month, value: 3, to: now)!,
                    backgroundColorIndex: 3,
                    symbolCandidates: ["house.fill", "key.fill", "shippingbox.fill"]
                ),
                SeedDraft(
                    title: "New Year's fireworks",
                    targetDate: cal.date(byAdding: .month, value: 8, to: now)!,
                    backgroundColorIndex: 4,
                    symbolCandidates: ["sparkles", "party.popper.fill", "star.fill"]
                ),
            ]
        case .manifestation:
            return [
                SeedDraft(
                    title: "Amazing people around me",
                    detailsText: "I naturally build a life surrounded by generous, grounded, deeply aligned people.",
                    targetDate: now,
                    backgroundColorIndex: 1,
                    symbolCandidates: ["sparkles", "person.2.fill", "heart.fill"],
                    isFutureManifestation: true
                )
            ]
        case .stress:
            let titles = ["Sprint", "Release", "Meeting", "Review", "Launch",
                          "Demo", "Deadline", "Holiday", "Event", "Milestone"]
            return (0..<30).map { i in
                let days = Int.random(in: -90...365)
                let title = "\(titles[i % titles.count]) \(i + 1)"
                let date = cal.date(byAdding: .day, value: days, to: now)!
                let colorIdx = Int.random(in: 0..<ColorPalette.presets.count)
                let symbolGroups = [
                    ["sparkles", "star.fill", "paperplane.fill"],
                    ["heart.fill", "person.2.fill", "figure.walk"],
                    ["airplane", "tram.fill", "car.fill"],
                    ["camera.fill", "music.note", "book.fill"],
                    ["tree.fill", "sun.max.fill", "moon.stars.fill"]
                ]

                return SeedDraft(
                    title: title,
                    targetDate: date,
                    backgroundColorIndex: colorIdx,
                    symbolCandidates: symbolGroups[i % symbolGroups.count]
                )
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

    private struct SeedDraft {
        let title: String
        let detailsText: String?
        let targetDate: Date
        let backgroundColorIndex: Int?
        let symbolCandidates: [String]
        let isFutureManifestation: Bool

        init(
            title: String,
            detailsText: String? = nil,
            targetDate: Date,
            backgroundColorIndex: Int?,
            symbolCandidates: [String] = [],
            isFutureManifestation: Bool = false
        ) {
            self.title = title
            self.detailsText = detailsText
            self.targetDate = targetDate
            self.backgroundColorIndex = backgroundColorIndex
            self.symbolCandidates = symbolCandidates
            self.isFutureManifestation = isFutureManifestation
        }

        var resolvedSymbolName: String? {
            let availableSymbols = symbolCandidates.compactMap(MomentSymbolPolicy.normalized)

            if let symbol = availableSymbols.randomElement() {
                return symbol
            }

            return MomentSymbolPolicy.defaultSymbolName
        }
    }
}

enum DeveloperSettingsKeys {
    static let showEmptyStatePreview = "developer.showEmptyStatePreview"
    static let forceIntroSheetOnLaunch = "developer.forceIntroSheetOnLaunch"
}

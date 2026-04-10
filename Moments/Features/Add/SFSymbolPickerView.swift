import SwiftUI

private struct SymbolCategory {
    let name: String
    let symbols: [String]
}

private let allCategories: [SymbolCategory] = uniqueCategories([
    SymbolCategory(name: "Celebrations", symbols: [
        "party.popper", "balloon.fill", "balloon.2.fill", "star.fill", "crown.fill",
        "gift.fill", "trophy.fill", "medal.fill", "sparkles", "rosette",
        "fireworks", "hands.clap.fill", "checkmark.seal.fill", "flag.checkered", "bell.badge.fill",
        "party.popper.fill", "balloon", "balloon.2", "star", "star.circle",
        "star.circle.fill", "star.square.fill", "flag", "flag.fill", "gift",
        "gift.circle.fill", "trophy", "trophy.circle.fill", "bell.fill", "seal.fill"
    ]),
    SymbolCategory(name: "Activities", symbols: [
        "figure.run", "figure.walk", "figure.hiking", "figure.open.water.swim",
        "figure.dance", "figure.yoga", "figure.cooldown", "dumbbell.fill",
        "sportscourt.fill", "tent.fill",
        "figure.skiing.downhill", "figure.outdoor.cycle", "figure.martial.arts",
        "figure.surfing", "figure.archery",
        "figure.walk.circle", "figure.walk.circle.fill", "figure.run.circle", "figure.run.circle.fill",
        "figure.hiking.circle", "figure.hiking.circle.fill", "figure.dance.circle", "figure.cooldown.circle",
        "dumbbell", "sportscourt", "tent", "bicycle.circle", "map", "figure.mind.and.body", "figure.pool.swim"
    ]),
    SymbolCategory(name: "Sports", symbols: [
        "soccerball", "basketball.fill", "football.fill", "baseball.fill",
        "tennis.racket", "volleyball.fill", "cricket.ball.fill",
        "skateboard.fill", "snowboard.fill", "hockey.puck.fill",
        "figure.skiing.crosscountry", "figure.boxing", "figure.strengthtraining.traditional",
        "target", "flag.2.crossed",
        "soccerball.circle", "basketball", "football", "baseball", "baseball.circle",
        "tennisball.fill", "tennisball.circle", "figure.baseball", "figure.basketball",
        "figure.american.football", "figure.tennis", "figure.volleyball", "figure.golf", "medal.star.fill", "sportscourt.circle"
    ]),
    SymbolCategory(name: "Travel", symbols: [
        "airplane", "airplane.departure", "airplane.arrival",
        "car.fill", "train.side.front.car", "ferry.fill",
        "bicycle", "map.fill", "location.fill", "globe.europe.africa.fill",
        "mountain.2.fill", "suitcase.fill",
        "bus.fill", "tram.fill", "signpost.right.fill",
        "airplane.circle", "airplane.circle.fill", "car", "car.circle.fill", "sailboat.fill",
        "ferry", "bicycle.circle.fill", "map.circle.fill", "location.circle.fill", "globe",
        "globe.americas.fill", "mountain.2", "suitcase", "tram.circle.fill", "signpost.right"
    ]),
    SymbolCategory(name: "Nature", symbols: [
        "sun.max.fill", "moon.fill", "cloud.fill", "snowflake",
        "flame.fill", "leaf.fill", "tree.fill", "drop.fill",
        "bolt.fill", "rainbow", "wind",
        "cloud.sun.fill", "cloud.rain.fill", "sun.and.horizon.fill", "tornado",
        "sun.max", "moon.stars.fill", "cloud.sun", "cloud.rain", "cloud.bolt.fill",
        "cloud.fog.fill", "snowflake.circle", "leaf.circle.fill", "tree", "drop.circle.fill",
        "bolt.circle.fill", "hurricane", "thermometer.sun", "thermometer.snowflake", "aqi.low"
    ]),
    SymbolCategory(name: "Food & Drink", symbols: [
        "fork.knife", "cup.and.saucer.fill", "birthday.cake.fill",
        "wineglass.fill", "mug.fill", "popcorn.fill",
        "takeoutbag.and.cup.and.straw.fill", "carrot.fill", "fish.fill",
        "cup.and.heat.waves.fill", "basket.fill", "cart.fill",
        "refrigerator.fill", "microwave.fill", "bag.fill",
        "fork.knife.circle", "fork.knife.circle.fill", "birthday.cake", "wineglass", "waterbottle",
        "cup.and.saucer", "takeoutbag.and.cup.and.straw", "fish.circle", "cup.and.heat.waves", "basket",
        "cart.badge.plus", "popcorn.circle.fill", "waterbottle.fill", "cart.circle.fill", "bag.circle.fill"
    ]),
    SymbolCategory(name: "Home & Lifestyle", symbols: [
        "house.fill", "heart.fill", "heart.circle.fill",
        "music.note", "camera.fill", "book.fill",
        "gamecontroller.fill", "paintbrush.fill", "bed.double.fill",
        "sofa.fill", "tv.fill", "music.mic",
        "headphones", "photo.fill", "movieclapper.fill",
        "house", "heart.square.fill", "music.note.house.fill", "camera", "camera.circle.fill",
        "books.vertical.fill", "paintpalette.fill", "bed.double", "lamp.floor.fill", "washer.fill",
        "dishwasher.fill", "shower.fill", "theatermasks.fill", "guitars.fill", "pianokeys.inverse"
    ]),
    SymbolCategory(name: "Work & Education", symbols: [
        "briefcase.fill", "graduationcap.fill", "stethoscope",
        "hammer.fill", "wrench.fill", "pencil",
        "laptopcomputer", "building.2.fill", "chart.bar.fill",
        "doc.fill", "folder.fill", "person.2.fill",
        "magnifyingglass", "lightbulb.fill", "cpu.fill",
        "briefcase", "graduationcap", "hammer", "wrench.and.screwdriver.fill", "pencil.and.outline",
        "desktopcomputer", "printer.fill", "doc.text.fill", "doc.on.doc.fill", "clipboard.fill",
        "calendar", "bookmark.fill", "paperclip", "tray.full.fill", "signature"
    ]),
])

private let allSymbols: [String] = allCategories.flatMap(\.symbols)

private func uniqueCategories(_ categories: [SymbolCategory]) -> [SymbolCategory] {
    var seen = Set<String>()

    return categories.map { category in
        let uniqueSymbols = category.symbols.filter { seen.insert($0).inserted }
        return SymbolCategory(name: category.name, symbols: uniqueSymbols)
    }
}

struct SFSymbolPickerView: View {
    @Binding var selectedSymbol: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let tintColor: Color

    @State private var searchText = ""

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    private var displayCategories: [(name: String, symbols: [String])] {
        if searchText.isEmpty {
            return allCategories.map { ($0.name, $0.symbols) }
        }
        let query = searchText.lowercased()
        let matches = allSymbols.filter { $0.contains(query) }
        return matches.isEmpty ? [] : [("Results", matches)]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    ForEach(displayCategories, id: \.name) { category in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(category.name)
                                .font(.subheadline).fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 16)

                            LazyVGrid(columns: columns, spacing: 8) {
                                ForEach(category.symbols, id: \.self) { symbol in
                                    SymbolCell(
                                        symbol: symbol,
                                        isSelected: selectedSymbol == symbol,
                                        tintColor: tintColor
                                    ) {
                                        selectedSymbol = symbol
                                        dismiss()
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }

                    if displayCategories.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                            .padding(.top, 40)
                    }
                }
                .padding(.vertical, 16)
            }
            .searchable(text: $searchText, prompt: "Search symbols")
            .navigationTitle("Choose Symbol")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                    }
                    .foregroundStyle(closeButtonColor)
                }
            }
        }
    }

    private var closeButtonColor: Color {
        colorScheme == .dark ? .white : .black
    }
}

private struct SymbolCell: View {
    let symbol: String
    let isSelected: Bool
    let tintColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(tintColor.opacity(0.2))
                        .padding(8)
                }

                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(isSelected ? tintColor : .primary)
                    .padding(12)
            }
            .aspectRatio(1, contentMode: .fit)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

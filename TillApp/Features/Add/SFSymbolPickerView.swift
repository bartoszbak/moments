import SwiftUI

private struct SymbolCategory {
    let name: String
    let symbols: [String]
}

private let allCategories: [SymbolCategory] = [
    SymbolCategory(name: "Celebrations", symbols: [
        "party.popper", "balloon.fill", "balloon.2.fill", "star.fill", "crown.fill",
        "gift.fill", "trophy.fill", "medal.fill", "sparkles", "rosette",
        "fireworks", "hands.clap.fill", "checkmark.seal.fill", "flag.checkered", "bell.badge.fill"
    ]),
    SymbolCategory(name: "Activities", symbols: [
        "figure.run", "figure.walk", "figure.hiking", "figure.swimming.open",
        "figure.dance", "figure.yoga", "figure.cooldown", "dumbbell.fill",
        "sportscourt.fill", "tent.fill",
        "figure.skiing.downhill", "figure.outdoor.cycle", "figure.martial.arts",
        "figure.surfing", "figure.archery"
    ]),
    SymbolCategory(name: "Sports", symbols: [
        "soccerball", "basketball.fill", "football.fill", "baseball.fill",
        "tennis.racket", "volleyball.fill", "cricket.ball.fill",
        "skateboard.fill", "snowboard.fill", "hockey.puck.fill",
        "figure.skiing.crosscountry", "figure.boxing", "figure.strengthtraining.traditional",
        "target", "flag.2.crossed"
    ]),
    SymbolCategory(name: "Travel", symbols: [
        "airplane", "airplane.departure", "airplane.arrival",
        "car.fill", "train.side.front.car", "ferry.fill",
        "bicycle", "map.fill", "location.fill", "globe.europe.africa.fill",
        "mountain.2.fill", "suitcase.fill",
        "bus.fill", "tram.fill", "signpost.right.fill"
    ]),
    SymbolCategory(name: "Nature", symbols: [
        "sun.max.fill", "moon.fill", "cloud.fill", "snowflake",
        "flame.fill", "leaf.fill", "tree.fill", "drop.fill",
        "bolt.fill", "rainbow", "wind",
        "cloud.sun.fill", "cloud.rain.fill", "sun.and.horizon.fill", "tornado"
    ]),
    SymbolCategory(name: "Food & Drink", symbols: [
        "fork.knife", "cup.and.saucer.fill", "birthday.cake.fill",
        "wineglass.fill", "mug.fill", "popcorn.fill",
        "takeoutbag.and.cup.and.straw.fill", "carrot.fill", "fish.fill",
        "cup.and.heat.waves.fill", "basket.fill", "cart.fill",
        "refrigerator.fill", "microwave.fill", "bag.fill"
    ]),
    SymbolCategory(name: "Home & Lifestyle", symbols: [
        "house.fill", "heart.fill", "heart.circle.fill",
        "music.note", "camera.fill", "book.fill",
        "gamecontroller.fill", "paintbrush.fill", "bed.double.fill",
        "sofa.fill", "tv.fill", "music.mic",
        "headphones", "photo.fill", "movieclapper.fill"
    ]),
    SymbolCategory(name: "Work & Education", symbols: [
        "briefcase.fill", "graduationcap.fill", "stethoscope",
        "hammer.fill", "wrench.fill", "pencil",
        "laptopcomputer", "building.2.fill", "chart.bar.fill",
        "doc.fill", "folder.fill", "person.2.fill",
        "magnifyingglass", "lightbulb.fill", "cpu.fill"
    ]),
]

private let allSymbols: [String] = allCategories.flatMap(\.symbols)

struct SFSymbolPickerView: View {
    @Binding var selectedSymbol: String?
    @Environment(\.dismiss) private var dismiss

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
                LazyVStack(alignment: .leading, spacing: 24, pinnedViews: []) {
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
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search symbols")
            .navigationTitle("Choose Symbol")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                            .font(.title3)
                    }
                }
            }
        }
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
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? tintColor.opacity(0.15) : Color(.secondarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(isSelected ? tintColor : Color.clear, lineWidth: 2)
                    )

                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(isSelected ? tintColor : .primary)
                    .padding(12)
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(.plain)
    }
}

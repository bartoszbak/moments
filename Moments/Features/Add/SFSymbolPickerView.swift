import SwiftUI

private struct SymbolCategory {
    let name: String
    let symbols: [String]
}

private let allCategories: [SymbolCategory] = uniqueCategories([
    SymbolCategory(name: "Celebrations", symbols: [
        "party.popper.fill", "balloon.fill", "balloon.2.fill", "star.fill", "star.circle.fill",
        "star.square.fill", "crown.fill", "gift.fill", "gift.circle.fill", "trophy.fill",
        "trophy.circle.fill", "medal.fill", "medal.star.fill", "rosette", "checkmark.seal.fill",
        "bell.badge.fill", "flag.fill", "flag.checkered.2.crossed", "fireworks", "sparkles"
    ]),
    SymbolCategory(name: "Wellness", symbols: [
        "figure.run.circle.fill", "figure.walk.circle.fill", "figure.hiking.circle.fill", "figure.cooldown.circle.fill",
        "figure.mind.and.body.circle.fill", "figure.outdoor.cycle.circle.fill", "figure.open.water.swim.circle.fill",
        "figure.yoga", "dumbbell.fill", "sportscourt.fill", "tennisball.fill", "basketball.fill",
        "soccerball", "football.fill", "baseball.fill", "volleyball.fill",
        "snowboard.fill", "skateboard.fill", "tent.fill", "mountain.2.fill"
    ]),
    SymbolCategory(name: "Sports", symbols: [
        "basketball.fill", "football.fill", "baseball.fill", "tennisball.fill",
        "volleyball.fill", "cricket.ball.fill", "hockey.puck.fill", "soccerball.inverse",
        "figure.baseball.circle.fill", "figure.basketball.circle.fill", "figure.american.football.circle.fill",
        "figure.tennis.circle.fill", "figure.golf.circle.fill", "figure.boxing.circle.fill",
        "figure.strengthtraining.traditional.circle.fill", "target", "flag.checkered.2.crossed"
    ]),
    SymbolCategory(name: "Travel", symbols: [
        "airplane.circle.fill", "car.fill", "car.circle.fill", "bus.fill",
        "tram.fill", "ferry.fill", "sailboat.fill", "bicycle.circle.fill",
        "map.fill", "map.circle.fill", "location.fill", "location.circle.fill",
        "signpost.right.fill", "suitcase.fill", "globe.europe.africa.fill", "globe.americas.fill",
        "globe.asia.australia.fill", "mountain.2.fill"
    ]),
    SymbolCategory(name: "Nature", symbols: [
        "sun.max.fill", "moon.fill", "moon.stars.fill", "cloud.fill",
        "cloud.sun.fill", "cloud.rain.fill", "cloud.bolt.fill", "cloud.fog.fill",
        "sun.and.horizon.fill", "snowflake.circle.fill", "flame.fill", "drop.fill",
        "drop.circle.fill", "bolt.fill", "bolt.circle.fill", "leaf.fill",
        "leaf.circle.fill", "tree.fill", "aqi.low", "hurricane"
    ]),
    SymbolCategory(name: "Food & Drink", symbols: [
        "fork.knife.circle.fill", "cup.and.saucer.fill", "cup.and.heat.waves.fill", "birthday.cake.fill",
        "wineglass.fill", "waterbottle.fill", "mug.fill", "popcorn.fill",
        "popcorn.circle.fill", "takeoutbag.and.cup.and.straw.fill", "basket.fill", "bag.fill",
        "bag.circle.fill", "cart.fill", "cart.circle.fill", "carrot.fill",
        "fish.fill", "refrigerator.fill", "microwave.fill"
    ]),
    SymbolCategory(name: "Home & Lifestyle", symbols: [
        "house.fill", "heart.fill", "heart.circle.fill", "heart.square.fill",
        "camera.fill", "camera.circle.fill", "photo.fill", "book.fill",
        "books.vertical.fill", "music.note.house.fill", "gamecontroller.fill", "paintbrush.fill",
        "paintpalette.fill", "bed.double.fill", "sofa.fill", "lamp.floor.fill",
        "washer.fill", "dishwasher.fill", "shower.fill", "tv.fill",
        "movieclapper.fill", "theatermasks.fill", "guitars.fill"
    ]),
    SymbolCategory(name: "Work & Education", symbols: [
        "briefcase.fill", "graduationcap.fill", "building.2.fill", "person.2.fill",
        "doc.fill", "doc.text.fill", "doc.on.doc.fill", "folder.fill",
        "clipboard.fill", "bookmark.fill", "tray.full.fill", "printer.fill",
        "chart.bar.fill", "chart.line.uptrend.xyaxis", "lightbulb.fill", "wrench.and.screwdriver.fill",
        "hammer.fill", "cpu.fill", "display.and.arrow.down", "signature"
    ]),
    SymbolCategory(name: "Health", symbols: [
        "cross.case.fill", "cross.vial.fill", "stethoscope.circle.fill", "pills.fill",
        "bandage.fill", "syringe.fill", "heart.text.square.fill", "lungs.fill",
        "allergens.fill", "facemask.fill", "figure.run.circle.fill", "figure.cooldown.circle.fill",
        "waveform.path.ecg", "brain.head.profile", "eye.fill", "ear.fill"
    ]),
    SymbolCategory(name: "Technology", symbols: [
        "laptopcomputer.and.iphone", "desktopcomputer", "ipad", "iphone",
        "applewatch.watchface", "visionpro.fill", "airpodsmax", "headphones.circle.fill",
        "keyboard.fill", "printer.fill", "wifi", "antenna.radiowaves.left.and.right",
        "bolt.horizontal.circle.fill", "externaldrive.fill", "internaldrive.fill", "server.rack"
    ]),
    SymbolCategory(name: "Creativity", symbols: [
        "camera.fill", "photo.stack.fill", "video.fill", "film.fill",
        "music.note.list", "music.mic.circle.fill", "mic.fill", "pianokeys.inverse",
        "guitars.fill", "paintbrush.pointed.fill", "paintpalette.fill", "theatermasks.fill",
        "book.closed.fill", "book.pages.fill", "quote.bubble.fill", "sparkles.tv.fill"
    ]),
    SymbolCategory(name: "Finance", symbols: [
        "creditcard.fill", "banknote.fill", "wallet.pass.fill", "chart.pie.fill",
        "chart.bar.fill", "chart.line.uptrend.xyaxis.circle.fill", "building.columns.fill",
        "briefcase.fill", "cart.fill", "bag.fill", "gift.fill", "medal.fill",
        "trophy.fill", "dollarsign.circle.fill", "eurosign.circle.fill", "sterlingsign.circle.fill"
    ]),
    SymbolCategory(name: "Pets & Family", symbols: [
        "dog.fill", "cat.fill", "pawprint.fill", "bird.fill",
        "fish.fill", "tortoise.fill", "hare.fill", "person.fill",
        "person.2.fill", "figure.2.and.child.holdinghands", "figure.and.child.holdinghands",
        "house.heart.fill", "heart.fill", "balloon.fill", "gift.fill", "birthday.cake.fill"
    ]),
])

private let allSymbols: [String] = allCategories.flatMap(\.symbols)

private func uniqueCategories(_ categories: [SymbolCategory]) -> [SymbolCategory] {
    var seen = Set<String>()

    return categories.map { category in
        let uniqueSymbols = category.symbols.filter {
            guard MomentSymbolPolicy.normalized($0) != nil else { return false }
            return seen.insert($0).inserted
        }
        return SymbolCategory(name: category.name, symbols: uniqueSymbols)
    }.filter { !$0.symbols.isEmpty }
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

import SwiftUI

private struct SymbolCategory {
    let name: String
    let symbols: [String]
}

private func symbolCategory(_ name: String, _ symbols: String) -> SymbolCategory {
    SymbolCategory(
        name: name,
        symbols: symbols
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    )
}

private func uniqueSymbolsPreservingOrder(_ symbols: [String]) -> [String] {
    var seen = Set<String>()

    return symbols.filter { seen.insert($0).inserted }
}

private let allCategories: [SymbolCategory] = uniqueCategories([
    symbolCategory("Celebrations", """
        party.popper.fill
        balloon.fill
        balloon.2.fill
        birthday.cake.fill
        bubbles.and.sparkles.fill
        sparkle
        sparkles.rectangle.stack.fill
        sparkles.tv.fill
        rectangle.badge.sparkles.fill
        hands.and.sparkles.fill
        hands.sparkles.fill
        star.fill
        star.circle.fill
        star.square.fill
        star.rectangle.fill
        star.hexagon.fill
        star.bubble.fill
        star.square.on.square.fill
        star.leadinghalf.fill
        crown.fill
        gift.fill
        gift.circle.fill
        giftcard.fill
        trophy.fill
        trophy.circle.fill
        medal.fill
        medal.star.fill
        seal.fill
        checkmark.seal.fill
        checkmark.seal.text.page.fill
        bell.fill
        bell.circle.fill
        bell.square.fill
        bell.badge.fill
        bell.badge.circle.fill
        bell.and.waveform.fill
        bell.and.waves.left.and.right.fill
        flag.fill
        flag.circle.fill
        flag.square.fill
        flag.2.crossed.fill
        flag.2.crossed.circle.fill
        flag.checkered.circle.fill
        flag.pattern.checkered.circle.fill
        heart.fill
        heart.circle.fill
        heart.square.fill
        heart.rectangle.fill
        light.ribbon.fill
        moon.stars.fill
        staroflife.fill
        """),
    symbolCategory("Wellness", """
        dumbbell.fill
        figure.barre.circle.fill
        figure.climbing.circle.fill
        figure.cooldown.circle.fill
        figure.core.training.circle.fill
        figure.cross.training.circle.fill
        figure.dance.circle.fill
        figure.elliptical.circle.fill
        figure.flexibility.circle.fill
        figure.hand.cycling.circle.fill
        figure.highintensity.intervaltraining.circle.fill
        figure.hiking.circle.fill
        figure.indoor.cycle.circle.fill
        figure.indoor.rowing.circle.fill
        figure.jumprope.circle.fill
        figure.mind.and.body.circle.fill
        figure.mixed.cardio.circle.fill
        figure.open.water.swim.circle.fill
        figure.outdoor.cycle.circle.fill
        figure.outdoor.rowing.circle.fill
        figure.pilates.circle.fill
        figure.pool.swim.circle.fill
        figure.roll.circle.fill
        figure.roll.runningpace.circle.fill
        figure.rolling.circle.fill
        figure.run.circle.fill
        figure.run.square.stack.fill
        figure.run.treadmill.circle.fill
        figure.sailing.circle.fill
        figure.skateboarding.circle.fill
        figure.skiing.crosscountry.circle.fill
        figure.skiing.downhill.circle.fill
        figure.snowboarding.circle.fill
        figure.socialdance.circle.fill
        figure.stair.stepper.circle.fill
        figure.stairs.circle.fill
        figure.step.training.circle.fill
        figure.strengthtraining.functional.circle.fill
        figure.strengthtraining.traditional.circle.fill
        figure.surfing.circle.fill
        figure.taichi.circle.fill
        figure.walk.circle.fill
        figure.walk.diamond.fill
        figure.walk.suitcase.rolling.circle.fill
        figure.walk.treadmill.circle.fill
        figure.walk.triangle.fill
        figure.water.fitness.circle.fill
        figure.wave.circle.fill
        figure.yoga.circle.fill
        mountain.2.circle.fill
        """),
    symbolCategory("Sports", """
        american.football.circle.fill
        american.football.fill
        american.football.professional.circle.fill
        american.football.professional.fill
        australian.football.circle.fill
        australian.football.fill
        baseball.circle.fill
        baseball.fill
        basketball.circle.fill
        basketball.fill
        cricket.ball.circle.fill
        cricket.ball.fill
        dumbbell.fill
        figure.american.football.circle.fill
        figure.archery.circle.fill
        figure.australian.football.circle.fill
        figure.badminton.circle.fill
        figure.baseball.circle.fill
        figure.basketball.circle.fill
        figure.bowling.circle.fill
        figure.boxing.circle.fill
        figure.cricket.circle.fill
        figure.curling.circle.fill
        figure.disc.sports.circle.fill
        figure.equestrian.sports.circle.fill
        figure.fencing.circle.fill
        figure.field.hockey.circle.fill
        figure.fishing.circle.fill
        figure.golf.circle.fill
        figure.gymnastics.circle.fill
        figure.handball.circle.fill
        figure.hockey.circle.fill
        figure.ice.hockey.circle.fill
        figure.ice.skating.circle.fill
        figure.indoor.soccer.circle.fill
        figure.kickboxing.circle.fill
        figure.lacrosse.circle.fill
        figure.martial.arts.circle.fill
        figure.outdoor.soccer.circle.fill
        figure.pickleball.circle.fill
        figure.racquetball.circle.fill
        figure.rugby.circle.fill
        figure.skateboarding.circle.fill
        figure.skiing.crosscountry.circle.fill
        figure.skiing.downhill.circle.fill
        figure.snowboarding.circle.fill
        figure.softball.circle.fill
        figure.squash.circle.fill
        figure.surfing.circle.fill
        figure.table.tennis.circle.fill
        """),
    symbolCategory("Travel", """
        air.car.side.fill
        airplane.circle.fill
        airplane.ticket.fill
        airplane.up.forward
        airplane.up.right.app.fill
        bicycle.circle.fill
        bicycle.sensor.tag.radiowaves.left.and.right.fill
        bus.doubledecker.fill
        bus.fill
        cablecar.fill
        car.circle.fill
        car.fill
        car.side.and.exclamationmark.fill
        car.side.fill
        car.side.front.open.crop.fill
        car.side.front.open.fill
        checkmark.circle.badge.airplane.fill
        clock.badge.airplane.fill
        ferry.fill
        fuelpump.arrowtriangle.left.fill
        fuelpump.arrowtriangle.right.fill
        fuelpump.circle.fill
        fuelpump.exclamationmark.fill
        fuelpump.fill
        fuelpump.slash.fill
        fuelpump.thermometer.fill
        globe.americas.fill
        globe.asia.australia.fill
        globe.badge.clock.fill
        globe.central.south.asia.fill
        globe.desk.fill
        globe.europe.africa.fill
        globe.fill
        location.app.fill
        location.circle.fill
        location.fill
        location.north.circle.fill
        location.north.fill
        location.north.line.fill
        location.slash.circle.fill
        location.slash.fill
        location.square.fill
        map.circle.fill
        map.fill
        mappin.and.ellipse.circle.fill
        mappin.circle.fill
        sailboat.circle.fill
        sailboat.fill
        signpost.right.circle.fill
        signpost.right.fill
        """),
    symbolCategory("Nature", """
        leaf.fill
        leaf.circle.fill
        flame.fill
        flame.circle.fill
        drop.fill
        drop.circle.fill
        drop.triangle.fill
        bolt.fill
        bolt.circle.fill
        bolt.slash.fill
        bolt.slash.circle.fill
        cloud.fill
        cloud.circle.fill
        cloud.drizzle.fill
        cloud.drizzle.circle.fill
        cloud.rain.fill
        cloud.rain.circle.fill
        cloud.heavyrain.fill
        cloud.heavyrain.circle.fill
        cloud.bolt.fill
        cloud.bolt.circle.fill
        cloud.bolt.rain.fill
        cloud.bolt.rain.circle.fill
        cloud.fog.fill
        cloud.fog.circle.fill
        cloud.hail.fill
        cloud.hail.circle.fill
        cloud.sleet.fill
        cloud.sleet.circle.fill
        cloud.snow.fill
        cloud.snow.circle.fill
        cloud.sun.fill
        cloud.sun.circle.fill
        cloud.sun.bolt.fill
        cloud.sun.bolt.circle.fill
        cloud.sun.rain.fill
        cloud.sun.rain.circle.fill
        cloud.moon.fill
        cloud.moon.circle.fill
        cloud.moon.bolt.fill
        cloud.moon.bolt.circle.fill
        cloud.moon.rain.fill
        cloud.moon.rain.circle.fill
        cloud.rainbow.crop.fill
        bird.fill
        bird.circle.fill
        fish.fill
        fish.circle.fill
        hare.fill
        hare.circle.fill
        """),
    symbolCategory("Food & Drink", """
        bag.fill
        bag.circle.fill
        basket.fill
        birthday.cake.fill
        carrot.fill
        cart.fill
        cart.circle.fill
        cart.badge.clock.fill
        cooktop.fill
        cup.and.heat.waves.fill
        cup.and.saucer.fill
        dishwasher.fill
        dishwasher.circle.fill
        fish.fill
        fish.circle.fill
        fork.knife.circle.fill
        frying.pan.fill
        giftcard.fill
        microwave.fill
        mug.fill
        oven.fill
        popcorn.fill
        popcorn.circle.fill
        refrigerator.fill
        storefront.fill
        storefront.circle.fill
        stove.fill
        tag.fill
        tag.circle.fill
        tag.square.fill
        tag.slash.fill
        takeoutbag.and.cup.and.straw.fill
        ticket.fill
        ticket.circle.fill
        wallet.bifold.fill
        wallet.pass.fill
        wallet.sensor.tag.radiowaves.left.and.right.fill
        waterbottle.fill
        wineglass.fill
        handbag.fill
        handbag.circle.fill
        handbag.sensor.tag.radiowaves.left.and.right.fill
        duffle.bag.fill
        gym.bag.fill
        suitcase.cart.fill
        airplane.ticket.fill
        airtag.fill
        airtag.radiowaves.forward.fill
        ivfluid.bag.fill
        backpack.sensor.tag.radiowaves.left.and.right.fill
        """),
    symbolCategory("Home & Lifestyle", """
        house.fill
        house.circle.fill
        house.badge.wifi.fill
        house.slash.fill
        bed.double.fill
        bed.double.circle.fill
        bed.double.badge.checkmark.fill
        chair.fill
        chair.lounge.fill
        sofa.fill
        table.furniture.fill
        fan.fill
        fan.circle.fill
        fan.ceiling.fill
        fan.and.light.ceiling.fill
        fan.desk.fill
        fan.floor.fill
        fan.oscillation.fill
        fan.slash.fill
        lamp.ceiling.fill
        lamp.desk.fill
        lamp.floor.fill
        lamp.table.fill
        lightbulb.fill
        lightbulb.circle.fill
        lightbulb.2.fill
        lightbulb.led.fill
        lightbulb.led.wide.fill
        lightbulb.max.fill
        lightbulb.min.fill
        lightbulb.min.badge.exclamationmark.fill
        lightbulb.slash.fill
        cooktop.fill
        oven.fill
        stove.fill
        dishwasher.fill
        dishwasher.circle.fill
        washer.fill
        washer.circle.fill
        shower.fill
        shower.handheld.fill
        shower.sidejet.fill
        toilet.fill
        toilet.circle.fill
        fireplace.fill
        video.doorbell.fill
        web.camera.fill
        camera.fill
        photo.fill
        tv.fill
        """),
    symbolCategory("Work & Education", """
        briefcase.fill
        briefcase.circle.fill
        graduationcap.fill
        graduationcap.circle.fill
        building.fill
        building.2.fill
        building.2.crop.circle.fill
        building.columns.fill
        calendar.circle.fill
        globe.desk.fill
        backpack.fill
        backpack.circle.fill
        book.fill
        book.circle.fill
        book.closed.fill
        book.pages.fill
        books.vertical.fill
        bookmark.fill
        bookmark.circle.fill
        bookmark.square.fill
        archivebox.fill
        archivebox.circle.fill
        clipboard.fill
        cpu.fill
        apple.terminal.fill
        apple.terminal.circle.fill
        apple.terminal.on.rectangle.fill
        folder.fill
        folder.circle.fill
        arrow.forward.folder.fill
        arrow.up.folder.fill
        doc.fill
        doc.circle.fill
        doc.append.fill
        doc.badge.arrow.up.fill
        doc.badge.clock.fill
        doc.badge.gearshape.fill
        doc.on.doc.fill
        doc.on.clipboard.fill
        doc.plaintext.fill
        doc.richtext.fill
        doc.text.fill
        doc.text.image.fill
        document.fill
        document.circle.fill
        document.badge.plus.fill
        document.on.document.fill
        chart.bar.fill
        chart.line.uptrend.xyaxis.circle.fill
        chart.pie.fill
        """),
    symbolCategory("Health", """
        allergens.fill
        bandage.fill
        bed.double.badge.checkmark.fill
        bed.double.circle.fill
        bed.double.fill
        blood.pressure.cuff.fill
        blood.pressure.cuff.badge.gauge.with.needle.fill
        brain.fill
        brain.head.profile.fill
        cross.fill
        cross.circle.fill
        cross.case.fill
        cross.case.circle.fill
        cross.vial.fill
        ear.fill
        eye.fill
        eye.circle.fill
        eye.square.fill
        eye.slash.fill
        eye.trianglebadge.exclamationmark.fill
        facemask.fill
        hearingdevice.and.signal.meter.fill
        hearingdevice.ear.fill
        heart.fill
        heart.circle.fill
        heart.badge.bolt.fill
        heart.badge.bolt.slash.fill
        heart.text.clipboard.fill
        heart.text.square.fill
        ivfluid.bag.fill
        list.clipboard.fill
        list.bullet.clipboard.fill
        lungs.fill
        medical.thermometer.fill
        microbe.fill
        microbe.circle.fill
        pill.fill
        pill.circle.fill
        pills.fill
        pills.circle.fill
        sparkle.text.clipboard.fill
        staroflife.fill
        staroflife.circle.fill
        stethoscope.circle.fill
        syringe.fill
        thermometer.variable.and.figure.circle.fill
        waveform.path.ecg.rectangle.fill
        waveform.path.ecg.text.clipboard.fill
        apple.meditate.circle.fill
        apple.meditate.square.stack.fill
        """),
    symbolCategory("Technology", """
        airpods.chargingcase.fill
        airpods.chargingcase.wireless.fill
        airpods.gen3.chargingcase.wireless.fill
        airpods.gen4.chargingcase.wireless.fill
        airpods.pro.chargingcase.wireless.fill
        airpods.pro.chargingcase.wireless.radiowaves.left.and.right.fill
        antenna.radiowaves.left.and.right.circle.fill
        antenna.radiowaves.left.and.right.slash.circle.fill
        applepencil.adapter.usb.c.fill
        appletv.fill
        appletv.badge.checkmark.fill
        appletv.badge.exclamationmark.fill
        appletvremote.gen1.fill
        appletvremote.gen2.fill
        appletvremote.gen3.fill
        appletvremote.gen4.fill
        arcade.stick.console.fill
        av.remote.fill
        beats.fitpro.chargingcase.fill
        beats.pill.fill
        beats.powerbeats.pro.2.chargingcase.fill
        beats.powerbeats.pro.chargingcase.fill
        beats.solobuds.chargingcase.fill
        beats.studiobuds.chargingcase.fill
        beats.studiobuds.plus.chargingcase.fill
        bolt.horizontal.fill
        bolt.horizontal.circle.fill
        cellularbars.circle.fill
        circle.filled.ipad.fill
        circle.filled.ipad.landscape.fill
        circle.filled.iphone.fill
        computermouse.fill
        cpu.fill
        externaldrive.connected.to.line.below.fill
        headphones.circle.fill
        headset.circle.fill
        icloud.fill
        icloud.circle.fill
        icloud.square.fill
        icloud.slash.fill
        iphone.circle.fill
        iphone.gen1.circle.fill
        iphone.gen2.circle.fill
        iphone.gen3.circle.fill
        iphone.radiowaves.left.and.right.circle.fill
        iphone.slash.circle.fill
        keyboard.fill
        keyboard.badge.ellipsis.fill
        keyboard.badge.eye.fill
        macstudio.fill
        """),
    symbolCategory("Creativity", """
        airplay.audio.circle.fill
        airplay.video.circle.fill
        apple.books.pages.fill
        apple.image.playground.fill
        applepencil.adapter.usb.c.fill
        appletv.fill
        arrow.down.left.video.fill
        arrow.up.right.video.fill
        book.fill
        book.circle.fill
        book.closed.fill
        book.closed.circle.fill
        book.pages.fill
        books.vertical.fill
        bubbles.and.sparkles.fill
        camera.fill
        camera.circle.fill
        camera.badge.clock.fill
        camera.badge.ellipsis.fill
        camera.on.rectangle.fill
        camera.rotate.fill
        camera.shutter.button.fill
        character.book.closed.fill
        figure.play.circle.fill
        film.fill
        film.circle.fill
        film.stack.fill
        guitars.fill
        hands.and.sparkles.fill
        hands.sparkles.fill
        headphones.circle.fill
        hifispeaker.fill
        hifispeaker.2.fill
        megaphone.fill
        mic.fill
        mic.circle.fill
        mic.square.fill
        microphone.fill
        microphone.circle.fill
        microphone.square.fill
        music.house.fill
        music.mic.circle.fill
        music.microphone.circle.fill
        music.note.house.fill
        music.note.square.stack.fill
        paintbrush.fill
        paintbrush.pointed.fill
        paintpalette.fill
        pencil.and.ruler.fill
        pencil.circle.fill
        """),
    symbolCategory("Finance", """
        bag.fill
        bag.circle.fill
        banknote.fill
        basket.fill
        cart.fill
        cart.circle.fill
        cart.badge.clock.fill
        creditcard.fill
        creditcard.circle.fill
        creditcard.rewards.fill
        creditcard.trianglebadge.exclamationmark.fill
        wallet.bifold.fill
        wallet.pass.fill
        giftcard.fill
        building.fill
        building.2.fill
        building.columns.fill
        building.columns.circle.fill
        briefcase.fill
        briefcase.circle.fill
        chart.bar.fill
        chart.bar.doc.horizontal.fill
        chart.bar.horizontal.page.fill
        chart.line.downtrend.xyaxis.circle.fill
        chart.line.flattrend.xyaxis.circle.fill
        chart.line.uptrend.xyaxis.circle.fill
        chart.line.text.clipboard.fill
        chart.pie.fill
        doc.text.fill
        dollarsign.circle.fill
        dollarsign.square.fill
        dollarsign.bank.building.fill
        eurosign.circle.fill
        eurosign.square.fill
        eurosign.bank.building.fill
        sterlingsign.circle.fill
        sterlingsign.square.fill
        sterlingsign.bank.building.fill
        indianrupeesign.circle.fill
        indianrupeesign.square.fill
        indianrupeesign.bank.building.fill
        bitcoinsign.circle.fill
        bitcoinsign.square.fill
        bitcoinsign.bank.building.fill
        australiandollarsign.circle.fill
        australiandollarsign.square.fill
        australiandollarsign.bank.building.fill
        receipt.fill
        storefront.fill
        storefront.circle.fill
        """),
    symbolCategory("Pets & Family", """
        balloon.fill
        balloon.2.fill
        birthday.cake.fill
        app.gift.fill
        gift.fill
        gift.circle.fill
        giftcard.fill
        bed.double.fill
        bed.double.circle.fill
        bed.double.badge.checkmark.fill
        bird.fill
        bird.circle.fill
        cat.fill
        cat.circle.fill
        dog.fill
        dog.circle.fill
        fish.fill
        fish.circle.fill
        hare.fill
        hare.circle.fill
        pawprint.fill
        pawprint.circle.fill
        heart.fill
        heart.circle.fill
        heart.square.fill
        heart.rectangle.fill
        heart.badge.bolt.fill
        heart.badge.bolt.slash.fill
        heart.text.square.fill
        heart.text.clipboard.fill
        hands.clap.fill
        hands.and.sparkles.fill
        hands.sparkles.fill
        figure.child.circle.fill
        figure.child.and.lock.fill
        figure.child.and.lock.open.fill
        figure.2.circle.fill
        person.2.fill
        person.2.circle.fill
        person.2.badge.fill
        person.2.badge.gearshape.fill
        person.2.badge.key.fill
        person.2.badge.plus.fill
        person.2.badge.minus.fill
        person.2.shield.fill
        person.2.wave.2.fill
        person.3.fill
        person.3.sequence.fill
        person.crop.circle.fill
        person.crop.circle.badge.fill
        """),
])

private let allSymbols: [String] = uniqueSymbolsPreservingOrder(allCategories.flatMap(\.symbols))

private func uniqueCategories(_ categories: [SymbolCategory]) -> [SymbolCategory] {
    return categories.map { category in
        let validSymbols = category.symbols.compactMap(MomentSymbolPolicy.normalized)
        let uniqueSymbols = uniqueSymbolsPreservingOrder(validSymbols)
        return SymbolCategory(name: category.name, symbols: Array(uniqueSymbols.prefix(50)))
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

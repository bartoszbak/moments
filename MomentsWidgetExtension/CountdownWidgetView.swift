import SwiftUI
import WidgetKit

struct CountdownWidgetView: View {
    let entry: CountdownEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            accessoryCircularView
        case .accessoryRectangular:
            accessoryRectangularView
        case .accessoryInline:
            accessoryInlineView
        case .systemMedium:
            mediumView
        default:
            smallView
        }
    }

    // MARK: - Small

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top row: big number (+ subtitle when symbol shown) + label or symbol
            HStack(alignment: .top, spacing: 4) {
                if let countdown = entry.countdown {
                    if let symbol = countdown.sfSymbolName {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(countdown.isToday ? "0" : "\(countdown.isExpired ? countdown.daysSince : countdown.daysUntil)")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(fgPrimary)
                                .minimumScaleFactor(0.4)
                                .lineLimit(1)
                            Text(countdown.isExpired && !countdown.isToday ? "Days since" : "Days until")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(fgSecondary)
                        }

                        Spacer()

                        Image(systemName: symbol)
                            .font(.system(.title3, weight: .semibold))
                            .foregroundStyle(fgSecondary)
                            .padding(.top, 4)
                    } else {
                        Text(countdown.isToday ? "0" : "\(countdown.isExpired ? countdown.daysSince : countdown.daysUntil)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(fgPrimary)
                            .minimumScaleFactor(0.4)
                            .lineLimit(1)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, -4)

                        Spacer()

                        VStack(alignment: .trailing, spacing: 0) {
                            Text("Days")
                            Text(relationLabel(for: countdown))
                        }
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(fgSecondary)
                    }
                } else {
                    Text("—")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(fgPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, -7)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 0) {
                        Text("Days")
                        Text("until")
                    }
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(fgSecondary)
                }
            }

            Spacer()

            if let countdown = entry.countdown {
                Text(countdown.title)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(fgPrimary)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .padding(.bottom, 6)

                if !countdown.isExpired {
                    progressBar(progress: countdown.barProgress)
                }

                if countdown.showDate {
                    Text(countdown.targetDate.smartFormatted)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(fgSecondary)
                        .padding(.top, countdown.isExpired ? 0 : 6)
                }
            }
        }
        .padding(1)
        .containerBackground(for: .widget) { containerBackground }
    }

    // MARK: - Medium

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top row: big number + label or symbol
            HStack(alignment: .top, spacing: 4) {
                if let countdown = entry.countdown {
                    if let symbol = countdown.sfSymbolName {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(countdown.isToday ? "0" : "\(countdown.isExpired ? countdown.daysSince : countdown.daysUntil)")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(fgPrimary)
                                .minimumScaleFactor(0.4)
                                .lineLimit(1)
                            Text(countdown.isExpired && !countdown.isToday ? "Days since" : "Days until")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(fgSecondary)
                        }

                        Spacer()

                        Image(systemName: symbol)
                            .font(.system(.title3, weight: .semibold))
                            .foregroundStyle(fgSecondary)
                            .padding(.top, 4)
                    } else {
                        Text(countdown.isToday ? "0" : "\(countdown.isExpired ? countdown.daysSince : countdown.daysUntil)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(fgPrimary)
                            .minimumScaleFactor(0.4)
                            .lineLimit(1)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, -7)

                        Spacer()

                        VStack(alignment: .trailing, spacing: 0) {
                            Text("Days")
                            Text(relationLabel(for: countdown))
                        }
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(fgSecondary)
                    }
                } else {
                    Text("—")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(fgPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, -7)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 0) {
                        Text("Days")
                        Text("until")
                    }
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(fgSecondary)
                }
            }

            Spacer()

            if let countdown = entry.countdown {
                Text(countdown.title)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(fgPrimary)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .padding(.bottom, 8)

                if !countdown.isExpired {
                    progressBar(progress: countdown.barProgress)
                }

                if countdown.showDate {
                    Text(countdown.targetDate.smartFormatted)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(fgSecondary)
                        .padding(.top, countdown.isExpired ? 0 : 6)
                }
            }
        }
        .padding(1)
        .containerBackground(for: .widget) { containerBackground }
    }

    // MARK: - Accessory Circular

    private var accessoryCircularView: some View {
        VStack(spacing: 0) {
            if let countdown = entry.countdown {
                if countdown.isToday {
                    Text("0")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                } else {
                    Text("\(countdown.isExpired ? countdown.daysSince : countdown.daysUntil)")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .minimumScaleFactor(0.5)
                    Text("d")
                        .font(.caption2.bold())
                }
            } else {
                Text("—")
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }

    // MARK: - Accessory Rectangular

    private var accessoryRectangularView: some View {
        HStack {
            if let countdown = entry.countdown {
                VStack(alignment: .leading, spacing: 2) {
                    Text(countdown.title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Text(daysLabel(for: countdown))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("No countdown")
                    .font(.caption)
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }

    // MARK: - Accessory Inline

    private var accessoryInlineView: some View {
        Group {
            if let countdown = entry.countdown {
                Text("\(countdown.title) · \(daysLabel(for: countdown))")
            } else {
                Text("No countdown")
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }

    // MARK: - Helpers

    private var resolvedBackgroundColor: Color? {
        guard let hex = entry.countdown?.backgroundColorHex else { return nil }
        return Color(hex: hex)
    }

    /// True when background is dark → use white text; false → use dark text.
    private var usesLightText: Bool {
        guard let hex = entry.countdown?.backgroundColorHex else {
            return true // gradient background → white text
        }
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard cleaned.count == 6, let value = UInt64(cleaned, radix: 16) else {
            return true
        }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        return luminance < 0.5 // dark bg → light text
    }

    private var fgPrimary: Color { usesLightText ? .white : .black }
    private var fgSecondary: Color { usesLightText ? .white.opacity(0.5) : .black.opacity(0.4) }

    private var backgroundImage: UIImage? {
        guard let path = entry.countdown?.backgroundImagePath else { return nil }
        return UIImage(contentsOfFile: path)
    }

    private var containerBackground: some View {
        ZStack {
            if let image = backgroundImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                Color.black.opacity(0.3)
            } else if let color = resolvedBackgroundColor {
                color
            } else {
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.8), Color.accentColor.opacity(0.4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }


    private func progressBar(progress: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(fgSecondary.opacity(0.3))
                    .frame(height: 6)
                Capsule()
                    .fill(fgPrimary)
                    .frame(width: geo.size.width * progress, height: 6)
            }
        }
        .frame(height: 6)
    }

    private func daysLabel(for countdown: WidgetCountdown) -> String {
        if countdown.isToday { return "Today" }
        if countdown.isExpired { return "\(countdown.daysSince) days since" }
        return "\(countdown.daysUntil) days until"
    }

    private func relationLabel(for countdown: WidgetCountdown) -> String {
        countdown.isExpired && !countdown.isToday ? "since" : "until"
    }

}

#Preview(as: .systemSmall) {
    CountdownWidget()
} timeline: {
    CountdownEntry(date: .now, countdown: .placeholder)
}

#Preview(as: .systemMedium) {
    CountdownWidget()
} timeline: {
    CountdownEntry(date: .now, countdown: .placeholder)
}

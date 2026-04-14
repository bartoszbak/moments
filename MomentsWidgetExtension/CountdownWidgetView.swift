import SwiftUI
import WidgetKit
import UIKit

struct CountdownWidgetView: View {
    let entry: CountdownEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
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
        .widgetURL(widgetDestinationURL)
    }

    // MARK: - Small

    private var smallView: some View {
        if let countdown = entry.countdown, countdown.isFutureManifestation {
            return AnyView(manifestationWidgetView(countdown: countdown, titleBottomPadding: 4))
        }

        return AnyView(
            VStack(alignment: .leading, spacing: 0) {
            // Top row: big number (+ subtitle when symbol shown) + label or symbol
            HStack(alignment: .top, spacing: 4) {
                if let countdown = entry.countdown {
                    if let symbol = countdown.sfSymbolName {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(metricValue(for: countdown))
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(fgPrimary)
                                .minimumScaleFactor(0.4)
                                .lineLimit(1)
                            Text(metricTitle(for: countdown))
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(fgSecondary)
                        }

                        Spacer()

                        Image(systemName: symbol)
                            .font(.system(.title3, weight: .semibold))
                            .foregroundStyle(fgSecondary)
                            .padding(.top, 4)
                    } else {
                        Text(metricValue(for: countdown))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(fgPrimary)
                            .minimumScaleFactor(0.4)
                            .lineLimit(1)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, -4)

                        Spacer()

                        if !countdown.isFutureManifestation {
                            VStack(alignment: .trailing, spacing: 0) {
                                Text("Days")
                                Text(relationLabel(for: countdown))
                            }
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(fgSecondary)
                        }
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

                if !countdown.isExpired && !countdown.isFutureManifestation {
                    progressBar(progress: countdown.barProgress)
                }

                if countdown.showDate && !countdown.isFutureManifestation {
                    Text(countdown.targetDate.smartFormatted)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(fgSecondary)
                        .padding(.top, countdown.isExpired ? 0 : 6)
                }
            }
        }
        .padding(1)
        .containerBackground(for: .widget) { containerBackground }
        )
    }

    // MARK: - Medium

    private var mediumView: some View {
        if let countdown = entry.countdown, countdown.isFutureManifestation {
            return AnyView(manifestationWidgetView(countdown: countdown, titleBottomPadding: 6))
        }

        return AnyView(
            VStack(alignment: .leading, spacing: 0) {
            // Top row: big number + label or symbol
            HStack(alignment: .top, spacing: 4) {
                if let countdown = entry.countdown {
                    if let symbol = countdown.sfSymbolName {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(metricValue(for: countdown))
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(fgPrimary)
                                .minimumScaleFactor(0.4)
                                .lineLimit(1)
                            Text(metricTitle(for: countdown))
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(fgSecondary)
                        }

                        Spacer()

                        Image(systemName: symbol)
                            .font(.system(.title3, weight: .semibold))
                            .foregroundStyle(fgSecondary)
                            .padding(.top, 4)
                    } else {
                        Text(metricValue(for: countdown))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(fgPrimary)
                            .minimumScaleFactor(0.4)
                            .lineLimit(1)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, -7)

                        Spacer()

                        if !countdown.isFutureManifestation {
                            VStack(alignment: .trailing, spacing: 0) {
                                Text("Days")
                                Text(relationLabel(for: countdown))
                            }
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(fgSecondary)
                        }
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

                if !countdown.isExpired && !countdown.isFutureManifestation {
                    progressBar(progress: countdown.barProgress)
                }

                if countdown.showDate && !countdown.isFutureManifestation {
                    Text(countdown.targetDate.smartFormatted)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(fgSecondary)
                        .padding(.top, countdown.isExpired ? 0 : 6)
                }
            }
        }
        .padding(1)
        .containerBackground(for: .widget) { containerBackground }
        )
    }

    private func manifestationWidgetView(
        countdown: WidgetCountdown,
        titleBottomPadding: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 4) {
                Spacer()

                if let symbol = countdown.sfSymbolName {
                    Image(systemName: symbol)
                        .font(.system(.title3, weight: .semibold))
                        .foregroundStyle(fgSecondary)
                        .padding(.top, 4)
                }
            }

            Spacer()

            Text(countdown.title)
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(fgPrimary)
                .lineLimit(2)
                .truncationMode(.tail)
                .padding(.bottom, titleBottomPadding)

            Text("Manifest")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(fgSecondary)
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

    private var widgetDestinationURL: URL? {
        guard let countdown = entry.countdown else { return nil }
        return MomentDeepLink.previewURL(for: countdown.id)
    }

    private var usesLightText: Bool {
        if let image = backgroundImage {
            return image.prefersLightForeground(afterApplyingBlackOverlay: imageOverlayAverageOpacity)
        }

        if let color = resolvedBackgroundColor {
            return color.prefersLightForeground
        }

        return false
    }

    private var fgPrimary: Color { usesLightText ? .white : .black }
    private var fgSecondary: Color { usesLightText ? .white.opacity(0.72) : .black.opacity(0.58) }

    private var backgroundImage: UIImage? {
        guard let path = entry.countdown?.backgroundImagePath else { return nil }
        return UIImage(contentsOfFile: path)
    }

    private var imageOverlayAverageOpacity: Double { 0.28 }

    private var containerBackground: some View {
        ZStack {
            if let image = backgroundImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipped()

                LinearGradient(
                    colors: [
                        Color.black.opacity(0.1),
                        Color.black.opacity(0.24)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else if let color = resolvedBackgroundColor {
                color
            } else {
                Color.white
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
        if countdown.isFutureManifestation { return "Manifest" }
        if countdown.isToday { return "Today" }
        if countdown.isExpired { return "\(countdown.daysSince) days since" }
        return "\(countdown.daysUntil) days until"
    }

    private func relationLabel(for countdown: WidgetCountdown) -> String {
        if countdown.isFutureManifestation { return "manifest" }
        return countdown.isExpired && !countdown.isToday ? "since" : "until"
    }

    private func metricValue(for countdown: WidgetCountdown) -> String {
        if countdown.isFutureManifestation { return "∞" }
        return countdown.isToday ? "0" : "\(countdown.isExpired ? countdown.daysSince : countdown.daysUntil)"
    }

    private func metricTitle(for countdown: WidgetCountdown) -> String {
        if countdown.isFutureManifestation { return "Manifest" }
        return countdown.isExpired && !countdown.isToday ? "Days since" : "Days until"
    }

}

private extension UIImage {
    func prefersLightForeground(afterApplyingBlackOverlay overlayOpacity: Double) -> Bool {
        let effectiveLuminance = averageLuminance * (1 - overlayOpacity)
        return effectiveLuminance < 0.45
    }

    var averageLuminance: Double {
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        format.scale = 1

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1), format: format)
        let renderedImage = renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: CGSize(width: 1, height: 1)))
        }

        guard
            let cgImage = renderedImage.cgImage,
            let data = cgImage.dataProvider?.data,
            let bytes = CFDataGetBytePtr(data)
        else {
            return 1
        }

        let r = Double(bytes[0]) / 255
        let g = Double(bytes[1]) / 255
        let b = Double(bytes[2]) / 255

        return (0.299 * r) + (0.587 * g) + (0.114 * b)
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

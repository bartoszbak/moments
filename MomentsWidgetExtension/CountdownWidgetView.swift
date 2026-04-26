import SwiftUI
import WidgetKit
import UIKit

struct CountdownWidgetView: View {
    let entry: CountdownEntry

    @Environment(\.widgetFamily) private var family
    @Environment(\.showsWidgetContainerBackground) private var showsWidgetContainerBackground

    private var typography: WidgetTypography {
        WidgetTypography(option: entry.countdown?.widgetFontOption ?? .defaultOption)
    }

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
            return AnyView(manifestationWidgetView(countdown: countdown, titleBottomPadding: 6))
        }

        if let countdown = entry.countdown, countdown.isMinimalisticWidget {
            return AnyView(minimalisticWidgetView(countdown: countdown))
        }

        return AnyView(
            systemWidgetContent {
                VStack(alignment: .leading, spacing: 0) {
            // Top row: big number (+ subtitle when symbol shown) + label or symbol
            HStack(alignment: .top, spacing: 4) {
                if let countdown = entry.countdown {
                    if let symbol = countdown.sfSymbolName {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(metricValue(for: countdown))
                                .font(typography.font(size: 24, relativeTo: .title3, weight: .bold))
                                .foregroundStyle(fgPrimary)
                                .minimumScaleFactor(0.4)
                                .lineLimit(1)
                            Text(metricTitle(for: countdown))
                                .font(typography.font(.caption))
                                .foregroundStyle(fgSecondary)
                        }

                        Spacer()

                        Image(systemName: symbol)
                            .font(.system(.title3, weight: .semibold))
                            .foregroundStyle(fgSecondary)
                            .padding(.top, 4)
                    } else {
                        Text(metricValue(for: countdown))
                            .font(typography.font(size: 32, relativeTo: .largeTitle, weight: .bold))
                            .foregroundStyle(fgPrimary)
                            .minimumScaleFactor(0.4)
                            .lineLimit(1)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 2)

                        Spacer()

                        if !countdown.isFutureManifestation {
                            if countdown.isToday {
                                Text("Today")
                                    .font(typography.font(.caption))
                                    .foregroundStyle(fgSecondary)
                            } else {
                                VStack(alignment: .trailing, spacing: 0) {
                                    Text(dayUnit(for: countdown.isExpired ? countdown.daysSince : countdown.daysUntil))
                                    Text(relationLabel(for: countdown))
                                }
                                .font(typography.font(.caption))
                                .foregroundStyle(fgSecondary)
                            }
                        }
                    }
                } else {
                    Text("—")
                        .font(typography.font(size: 32, relativeTo: .largeTitle, weight: .bold))
                        .foregroundStyle(fgPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 0) {
                        Text("Days")
                        Text("until")
                    }
                    .font(typography.font(.caption))
                    .foregroundStyle(fgSecondary)
                }
            }

            Spacer()

            if let countdown = entry.countdown {
                widgetTitleText(
                    countdown.title,
                    lineLimit: 2,
                    bottomPadding: 6
                )

                if countdown.showProgress && !countdown.isExpired && !countdown.isFutureManifestation {
                    WidgetLinearProgressBar(
                        progress: countdown.barProgress,
                        foregroundColor: fgPrimary,
                        backgroundColor: fgSecondary.opacity(0.3)
                    )
                }

                if countdown.showDate && !countdown.isFutureManifestation {
                    Text(countdown.targetDate.smartFormatted)
                        .font(typography.font(.caption))
                        .foregroundStyle(fgSecondary)
                        .padding(.top, countdown.isExpired ? 0 : 6)
                }
            }
        }
            }
        )
    }

    // MARK: - Medium

    private var mediumView: some View {
        if let countdown = entry.countdown, countdown.isFutureManifestation {
            return AnyView(manifestationWidgetView(countdown: countdown, titleBottomPadding: 8))
        }

        if let countdown = entry.countdown, countdown.isMinimalisticWidget {
            return AnyView(minimalisticWidgetView(countdown: countdown))
        }

        return AnyView(
            systemWidgetContent {
                VStack(alignment: .leading, spacing: 0) {
            // Top row: big number + label or symbol
            HStack(alignment: .top, spacing: 4) {
                if let countdown = entry.countdown {
                    if let symbol = countdown.sfSymbolName {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(metricValue(for: countdown))
                                .font(typography.font(size: 24, relativeTo: .title3, weight: .bold))
                                .foregroundStyle(fgPrimary)
                                .minimumScaleFactor(0.4)
                                .lineLimit(1)
                            Text(metricTitle(for: countdown))
                                .font(typography.font(.caption))
                                .foregroundStyle(fgSecondary)
                        }

                        Spacer()

                        Image(systemName: symbol)
                            .font(.system(.title3, weight: .semibold))
                            .foregroundStyle(fgSecondary)
                            .padding(.top, 4)
                    } else {
                        Text(metricValue(for: countdown))
                            .font(typography.font(size: 32, relativeTo: .largeTitle, weight: .bold))
                            .foregroundStyle(fgPrimary)
                            .minimumScaleFactor(0.4)
                            .lineLimit(1)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 2)

                        Spacer()

                        if !countdown.isFutureManifestation {
                            if countdown.isToday {
                                Text("Today")
                                    .font(typography.font(.caption))
                                    .foregroundStyle(fgSecondary)
                            } else {
                                VStack(alignment: .trailing, spacing: 0) {
                                    Text(dayUnit(for: countdown.isExpired ? countdown.daysSince : countdown.daysUntil))
                                    Text(relationLabel(for: countdown))
                                }
                                .font(typography.font(.caption))
                                .foregroundStyle(fgSecondary)
                            }
                        }
                    }
                } else {
                    Text("—")
                        .font(typography.font(size: 32, relativeTo: .largeTitle, weight: .bold))
                        .foregroundStyle(fgPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 0) {
                        Text("Days")
                        Text("until")
                    }
                    .font(typography.font(.caption))
                    .foregroundStyle(fgSecondary)
                }
            }

            Spacer()

            if let countdown = entry.countdown {
                widgetTitleText(
                    countdown.title,
                    lineLimit: 2,
                    bottomPadding: 8
                )

                if countdown.showProgress && !countdown.isExpired && !countdown.isFutureManifestation {
                    WidgetLinearProgressBar(
                        progress: countdown.barProgress,
                        foregroundColor: fgPrimary,
                        backgroundColor: fgSecondary.opacity(0.3)
                    )
                }

                if countdown.showDate && !countdown.isFutureManifestation {
                    Text(countdown.targetDate.smartFormatted)
                        .font(typography.font(.caption))
                        .foregroundStyle(fgSecondary)
                        .padding(.top, countdown.isExpired ? 0 : 6)
                }
            }
        }
            }
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

            widgetTitleText(
                countdown.title,
                lineLimit: 3,
                bottomPadding: titleBottomPadding,
                isManifestation: true
            )

            Text("Manifest")
                .font(typography.font(.caption))
                .foregroundStyle(fgSecondary)
        }
        .modifier(SystemWidgetChrome(
            containerBackground: containerBackground,
            padding: systemWidgetPadding
        ))
    }

    private func minimalisticWidgetView(countdown: WidgetCountdown) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(minimalisticMetricText(for: countdown)) \(minimalisticRelationTitleText(for: countdown))")
                .font(typography.font(size: 17, relativeTo: .headline, weight: .bold))
                .foregroundStyle(fgPrimary)
                .lineLimit(3)
                .lineSpacing(typography.minimalTitleLineSpacing())
                .truncationMode(.tail)

            Spacer()

            minimalWidgetFooter(for: countdown)
        }
        .modifier(SystemWidgetChrome(
            containerBackground: containerBackground,
            padding: systemWidgetPadding
        ))
    }

    // MARK: - Accessory Circular

    private var accessoryCircularView: some View {
        VStack(spacing: 0) {
            if let countdown = entry.countdown {
                if countdown.isToday {
                    Text("0")
                        .font(typography.font(.title2, weight: .bold))
                } else {
                    Text("\(countdown.isExpired ? countdown.daysSince : countdown.daysUntil)")
                        .font(typography.font(.title2, weight: .bold))
                        .minimumScaleFactor(0.5)
                    Text("d")
                        .font(typography.font(.caption2, weight: .bold))
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
                        .font(typography.font(.caption, weight: .semibold))
                        .lineLimit(1)
                    Text(daysLabel(for: countdown))
                        .font(typography.font(.caption2))
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("No countdown")
                    .font(typography.font(.caption))
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }

    // MARK: - Accessory Inline

    private var accessoryInlineView: some View {
        Group {
            if let countdown = entry.countdown {
                Text(inlineLabel(for: countdown))
                    .font(typography.font(.caption))
            } else {
                Text("No countdown")
                    .font(typography.font(.caption))
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
        if !showsWidgetContainerBackground {
            return true
        }

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

    private var systemWidgetPadding: EdgeInsets {
        switch family {
        case .systemSmall:
            return EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)
        case .systemMedium:
            return EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)
        default:
            return EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)
        }
    }

    private func systemWidgetContent<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .modifier(SystemWidgetChrome(
                containerBackground: containerBackground,
                padding: systemWidgetPadding
            ))
    }

    @ViewBuilder
    private func minimalWidgetFooter(for countdown: WidgetCountdown) -> some View {
        let showsProgress = countdown.showProgress && !countdown.isExpired

        if showsProgress && countdown.minimalWidgetProgressStyle == .circular {
            HStack(alignment: .bottom, spacing: 8) {
                if countdown.showDate {
                    minimalWidgetDateText(for: countdown)
                }

                Spacer(minLength: 0)

                minimalWidgetProgressView(for: countdown)
            }
            .frame(maxWidth: .infinity, alignment: .bottomLeading)
        } else {
            if countdown.showDate {
                minimalWidgetDateText(for: countdown)
                    .padding(.bottom, minimalWidgetDateBottomPadding(for: countdown, showsProgress: showsProgress))
            }

            if showsProgress {
                minimalWidgetProgressView(for: countdown)
            }
        }
    }

    private func minimalWidgetDateText(for countdown: WidgetCountdown) -> some View {
        Text(countdown.targetDate.smartFormatted)
            .font(typography.font(size: 15, relativeTo: .subheadline, weight: .semibold))
            .foregroundStyle(fgSecondary)
    }

    private func minimalWidgetDateBottomPadding(for countdown: WidgetCountdown, showsProgress: Bool) -> CGFloat {
        guard showsProgress else { return 0 }

        switch countdown.minimalWidgetProgressStyle {
        case .linear:
            return 8
        case .verticalBars:
            return 10
        case .circular:
            return 0
        }
    }

    @ViewBuilder
    private func minimalWidgetProgressView(for countdown: WidgetCountdown) -> some View {
        switch countdown.minimalWidgetProgressStyle {
        case .linear:
            WidgetLinearProgressBar(
                progress: countdown.barProgress,
                foregroundColor: fgPrimary,
                backgroundColor: fgSecondary.opacity(0.3)
            )
        case .circular:
            WidgetCircularProgressBar(
                progress: countdown.barProgress,
                foregroundColor: fgPrimary,
                backgroundColor: fgSecondary.opacity(0.3),
                size: 36
            )
        case .verticalBars:
            WidgetVerticalBarsProgressBar(
                progress: countdown.barProgress,
                foregroundColor: fgPrimary,
                backgroundColor: fgSecondary.opacity(0.3),
                barCount: 11,
                height: 27.75,
                barWidth: 6.75,
                fillsAvailableWidth: family == .systemMedium,
                extraBarsWhenFillingWidth: family == .systemMedium ? 1 : 0
            )
        }
    }

    private func widgetTitleText(
        _ title: String,
        lineLimit: Int,
        bottomPadding: CGFloat,
        isManifestation: Bool = false
    ) -> some View {
        Text(title)
            .font(typography.font(.headline, weight: .semibold))
            .foregroundStyle(fgPrimary)
            .lineLimit(lineLimit)
            .lineSpacing(typography.titleLineSpacing(isManifestation: isManifestation))
            .truncationMode(.tail)
            .padding(.bottom, bottomPadding)
    }

    private func daysLabel(for countdown: WidgetCountdown) -> String {
        if countdown.isFutureManifestation { return "Manifest" }
        if countdown.isToday { return "Today" }
        if countdown.isExpired { return "\(countdown.daysSince) \(dayUnit(for: countdown.daysSince)) since" }
        return "\(countdown.daysUntil) \(dayUnit(for: countdown.daysUntil)) until"
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
        if countdown.isToday { return "Today" }
        let dayCount = countdown.isExpired ? countdown.daysSince : countdown.daysUntil
        return "\(dayUnit(for: dayCount)) \(countdown.isExpired ? "since" : "until")"
    }

    private func minimalisticMetricText(for countdown: WidgetCountdown) -> String {
        if countdown.isToday {
            return "Today"
        }

        let count = countdown.isExpired ? countdown.daysSince : countdown.daysUntil
        return "\(count) \(dayUnit(for: count))"
    }

    private func minimalisticRelationTitleText(for countdown: WidgetCountdown) -> String {
        if countdown.isToday {
            return countdown.title
        }

        let relation = countdown.isExpired ? "since" : "to"
        return "\(relation) \(countdown.title)"
    }

    private func inlineLabel(for countdown: WidgetCountdown) -> String {
        if countdown.isFutureManifestation {
            return "Manifest \(countdown.title)"
        }

        return "\(daysLabel(for: countdown)) \(countdown.title)"
    }

    private func dayUnit(for count: Int) -> String {
        count == 1 ? "Day" : "Days"
    }

}

private struct SystemWidgetChrome<Background: View>: ViewModifier {
    let containerBackground: Background
    let padding: EdgeInsets

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .containerBackground(for: .widget) { containerBackground }
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
    CountdownEntry(date: .now, countdown: .placeholder, relevance: nil)
}

#Preview(as: .systemMedium) {
    CountdownWidget()
} timeline: {
    CountdownEntry(date: .now, countdown: .placeholder, relevance: nil)
}

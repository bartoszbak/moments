import SwiftUI

struct CountdownTileView: View {
    let countdown: Countdown
    let currentTime: Date

    @Environment(\.colorScheme) private var colorScheme

    private let cornerRadius: CGFloat = 28

    private var isExpired: Bool { countdown.isExpired(at: currentTime) }
    private var isToday: Bool { countdown.isToday(at: currentTime) }
    private var daysUntil: Int { countdown.daysUntil(from: currentTime) }
    private var daysSince: Int { countdown.daysSince(from: currentTime) }

    var body: some View {
        Group {
            if #available(iOS 26, *) {
                tileContent
                    .glassEffect(.regular.tint(tileSurfaceColor.opacity(colorScheme == .dark ? 0.64 : 0.82)), in: .rect(cornerRadius: cornerRadius))
            } else {
                tileContent
                    .background(tileSurfaceColor, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.24 : 0.12), radius: 22, x: 0, y: 12)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(tileBorderColor, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var tileContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(metricValueText)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(primaryTextColor)
                        .contentTransition(.numericText(countsDown: !isExpired))
                        .animation(.snappy, value: metricValueText)

                    Text(metricCaptionText)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(secondaryTextColor)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if let symbolName = countdown.sfSymbolName {
                    Image(systemName: symbolName)
                        .font(.system(.title3, weight: .semibold))
                        .foregroundStyle(secondaryTextColor)
                        .padding(.top, 4)
                }
            }

            Spacer(minLength: 0)

            Text(countdown.title)
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(primaryTextColor)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .aspectRatio(1, contentMode: .fit)
        .padding(18)
        .background(tileSurfaceColor)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var tileSurfaceColor: Color {
        colorScheme == .dark ? .black : .white
    }

    private var tileBorderColor: Color {
        colorScheme == .dark ? .white.opacity(0.10) : .black.opacity(0.14)
    }

    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.50) : .black.opacity(0.38)
    }

    private var metricValueText: String {
        if isToday {
            return "0"
        }

        return isExpired ? "\(daysSince)" : "\(daysUntil)"
    }

    private var metricCaptionText: String {
        isExpired ? "Days since" : "Days until"
    }

    private var spokenMetricText: String {
        if isToday {
            return "0 days until"
        }

        if isExpired {
            return "\(daysSince) days since"
        }

        return "\(daysUntil) days until"
    }

    private var accessibilityLabel: String {
        "\(countdown.title), \(spokenMetricText), \(countdown.targetDate.smartFormatted)"
    }
}

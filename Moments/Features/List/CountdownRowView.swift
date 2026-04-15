import SwiftUI

struct CountdownTileView: View {
    let countdown: Countdown
    let currentTime: Date

    @Environment(\.colorScheme) private var colorScheme

    private let cornerRadius: CGFloat = 28

    private var titleLineLimit: Int {
        UIDevice.current.userInterfaceIdiom == .pad ? 4 : 2
    }

    private var isExpired: Bool { countdown.isExpired(at: currentTime) }
    private var isToday: Bool { countdown.isToday(at: currentTime) }
    private var daysUntil: Int { countdown.daysUntil(from: currentTime) }
    private var daysSince: Int { countdown.daysSince(from: currentTime) }

    var body: some View {
        Group {
            if #available(iOS 26, *) {
                tileContent
                    .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
            } else {
                tileContent
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.24 : 0.12), radius: 22, x: 0, y: 12)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(tileBorderColor, lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var tileContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if countdown.isFutureManifestation {
                HStack(alignment: .top, spacing: 8) {
                    Spacer(minLength: 0)

                    if let symbolName = countdown.sfSymbolName {
                        Image(systemName: symbolName)
                            .font(.system(.title3, weight: .semibold))
                            .foregroundStyle(secondaryTextColor)
                            .padding(.top, 4)
                    }
                }
            } else {
                HStack(alignment: .top, spacing: 8) {
                    Spacer(minLength: 0)
                    if let symbolName = countdown.sfSymbolName {
                        Image(systemName: symbolName)
                            .font(.system(.title3, weight: .semibold))
                            .foregroundStyle(secondaryTextColor)
                            .padding(.top, 4)
                    }
                }
            }

            Spacer(minLength: 0)

            if countdown.isFutureManifestation {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Manifestation")
                        .font(titleFont)
                        .fontDesign(nil)
                        .foregroundStyle(secondaryTextColor)
                        .lineLimit(1)

                    Text(countdown.title)
                        .font(titleFont)
                        .fontDesign(nil)
                        .foregroundStyle(primaryTextColor)
                        .lineLimit(titleLineLimit)
                        .lineSpacing(titleLineSpacing)
                        .multilineTextAlignment(.leading)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(metricTitleText)
                        .font(titleFont)
                        .fontDesign(.rounded)
                        .foregroundStyle(secondaryTextColor)
                        .lineLimit(1)
                        .contentTransition(.numericText(countsDown: !isExpired))
                        .animation(.snappy, value: metricTitleText)

                    Text(countdown.title)
                        .font(titleFont)
                        .fontDesign(.rounded)
                        .foregroundStyle(primaryTextColor)
                        .lineLimit(titleLineLimit)
                        .multilineTextAlignment(.leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .aspectRatio(1, contentMode: .fit)
        .padding(18)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var tileBorderColor: Color {
        colorScheme == .dark ? .white.opacity(0.10) : .black.opacity(0.12)
    }

    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.62) : .black.opacity(0.46)
    }

    private var titleLineSpacing: CGFloat {
        countdown.isFutureManifestation ? 4 : 0
    }

    private var titleFont: Font {
        if countdown.isFutureManifestation {
            return AppTypography.manifestationFont(
                relativeTo: .headline,
                variant: .medium
            )
        }

        return .system(.headline, design: .rounded, weight: .semibold)
    }

    private var metricValueText: String {
        if countdown.isFutureManifestation {
            return "∞"
        }
        if isToday {
            return "0"
        }

        return isExpired ? "\(daysSince)" : "\(daysUntil)"
    }

    private var metricCaptionText: String {
        if countdown.isFutureManifestation {
            return "Manifest"
        }
        if isToday {
            return "Today"
        }

        return "\(dayUnit(for: isExpired ? daysSince : daysUntil)) \(isExpired ? "since" : "until")"
    }

    private var metricTitleText: String {
        if countdown.isFutureManifestation {
            return "\(metricValueText) \(metricCaptionText)"
        }

        if isToday {
            return "Today"
        }

        return "\(metricValueText) \(metricCaptionText)"
    }

    private var spokenMetricText: String {
        if countdown.isFutureManifestation {
            return "future manifestation"
        }
        if isToday {
            return "Today"
        }

        if isExpired {
            return "\(daysSince) \(dayUnit(for: daysSince).lowercased()) since"
        }

        return "\(daysUntil) \(dayUnit(for: daysUntil).lowercased()) until"
    }

    private func dayUnit(for count: Int) -> String {
        count == 1 ? "Day" : "Days"
    }

    private var accessibilityLabel: String {
        if countdown.isFutureManifestation {
            return "\(countdown.title), \(spokenMetricText)"
        }
        return "\(countdown.title), \(spokenMetricText), \(countdown.targetDate.smartFormatted)"
    }
}

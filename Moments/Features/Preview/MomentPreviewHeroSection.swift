import SwiftUI
import UIKit

struct MomentPreviewHeroSection: View {
    let countdown: Countdown
    let currentTime: Date
    let previewSymbolColor: Color

    var body: some View {
        if countdown.isFutureManifestation {
            manifestationHeroCard
        } else {
            standardHeroCard
        }
    }

    private var standardHeroCard: some View {
        VStack(alignment: .center, spacing: 14) {
            VStack(alignment: .center, spacing: standardHeroMetricSpacing) {
                Text(metricValue)
                    .font(.system(size: 62, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text(metricLabel)
                    .font(.headline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, standardHeroMetricBottomPadding)

            titleText(font: .system(size: 34, weight: .bold, design: .rounded))

            symbolView
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.bottom, 28)
    }

    private var manifestationHeroCard: some View {
        VStack(alignment: .center, spacing: 18) {
            titleText(
                font: AppTypography.manifestationFont(
                    size: 34,
                    relativeTo: .title,
                    variant: .bold
                ),
                fontDesign: nil,
                horizontalPadding: 42
            )

            symbolView
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.bottom, 28)
    }

    private func titleText(
        font: Font,
        fontDesign: Font.Design? = .rounded,
        horizontalPadding: CGFloat? = nil
    ) -> some View {
        Text(countdown.title)
            .font(font)
            .fontDesign(fontDesign)
            .foregroundStyle(.primary)
            .multilineTextAlignment(.center)
            .lineSpacing(countdown.isFutureManifestation ? 8 : 0)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, horizontalPadding)
    }

    @ViewBuilder
    private var symbolView: some View {
        if let symbolName = countdown.sfSymbolName {
            Image(systemName: symbolName)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(previewSymbolColor)
                .padding(.top, standardHeroSymbolTopPadding)
                .padding(.bottom, standardHeroSymbolBottomPadding)
        }
    }

    private var metricValue: String {
        if countdown.isToday(at: currentTime) {
            return "0"
        }

        if countdown.isExpired(at: currentTime) {
            return "\(countdown.daysSince(from: currentTime))"
        }

        return "\(countdown.daysUntil(from: currentTime))"
    }

    private var metricLabel: String {
        if countdown.isToday(at: currentTime) {
            return "Today"
        }

        if countdown.isExpired(at: currentTime) {
            return "\(dayUnit(for: countdown.daysSince(from: currentTime))) since"
        }

        return "\(dayUnit(for: countdown.daysUntil(from: currentTime))) until"
    }

    private func dayUnit(for count: Int) -> String {
        count == 1 ? "Day" : "Days"
    }

    private var standardHeroSymbolTopPadding: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 16 : 0
    }

    private var standardHeroSymbolBottomPadding: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 32 : 16
    }

    private var standardHeroMetricSpacing: CGFloat {
        2
    }

    private var standardHeroMetricBottomPadding: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 8 : 0
    }
}

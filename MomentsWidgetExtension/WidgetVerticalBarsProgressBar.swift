import SwiftUI

struct WidgetVerticalBarsProgressBar: View {
    let progress: Double
    let foregroundColor: Color
    let backgroundColor: Color
    var barCount: Int = 12
    var height: CGFloat = 56
    var barWidth: CGFloat = 8
    var spacing: CGFloat = 6
    var fillsAvailableWidth: Bool = false
    var extraBarsWhenFillingWidth: Int = 0

    var body: some View {
        GeometryReader { proxy in
            let visibleBarCount = effectiveBarCount(for: proxy.size.width)
            let effectiveSpacing = effectiveSpacing(for: proxy.size.width, barCount: visibleBarCount)

            HStack(spacing: effectiveSpacing) {
                ForEach(0..<visibleBarCount, id: \.self) { index in
                    Capsule()
                        .fill(index < filledBarCount(for: visibleBarCount) ? foregroundColor : backgroundColor)
                        .frame(width: barWidth)
                        .frame(height: height)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: height)
    }

    private func effectiveBarCount(for availableWidth: CGFloat) -> Int {
        guard fillsAvailableWidth, availableWidth > 0 else { return barCount }
        let fittedBarCount = Int((availableWidth + spacing) / (barWidth + spacing))
        return max(1, fittedBarCount + extraBarsWhenFillingWidth)
    }

    private func effectiveSpacing(for availableWidth: CGFloat, barCount: Int) -> CGFloat {
        guard availableWidth > 0, barCount > 1 else { return spacing }
        let availableSpacing = availableWidth - (CGFloat(barCount) * barWidth)
        return max(0, availableSpacing / CGFloat(barCount - 1))
    }

    private func filledBarCount(for totalBarCount: Int) -> Int {
        let scaled = Int((clampedProgress * Double(totalBarCount)).rounded())
        if clampedProgress > 0 {
            return max(1, scaled)
        }
        return 0
    }

    private var clampedProgress: Double {
        min(1, max(0, progress))
    }
}

import SwiftUI

struct WidgetLinearProgressBar: View {
    let progress: Double
    let foregroundColor: Color
    let backgroundColor: Color
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(backgroundColor)
                    .frame(height: height)

                Capsule()
                    .fill(foregroundColor)
                    .frame(width: geo.size.width * clampedProgress, height: height)
            }
        }
        .frame(height: height)
    }

    private var clampedProgress: Double {
        min(1, max(0, progress))
    }
}

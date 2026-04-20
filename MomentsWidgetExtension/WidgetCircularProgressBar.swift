import SwiftUI

struct WidgetCircularProgressBar: View {
    let progress: Double
    let foregroundColor: Color
    let backgroundColor: Color
    var size: CGFloat = 48

    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)

            WidgetPieSliceShape(progress: clampedProgress)
                .fill(foregroundColor)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var clampedProgress: Double {
        min(1, max(0, progress))
    }
}

private struct WidgetPieSliceShape: Shape {
    let progress: Double

    func path(in rect: CGRect) -> Path {
        guard progress > 0 else { return Path() }

        let radius = min(rect.width, rect.height) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let startAngle = Angle.degrees(-90)
        let endAngle = Angle.degrees((progress * 360) - 90)

        var path = Path()
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

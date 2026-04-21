import SwiftUI

struct MomentPreviewPrimaryActionButton: View {
    @Environment(\.colorScheme) private var colorScheme

    let isLoading: Bool
    let isEnabled: Bool
    let prefersResponsiveGlassStyle: Bool
    let label: String
    let foregroundColor: Color
    let backgroundColor: Color
    let disabledBackgroundColor: Color?
    let loadingForegroundColor: Color
    let loadingBackgroundColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ThinkingActionLabel(
                        foregroundColor: loadingForegroundColor,
                        backgroundColor: loadingBackgroundColor
                    )
                } else {
                    Text(label)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(resolvedForegroundColor)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(buttonBackground)
                }
            }
        }
        .buttonStyle(.plain)
        .allowsHitTesting(!isLoading && isEnabled)
    }

    private var resolvedForegroundColor: Color {
        if prefersResponsiveGlassStyle {
            return colorScheme == .dark ? .black : .white
        }

        return isEnabled ? foregroundColor : .secondary
    }

    private var resolvedBackgroundColor: Color {
        if isEnabled {
            return backgroundColor
        }

        return disabledBackgroundColor ?? Color(uiColor: .tertiarySystemFill)
    }

    @ViewBuilder
    private var buttonBackground: some View {
        if prefersResponsiveGlassStyle {
            ResponsiveMonochromeGlassCapsule()
        } else {
            Capsule()
                .fill(resolvedBackgroundColor)
        }
    }
}

private struct ThinkingActionLabel: View {
    let foregroundColor: Color
    let backgroundColor: Color

    var body: some View {
        LoopingLetterRevealText(
            text: "Thinking",
            font: .headline.weight(.semibold),
            color: foregroundColor
        )
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(
            Capsule()
                .fill(backgroundColor)
        )
    }
}

private struct ResponsiveMonochromeGlassCapsule: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if #available(iOS 26, *) {
                Color.clear
                    .glassEffect(.regular.tint(surfaceColor), in: .capsule)
            } else {
                Capsule()
                    .fill(surfaceColor.opacity(fillOpacity))
                    .background(.ultraThinMaterial, in: Capsule())
                    .shadow(color: .black.opacity(shadowOpacity), radius: 18, x: 0, y: 10)
            }
        }
        .overlay(
            Capsule()
                .strokeBorder(strokeColor, lineWidth: 1)
        )
    }

    private var surfaceColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var strokeColor: Color {
        colorScheme == .dark
            ? .white.opacity(0.32)
            : .white.opacity(0.14)
    }

    private var fillOpacity: CGFloat {
        colorScheme == .dark ? 0.24 : 0.18
    }

    private var shadowOpacity: CGFloat {
        colorScheme == .dark ? 0.12 : 0.18
    }
}

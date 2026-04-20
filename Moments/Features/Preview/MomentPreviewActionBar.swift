import SwiftUI

struct MomentPreviewPrimaryActionButton: View {
    let isLoading: Bool
    let isEnabled: Bool
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
                        .background(
                            Capsule()
                                .fill(resolvedBackgroundColor)
                        )
                }
            }
        }
        .buttonStyle(.plain)
        .allowsHitTesting(!isLoading && isEnabled)
        .opacity(isEnabled || isLoading ? 1 : 0.72)
    }

    private var resolvedForegroundColor: Color {
        isEnabled ? foregroundColor : .secondary
    }

    private var resolvedBackgroundColor: Color {
        if isEnabled {
            return backgroundColor
        }

        return disabledBackgroundColor ?? Color(uiColor: .tertiarySystemFill)
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

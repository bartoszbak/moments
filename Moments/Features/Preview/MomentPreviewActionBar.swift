import BlurSwiftUI
import SwiftUI

struct MomentPreviewPrimaryActionButton: View {
    let isLoading: Bool
    let isEnabled: Bool
    let label: String
    let foregroundColor: Color
    let backgroundColor: Color
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
        isEnabled ? backgroundColor : Color(uiColor: .tertiarySystemFill)
    }
}

struct MomentPreviewBottomActionBar<Content: View>: View {
    let showsPrimaryAction: Bool
    let maxContentWidth: CGFloat
    let bottomSafeAreaInset: CGFloat
    let bottomBlurGradientHeight: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        if #available(iOS 26, *) {
            ZStack(alignment: .bottom) {
                VariableBlur(direction: .up)
                    .maximumBlurRadius(2)
                    .blurStartingInset(nil)
                    .dimmingTintColor(nil)
                    .dimmingAlpha(nil)
                    .dimmingOvershoot(nil)
                    .dimmingStartingInset(nil)
                    .passesTouchesThrough(true)
                    .frame(maxWidth: .infinity)
                    .frame(height: bottomBlurGradientHeight + (bottomSafeAreaInset * 2))
                    .offset(y: bottomSafeAreaInset)

                LinearGradient(
                    stops: [
                        .init(color: Color(uiColor: .systemBackground).opacity(0), location: 0),
                        .init(color: Color(uiColor: .systemBackground).opacity(1), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(maxWidth: .infinity)
                .frame(height: bottomBlurGradientHeight + (bottomSafeAreaInset * 2))
                .offset(y: bottomSafeAreaInset)
                .allowsHitTesting(false)

                if showsPrimaryAction {
                    content()
                        .frame(maxWidth: maxContentWidth)
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                        .padding(.bottom, 12)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .bottom)
            .ignoresSafeArea(edges: .bottom)
        } else if showsPrimaryAction {
            content()
                .frame(maxWidth: maxContentWidth)
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 12)
                .background(Color(.systemBackground))
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

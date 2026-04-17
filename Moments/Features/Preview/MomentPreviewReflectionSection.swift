import SwiftUI

struct MomentPreviewReflectionSection: View {
    let countdown: Countdown
    @ObservedObject var viewModel: MomentPreviewViewModel
    let onSurfaceRevealCompleted: () -> Void
    let onRevealCompleted: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if viewModel.errorText != nil {
                Label(reflectionCardTitle, systemImage: reflectionCardIcon)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            VStack(alignment: .leading, spacing: reflectionContentSpacing) {
                if !viewModel.surfaceDisplayText.isEmpty {
                    WordRevealText(
                        text: viewModel.surfaceDisplayText,
                        font: viewModel.errorText == nil
                            ? primaryReflectionFont
                            : .system(.body, design: .rounded),
                        color: viewModel.errorText == nil ? .primary : .secondary,
                        fontDesignOverride: countdown.isFutureManifestation ? nil : .rounded,
                        verticalSpacing: reflectionLineSpacing,
                        paragraphSpacing: reflectionParagraphSpacing,
                        onRevealCompleted: onSurfaceRevealCompleted
                    )
                }

                if !viewModel.reflectionDisplayText.isEmpty {
                    WordRevealText(
                        text: viewModel.reflectionDisplayText,
                        font: primaryReflectionFont,
                        color: .primary,
                        alignment: .leading,
                        fontDesignOverride: countdown.isFutureManifestation ? nil : .rounded,
                        verticalSpacing: reflectionLineSpacing,
                        paragraphSpacing: reflectionParagraphSpacing,
                        onRevealCompleted: { onRevealCompleted(1) }
                    )
                    .transition(.opacity)
                }

                if !viewModel.guidanceDisplayText.isEmpty {
                    if countdown.isFutureManifestation {
                        NativeRevealText(
                            text: viewModel.guidanceDisplayText,
                            font: secondaryReflectionFont,
                            color: .primary,
                            alignment: .center,
                            fontDesignOverride: nil,
                            onRevealCompleted: { onRevealCompleted(viewModel.guidanceStage) }
                        )
                        .transition(.opacity)
                    } else {
                        WordRevealText(
                            text: viewModel.guidanceDisplayText,
                            font: secondaryReflectionFont,
                            color: .primary,
                            alignment: .leading,
                            fontDesignOverride: .rounded,
                            verticalSpacing: reflectionLineSpacing,
                            paragraphSpacing: reflectionParagraphSpacing,
                            onRevealCompleted: { onRevealCompleted(viewModel.guidanceStage) }
                        )
                        .transition(.opacity)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.smooth(duration: 0.28), value: viewModel.surfaceDisplayText)
        .animation(.smooth(duration: 0.28), value: viewModel.reflectionDisplayText)
        .animation(.smooth(duration: 0.28), value: viewModel.guidanceDisplayText)
    }

    private var primaryReflectionFont: Font {
        if countdown.isFutureManifestation {
            return AppTypography.manifestationFont(
                relativeTo: .body,
                variant: .medium,
                sizeAdjustment: 3
            )
        }

        return .system(size: 20, weight: .medium, design: .rounded)
    }

    private var secondaryReflectionFont: Font {
        if countdown.isFutureManifestation {
            return AppTypography.manifestationFont(
                relativeTo: .body,
                variant: .mediumItalic,
                sizeAdjustment: 3
            )
        }

        return primaryReflectionFont
    }

    private var reflectionCardTitle: String {
        viewModel.errorText == nil ? "Reflection" : "AI generation issue"
    }

    private var reflectionCardIcon: String {
        viewModel.errorText == nil ? "text.quote" : "exclamationmark.triangle"
    }

    private var reflectionContentSpacing: CGFloat {
        countdown.isFutureManifestation ? 32 : 14
    }

    private var reflectionLineSpacing: CGFloat {
        countdown.isFutureManifestation ? 9 : 4
    }

    private var reflectionParagraphSpacing: CGFloat {
        countdown.isFutureManifestation ? 22 : 18
    }
}

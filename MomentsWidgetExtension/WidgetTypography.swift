import SwiftUI

struct WidgetTypography {
    let option: WidgetFontOption

    func titleLineSpacing(isManifestation _: Bool) -> CGFloat {
        guard option == .serif else { return 0 }
        return 3
    }

    func minimalTitleLineSpacing() -> CGFloat {
        guard option == .serif else { return 0 }
        return 3
    }

    func font(
        _ textStyle: Font.TextStyle,
        weight: Font.Weight = .regular
    ) -> Font {
        switch option {
        case .default:
            return .system(textStyle, design: .default, weight: weight)
        case .rounded:
            return .system(textStyle, design: .rounded, weight: weight)
        case .serif:
            return ManifestationTypography.widgetFont(
                relativeTo: textStyle,
                variant: manifestationVariant(for: weight)
            )
        }
    }

    func font(
        size: CGFloat,
        relativeTo textStyle: Font.TextStyle,
        weight: Font.Weight = .regular
    ) -> Font {
        switch option {
        case .default:
            return .system(size: size, weight: weight, design: .default)
        case .rounded:
            return .system(size: size, weight: weight, design: .rounded)
        case .serif:
            return ManifestationTypography.widgetFont(
                size: size,
                relativeTo: textStyle,
                variant: manifestationVariant(for: weight)
            )
        }
    }

    private func manifestationVariant(for weight: Font.Weight) -> ManifestationTypography.Variant {
        switch weight {
        case .black, .heavy, .bold:
            return .bold
        case .semibold, .medium:
            return .medium
        case .light, .thin, .ultraLight:
            return .book
        default:
            return .regular
        }
    }
}

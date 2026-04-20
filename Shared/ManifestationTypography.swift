import CoreText
import SwiftUI
import UIKit

enum ManifestationTypography {
    private static var postScriptNames: [Variant: String] = [:]
    private static var graphicsFonts: [Variant: CGFont] = [:]
    private static var hasRegisteredFonts = false

    static func configure() {
        ensureBundledFontsRegistered()
    }

    static func font(
        relativeTo textStyle: Font.TextStyle,
        variant: Variant = .regular,
        sizeAdjustment: CGFloat = 0
    ) -> Font {
        ensureBundledFontsRegistered()

        if let resolvedFont = manifestationCTFont(
            relativeTo: textStyle,
            variant: variant,
            sizeAdjustment: sizeAdjustment
        ) {
            return Font(resolvedFont)
        }

        let fallbackUIFont = manifestationFallbackUIFont(
            relativeTo: textStyle,
            variant: variant,
            sizeAdjustment: sizeAdjustment
        )
        return Font(fallbackUIFont)
    }

    static func font(
        size: CGFloat,
        relativeTo textStyle: Font.TextStyle,
        variant: Variant = .regular
    ) -> Font {
        ensureBundledFontsRegistered()

        if let resolvedFont = manifestationCTFont(
            size: size,
            relativeTo: textStyle,
            variant: variant
        ) {
            return Font(resolvedFont)
        }

        let fallbackUIFont = manifestationFallbackUIFont(
            size: size,
            relativeTo: textStyle,
            variant: variant
        )
        return Font(fallbackUIFont)
    }

    static func widgetFont(
        relativeTo textStyle: Font.TextStyle,
        variant: Variant = .regular
    ) -> Font {
        .custom(
            widgetFontName(for: variant),
            size: widgetBasePointSize(for: textStyle),
            relativeTo: textStyle
        )
    }

    static func widgetFont(
        size: CGFloat,
        relativeTo textStyle: Font.TextStyle,
        variant: Variant = .regular
    ) -> Font {
        .custom(
            widgetFontName(for: variant),
            size: size,
            relativeTo: textStyle
        )
    }

    private static func manifestationCTFont(
        relativeTo textStyle: Font.TextStyle,
        variant: Variant,
        sizeAdjustment: CGFloat
    ) -> CTFont? {
        let uiTextStyle = uiTextStyle(for: textStyle)
        let basePointSize = UIFont.preferredFont(forTextStyle: uiTextStyle).pointSize + sizeAdjustment
        let scaledPointSize = UIFontMetrics(forTextStyle: uiTextStyle).scaledValue(for: basePointSize)

        if let graphicsFont = graphicsFonts[variant] {
            return CTFontCreateWithGraphicsFont(graphicsFont, scaledPointSize, nil, nil)
        }

        for fontName in resolvedNames(for: variant) {
            if let customFont = UIFont(name: fontName, size: scaledPointSize) {
                return customFont as CTFont
            }
        }

        return nil
    }

    private static func manifestationCTFont(
        size: CGFloat,
        relativeTo textStyle: Font.TextStyle,
        variant: Variant
    ) -> CTFont? {
        let uiTextStyle = uiTextStyle(for: textStyle)
        let scaledPointSize = UIFontMetrics(forTextStyle: uiTextStyle).scaledValue(for: size)

        if let graphicsFont = graphicsFonts[variant] {
            return CTFontCreateWithGraphicsFont(graphicsFont, scaledPointSize, nil, nil)
        }

        for fontName in resolvedNames(for: variant) {
            if let customFont = UIFont(name: fontName, size: scaledPointSize) {
                return customFont as CTFont
            }
        }

        return nil
    }

    private static func manifestationFallbackUIFont(
        relativeTo textStyle: Font.TextStyle,
        variant: Variant,
        sizeAdjustment: CGFloat
    ) -> UIFont {
        let uiTextStyle = uiTextStyle(for: textStyle)
        let basePointSize = UIFont.preferredFont(forTextStyle: uiTextStyle).pointSize + sizeAdjustment
        let metrics = UIFontMetrics(forTextStyle: uiTextStyle)
        let fallbackFont = fallbackBaseFont(size: basePointSize, variant: variant)
        return metrics.scaledFont(for: fallbackFont)
    }

    private static func manifestationFallbackUIFont(
        size: CGFloat,
        relativeTo textStyle: Font.TextStyle,
        variant: Variant
    ) -> UIFont {
        let uiTextStyle = uiTextStyle(for: textStyle)
        let metrics = UIFontMetrics(forTextStyle: uiTextStyle)
        let fallbackFont = fallbackBaseFont(size: size, variant: variant)
        return metrics.scaledFont(for: fallbackFont)
    }

    private static func fallbackBaseFont(size: CGFloat, variant: Variant) -> UIFont {
        let baseFont = UIFont.systemFont(ofSize: size, weight: variant.fallbackWeight)

        guard variant.isItalic,
              let italicDescriptor = baseFont.fontDescriptor.withSymbolicTraits(.traitItalic)
        else {
            return baseFont
        }

        return UIFont(descriptor: italicDescriptor, size: size)
    }

    private static func resolvedNames(for variant: Variant) -> [String] {
        var names: [String] = []

        if let resolvedName = postScriptNames[variant] {
            names.append(resolvedName)
        }

        names.append(contentsOf: variant.candidateFontNames)
        return Array(NSOrderedSet(array: names)) as? [String] ?? names
    }

    private static func widgetFontName(for variant: Variant) -> String {
        ensureBundledFontsRegistered()
        return resolvedNames(for: variant).first ?? variant.candidateFontNames.first ?? "BradfordLL-Regular"
    }

    private static func widgetBasePointSize(for textStyle: Font.TextStyle) -> CGFloat {
        switch textStyle {
        case .largeTitle:
            return 34
        case .title:
            return 28
        case .title2:
            return 22
        case .title3:
            return 20
        case .headline:
            return 17
        case .subheadline:
            return 15
        case .callout:
            return 16
        case .footnote:
            return 13
        case .caption:
            return 12
        case .caption2:
            return 11
        default:
            return 17
        }
    }

    private static func ensureBundledFontsRegistered() {
        guard !hasRegisteredFonts else { return }
        for variant in Variant.allCases {
            registerBundledFont(for: variant)
        }
        hasRegisteredFonts = true
    }

    private static func registerBundledFont(for variant: Variant) {
        guard let url = Bundle.main.url(forResource: variant.bundleFileName, withExtension: nil) else { return }

        if let provider = CGDataProvider(url: url as CFURL),
           let cgFont = CGFont(provider),
           let postScriptName = cgFont.postScriptName as String? {
            graphicsFonts[variant] = cgFont
            postScriptNames[variant] = postScriptName
        }
    }

    private static func uiTextStyle(for textStyle: Font.TextStyle) -> UIFont.TextStyle {
        switch textStyle {
        case .largeTitle:
            return .largeTitle
        case .title:
            return .title1
        case .title2:
            return .title2
        case .title3:
            return .title3
        case .headline:
            return .headline
        case .subheadline:
            return .subheadline
        case .callout:
            return .callout
        case .footnote:
            return .footnote
        case .caption:
            return .caption1
        case .caption2:
            return .caption2
        default:
            return .body
        }
    }

    enum Variant: CaseIterable {
        case book
        case regular
        case medium
        case mediumItalic
        case bold

        fileprivate var bundleFileName: String {
            switch self {
            case .book:
                return "BradfordLL-Book.otf"
            case .regular:
                return "BradfordLL-Regular.otf"
            case .medium:
                return "BradfordLL-Medium.otf"
            case .mediumItalic:
                return "BradfordLL-MediumItalic.otf"
            case .bold:
                return "BradfordLL-Bold.otf"
            }
        }

        fileprivate var candidateFontNames: [String] {
            switch self {
            case .book:
                return ["BradfordLL-Book", "Bradford LL Book", "Bradford LL"]
            case .regular:
                return ["BradfordLL-Regular", "Bradford LL Regular", "Bradford LL"]
            case .medium:
                return ["BradfordLL-Medium", "Bradford LL Medium", "Bradford LL"]
            case .mediumItalic:
                return ["BradfordLL-MediumItalic", "Bradford LL Medium Italic", "Bradford LL Italic"]
            case .bold:
                return ["BradfordLL-Bold", "Bradford LL Bold", "Bradford LL"]
            }
        }

        fileprivate var fallbackWeight: UIFont.Weight {
            switch self {
            case .book:
                return .light
            case .regular:
                return .regular
            case .medium:
                return .medium
            case .mediumItalic:
                return .medium
            case .bold:
                return .bold
            }
        }

        fileprivate var isItalic: Bool {
            switch self {
            case .mediumItalic:
                return true
            case .book, .regular, .medium, .bold:
                return false
            }
        }
    }
}

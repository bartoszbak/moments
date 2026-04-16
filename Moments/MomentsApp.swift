import SwiftUI
import UIKit
import CoreText

@main
struct MomentsApp: App {
    @StateObject private var repository: CountdownRepository
    @StateObject private var timerManager = TimerManager()
    @StateObject private var subscriptionService = SubscriptionService.shared
    @AppStorage(AppSettingsKeys.appearance) private var appearanceSetting = AppSettingsDefaults.appearance

    @Environment(\.scenePhase) private var scenePhase

    init() {
        AppTypography.configure()

        let persistence = PersistenceController.shared
        _repository = StateObject(wrappedValue: CountdownRepository(
            viewContext: persistence.container.viewContext,
            backgroundContext: persistence.newBackgroundContext()
        ))
    }

    var body: some Scene {
        WindowGroup {
            AppThemeRootView()
                .environmentObject(repository)
                .environmentObject(timerManager)
                .environmentObject(subscriptionService)
                .preferredColorScheme(AppTheme.preferredColorScheme(for: appearanceSetting))
                .task {
                    await subscriptionService.configure()
                }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                timerManager.start()
                Task { @MainActor in
                    await subscriptionService.refreshCustomerInfo()
                    await ManifestNotificationService.shared.refreshAuthorizationStatus()
                    await ManifestNotificationService.shared.reconcile(countdowns: repository.countdowns)
                }
            case .background, .inactive:
                timerManager.stop()
            default:
                break
            }
        }
    }
}

enum AppTypography {
    private static var manifestationPostScriptNames: [ManifestationVariant: String] = [:]
    private static var manifestationGraphicsFonts: [ManifestationVariant: CGFont] = [:]

    static func configure() {
        registerBundledFonts()

        let largeTitleFont = UIFont.preferredRoundedFont(forTextStyle: .largeTitle, weight: .bold)
        let titleFont = UIFont.preferredRoundedFont(forTextStyle: .headline, weight: .semibold)

        let navigationBarAppearance = UINavigationBarAppearance()
        navigationBarAppearance.configureWithDefaultBackground()
        navigationBarAppearance.largeTitleTextAttributes = [.font: largeTitleFont]
        navigationBarAppearance.titleTextAttributes = [.font: titleFont]

        UINavigationBar.appearance().standardAppearance = navigationBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navigationBarAppearance
        UINavigationBar.appearance().compactAppearance = navigationBarAppearance
    }

    static func manifestationFont(
        relativeTo textStyle: Font.TextStyle,
        variant: ManifestationVariant = .regular,
        sizeAdjustment: CGFloat = 0
    ) -> Font {
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

    static func manifestationFont(
        size: CGFloat,
        relativeTo textStyle: Font.TextStyle,
        variant: ManifestationVariant = .regular
    ) -> Font {
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

    private static func manifestationCTFont(
        relativeTo textStyle: Font.TextStyle,
        variant: ManifestationVariant,
        sizeAdjustment: CGFloat
    ) -> CTFont? {
        let uiTextStyle = uiTextStyle(for: textStyle)
        let basePointSize = UIFont.preferredFont(forTextStyle: uiTextStyle).pointSize + sizeAdjustment
        let scaledPointSize = UIFontMetrics(forTextStyle: uiTextStyle).scaledValue(for: basePointSize)

        if let graphicsFont = manifestationGraphicsFonts[variant] {
            return CTFontCreateWithGraphicsFont(graphicsFont, scaledPointSize, nil, nil)
        }

        for fontName in manifestationResolvedNames(for: variant) {
            if let customFont = UIFont(name: fontName, size: scaledPointSize) {
                return customFont as CTFont
            }
        }

        return nil
    }

    private static func manifestationCTFont(
        size: CGFloat,
        relativeTo textStyle: Font.TextStyle,
        variant: ManifestationVariant
    ) -> CTFont? {
        let uiTextStyle = uiTextStyle(for: textStyle)
        let scaledPointSize = UIFontMetrics(forTextStyle: uiTextStyle).scaledValue(for: size)

        if let graphicsFont = manifestationGraphicsFonts[variant] {
            return CTFontCreateWithGraphicsFont(graphicsFont, scaledPointSize, nil, nil)
        }

        for fontName in manifestationResolvedNames(for: variant) {
            if let customFont = UIFont(name: fontName, size: scaledPointSize) {
                return customFont as CTFont
            }
        }

        return nil
    }

    private static func manifestationFallbackUIFont(
        relativeTo textStyle: Font.TextStyle,
        variant: ManifestationVariant,
        sizeAdjustment: CGFloat
    ) -> UIFont {
        let uiTextStyle = uiTextStyle(for: textStyle)
        let basePointSize = UIFont.preferredFont(forTextStyle: uiTextStyle).pointSize + sizeAdjustment
        let metrics = UIFontMetrics(forTextStyle: uiTextStyle)
        let fallbackFont = manifestationFallbackBaseFont(
            size: basePointSize,
            variant: variant
        )
        return metrics.scaledFont(for: fallbackFont)
    }

    private static func manifestationFallbackUIFont(
        size: CGFloat,
        relativeTo textStyle: Font.TextStyle,
        variant: ManifestationVariant
    ) -> UIFont {
        let uiTextStyle = uiTextStyle(for: textStyle)
        let metrics = UIFontMetrics(forTextStyle: uiTextStyle)
        let fallbackFont = manifestationFallbackBaseFont(
            size: size,
            variant: variant
        )
        return metrics.scaledFont(for: fallbackFont)
    }

    private static func manifestationFallbackBaseFont(
        size: CGFloat,
        variant: ManifestationVariant
    ) -> UIFont {
        let baseFont = UIFont.systemFont(ofSize: size, weight: variant.fallbackWeight)

        guard variant.isItalic,
              let italicDescriptor = baseFont.fontDescriptor.withSymbolicTraits(.traitItalic)
        else {
            return baseFont
        }

        return UIFont(descriptor: italicDescriptor, size: size)
    }

    private static func manifestationResolvedNames(for variant: ManifestationVariant) -> [String] {
        var names: [String] = []

        if let resolvedName = manifestationPostScriptNames[variant] {
            names.append(resolvedName)
        }

        names.append(contentsOf: variant.candidateFontNames)
        return Array(NSOrderedSet(array: names)) as? [String] ?? names
    }

    private static func registerBundledFonts() {
        for variant in ManifestationVariant.allCases {
            registerBundledFont(for: variant)
        }
    }

    private static func registerBundledFont(for variant: ManifestationVariant) {
        guard let url = Bundle.main.url(forResource: variant.bundleFileName, withExtension: nil) else { return }

        if let provider = CGDataProvider(url: url as CFURL),
           let cgFont = CGFont(provider),
           let postScriptName = cgFont.postScriptName as String? {
            manifestationGraphicsFonts[variant] = cgFont
            manifestationPostScriptNames[variant] = postScriptName
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

    enum ManifestationVariant: CaseIterable {
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

private extension UIFont {
    static func preferredRoundedFont(forTextStyle textStyle: TextStyle, weight: Weight) -> UIFont {
        let baseFont = preferredFont(forTextStyle: textStyle)
        let systemFont = UIFont.systemFont(ofSize: baseFont.pointSize, weight: weight)

        guard let roundedDescriptor = systemFont.fontDescriptor.withDesign(.rounded) else {
            return systemFont
        }

        return UIFont(descriptor: roundedDescriptor, size: systemFont.pointSize)
    }
}

private struct AppThemeRootView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var deepLinkedCountdownID: UUID?

    var body: some View {
        CountdownListView(deepLinkedCountdownID: $deepLinkedCountdownID)
            .tint(.blue)
            .toggleStyle(AppSwitchToggleStyle(tint: .blue, colorScheme: colorScheme))
            .fontDesign(.rounded)
            .onOpenURL { url in
                deepLinkedCountdownID = MomentDeepLink.countdownID(from: url)
            }
    }
}

private struct AppSwitchToggleStyle: ToggleStyle {
    let tint: Color
    let colorScheme: ColorScheme

    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer(minLength: 12)

            Button {
                withAnimation(.snappy(duration: 0.18, extraBounce: 0)) {
                    configuration.isOn.toggle()
                }
            } label: {
                ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                    Capsule()
                        .fill(trackColor(isOn: configuration.isOn))
                        .overlay {
                            Capsule()
                                .stroke(trackBorderColor(isOn: configuration.isOn), lineWidth: 1)
                        }
                        .frame(width: 52, height: 32)

                    Circle()
                        .fill(knobColor(isOn: configuration.isOn))
                        .frame(width: 28, height: 28)
                        .padding(2)
                        .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.12), radius: 1.5, y: 1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityRepresentation {
                Toggle(isOn: Binding(
                    get: { configuration.isOn },
                    set: { configuration.isOn = $0 }
                )) {
                    configuration.label
                }
            }
        }
    }

    private func trackColor(isOn: Bool) -> Color {
        if isOn {
            return tint
        }

        return colorScheme == .dark
            ? Color.black.opacity(0.88)
            : Color(uiColor: .tertiarySystemFill)
    }

    private func trackBorderColor(isOn: Bool) -> Color {
        if isOn, colorScheme == .dark {
            return .white.opacity(0.18)
        }

        return .clear
    }

    private func knobColor(isOn: Bool) -> Color {
        return Color.white
    }
}

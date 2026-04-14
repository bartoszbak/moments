import SwiftUI
import UIKit
import CoreText

@main
struct MomentsApp: App {
    @StateObject private var repository: CountdownRepository
    @StateObject private var timerManager = TimerManager()
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
                .preferredColorScheme(AppTheme.preferredColorScheme(for: appearanceSetting))
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                timerManager.start()
            case .background, .inactive:
                timerManager.stop()
            default:
                break
            }
        }
    }
}

enum AppTypography {
    private static var editorialNewPostScriptNames: [EditorialNewVariant: String] = [:]

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

    static func editorialNewFont(
        relativeTo textStyle: Font.TextStyle,
        variant: EditorialNewVariant = .regular,
        sizeAdjustment: CGFloat = 0
    ) -> Font {
        let resolvedFont = editorialNewUIFont(
            relativeTo: textStyle,
            variant: variant,
            sizeAdjustment: sizeAdjustment
        )
        return .custom(resolvedFont.fontName, size: resolvedFont.pointSize)
    }

    private static func editorialNewUIFont(
        relativeTo textStyle: Font.TextStyle,
        variant: EditorialNewVariant,
        sizeAdjustment: CGFloat
    ) -> UIFont {
        let uiTextStyle = uiTextStyle(for: textStyle)
        let basePointSize = UIFont.preferredFont(forTextStyle: uiTextStyle).pointSize + sizeAdjustment
        let metrics = UIFontMetrics(forTextStyle: uiTextStyle)

        for fontName in editorialNewResolvedNames(for: variant) {
            if let customFont = UIFont(name: fontName, size: basePointSize) {
                return metrics.scaledFont(for: customFont)
            }
        }

        let fallbackFont = UIFont.systemFont(ofSize: basePointSize, weight: variant.fallbackWeight)
        return metrics.scaledFont(for: fallbackFont)
    }

    private static func editorialNewResolvedNames(for variant: EditorialNewVariant) -> [String] {
        var names: [String] = []

        if let resolvedName = editorialNewPostScriptNames[variant] {
            names.append(resolvedName)
        }

        names.append(contentsOf: variant.candidateFontNames)
        return Array(NSOrderedSet(array: names)) as? [String] ?? names
    }

    private static func registerBundledFonts() {
        for variant in EditorialNewVariant.allCases {
            registerBundledFont(for: variant)
        }
    }

    private static func registerBundledFont(for variant: EditorialNewVariant) {
        guard let url = Bundle.main.url(forResource: variant.bundleFileName, withExtension: nil) else { return }

        if let provider = CGDataProvider(url: url as CFURL),
           let cgFont = CGFont(provider),
           let postScriptName = cgFont.postScriptName as String? {
            editorialNewPostScriptNames[variant] = postScriptName

            var registrationError: Unmanaged<CFError>?
            CTFontManagerRegisterGraphicsFont(cgFont, &registrationError)
        } else {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
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

    enum EditorialNewVariant: CaseIterable {
        case light
        case regular
        case medium

        fileprivate var bundleFileName: String {
            switch self {
            case .light:
                return "moments-Light.ttf"
            case .regular:
                return "moments-Regular.ttf"
            case .medium:
                return "moments-Medium.ttf"
            }
        }

        fileprivate var candidateFontNames: [String] {
            switch self {
            case .light:
                return ["EditorialNew-Light", "Editorial New Light", "Editorial New"]
            case .regular:
                return ["EditorialNew-Regular", "Editorial New Regular", "Editorial New"]
            case .medium:
                return ["EditorialNew-Medium", "Editorial New Medium", "Editorial New"]
            }
        }

        fileprivate var fallbackWeight: UIFont.Weight {
            switch self {
            case .light:
                return .light
            case .regular:
                return .regular
            case .medium:
                return .medium
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

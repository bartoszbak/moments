import SwiftUI
import UIKit

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

private enum AppTypography {
    static func configure() {
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
    @AppStorage(AppSettingsKeys.appearance) private var appearanceSetting = AppSettingsDefaults.appearance

    var body: some View {
        CountdownListView()
            .tint(interfaceTintColor)
            .toggleStyle(AppSwitchToggleStyle(tint: interfaceTintColor, colorScheme: effectiveColorScheme))
            .fontDesign(.rounded)
    }

    private var interfaceTintColor: Color {
        AppTheme.defaultInterfaceTintColor(for: effectiveColorScheme)
    }

    private var preferredColorScheme: ColorScheme? {
        AppTheme.preferredColorScheme(for: appearanceSetting)
    }

    private var effectiveColorScheme: ColorScheme {
        preferredColorScheme ?? colorScheme
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

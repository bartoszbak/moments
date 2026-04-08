import SwiftUI

@main
struct TillAppApp: App {
    @StateObject private var repository: CountdownRepository
    @StateObject private var timerManager = TimerManager()
    @AppStorage(AppSettingsKeys.appearance) private var appearanceSetting = AppSettingsDefaults.appearance

    @Environment(\.scenePhase) private var scenePhase

    init() {
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

private struct AppThemeRootView: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(AppSettingsKeys.interfaceTintHex) private var interfaceTintHex = AppSettingsDefaults.interfaceTintHex

    var body: some View {
        CountdownListView()
            .tint(interfaceTintColor)
            .toggleStyle(AppSwitchToggleStyle(tint: interfaceTintColor, colorScheme: colorScheme))
    }

    private var interfaceTintColor: Color {
        AppTheme.interfaceTintColor(from: interfaceTintHex, for: colorScheme)
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

        return Color(uiColor: colorScheme == .dark ? .secondarySystemFill : .tertiarySystemFill)
    }

    private func trackBorderColor(isOn: Bool) -> Color {
        if isOn, colorScheme == .dark {
            return .white.opacity(0.18)
        }

        return .clear
    }

    private func knobColor(isOn: Bool) -> Color {
        if colorScheme == .dark, isOn {
            return Color.black.opacity(0.82)
        }

        return Color.white
    }
}

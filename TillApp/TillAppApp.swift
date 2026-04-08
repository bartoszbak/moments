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
            .tint(AppTheme.interfaceTintColor(from: interfaceTintHex, for: colorScheme))
    }
}

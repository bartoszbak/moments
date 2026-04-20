import SwiftUI
import UIKit
import UserNotifications

@main
struct MomentsApp: App {
    @StateObject private var repository: CountdownRepository
    @StateObject private var timerManager = TimerManager()
    @StateObject private var subscriptionService = SubscriptionService.shared
    @StateObject private var navigationCoordinator = AppNavigationCoordinator.shared
    @AppStorage(AppSettingsKeys.appearance) private var appearanceSetting = AppSettingsDefaults.appearance
    @UIApplicationDelegateAdaptor(MomentsAppDelegate.self) private var appDelegate

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
                .environmentObject(navigationCoordinator)
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

@MainActor
final class AppNavigationCoordinator: ObservableObject {
    static let shared = AppNavigationCoordinator()

    @Published private(set) var pendingPreviewCountdownID: UUID?
    @Published private(set) var addMomentRequestToken = 0

    private init() {}

    func handle(url: URL) {
        guard let countdownID = MomentDeepLink.countdownID(from: url) else { return }
        pendingPreviewCountdownID = countdownID
    }

    @discardableResult
    func handle(shortcutItem: UIApplicationShortcutItem) -> Bool {
        guard shortcutItem.type == AppShortcut.addMomentType else { return false }
        addMomentRequestToken += 1
        return true
    }

    func handle(notificationUserInfo: [AnyHashable: Any]) {
        guard let countdownID = MomentDeepLink.countdownID(from: notificationUserInfo) else { return }
        pendingPreviewCountdownID = countdownID
    }

    func clearPendingPreviewCountdownID() {
        pendingPreviewCountdownID = nil
    }
}

enum AppShortcut {
    static let addMomentType = "com.tillappcounter.Moments.addMoment"
}

final class MomentsAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: nil,
            sessionRole: connectingSceneSession.role
        )
        configuration.delegateClass = MomentsSceneDelegate.self
        return configuration
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await MainActor.run {
            AppNavigationCoordinator.shared.handle(
                notificationUserInfo: response.notification.request.content.userInfo
            )
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}

final class MomentsSceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let shortcutItem = connectionOptions.shortcutItem else { return }

        Task { @MainActor in
            _ = AppNavigationCoordinator.shared.handle(shortcutItem: shortcutItem)
        }
    }

    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        Task { @MainActor in
            let handled = AppNavigationCoordinator.shared.handle(shortcutItem: shortcutItem)
            completionHandler(handled)
        }
    }
}

enum AppTypography {
    typealias ManifestationVariant = ManifestationTypography.Variant

    static func configure() {
        ManifestationTypography.configure()

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
        ManifestationTypography.font(
            relativeTo: textStyle,
            variant: variant,
            sizeAdjustment: sizeAdjustment
        )
    }

    static func manifestationFont(
        size: CGFloat,
        relativeTo textStyle: Font.TextStyle,
        variant: ManifestationVariant = .regular
    ) -> Font {
        ManifestationTypography.font(
            size: size,
            relativeTo: textStyle,
            variant: variant
        )
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
    @EnvironmentObject private var navigationCoordinator: AppNavigationCoordinator

    var body: some View {
        CountdownListView()
            .tint(.blue)
            .toggleStyle(AppSwitchToggleStyle(tint: .blue, colorScheme: colorScheme))
            .fontDesign(.rounded)
            .onOpenURL { url in
                navigationCoordinator.handle(url: url)
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

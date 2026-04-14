import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var repository: CountdownRepository
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage(AppSettingsKeys.appearance) private var appearanceSetting = AppSettingsDefaults.appearance
    @AppStorage(AppSettingsKeys.interfaceTintHex) private var interfaceTintHex = AppSettingsDefaults.interfaceTintHex
    @AppStorage(AppSettingsKeys.backgroundGradientEnabled) private var backgroundGradientEnabled = AppSettingsDefaults.backgroundGradientEnabled
    @AppStorage(AppSettingsKeys.calendarIntegrationEnabled) private var isCalendarIntegrationEnabled = AppSettingsDefaults.calendarIntegrationEnabled
    @AppStorage(AppSettingsKeys.manifestNotificationsEnabled) private var manifestNotificationsEnabled = AppSettingsDefaults.manifestNotificationsEnabled
    @AppStorage(AppSettingsKeys.hapticsEnabled) private var hapticsEnabled = AppSettingsDefaults.hapticsEnabled

    @StateObject private var calendarService = CalendarService.shared
    @StateObject private var manifestNotificationService = ManifestNotificationService.shared
    @State private var isReconcilingCalendarToggle = false
    @State private var isReconcilingManifestNotificationToggle = false

    private var isiPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        Image("Settings")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 88, height: 88)
                        Spacer()
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
                    .listRowBackground(Color.clear)
                }

                Section {
                    Picker("Mode", selection: $appearanceSetting) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    ColorPicker("Accent Color", selection: plusButtonColorBinding, supportsOpacity: false)
                    Toggle("Background Gradient", isOn: $backgroundGradientEnabled)
                        .tint(controlTintColor)

                    if isUsingCustomPlusButtonColor {
                        Button("Reset to Default") {
                            interfaceTintHex = AppSettingsDefaults.interfaceTintHex
                        }
                        .foregroundStyle(controlTintColor)
                    }
                } header: {
                    Text("Appearance")
                }

                Section {
                    Toggle("Add moments to Calendar", isOn: $isCalendarIntegrationEnabled)
                        .tint(controlTintColor)
                } header: {
                    Text("Calendar")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Moments will appear as events in your Apple calendar.")
                        calendarFooter
                    }
                }

                Section {
                    Toggle("Manifestation Reminder", isOn: $manifestNotificationsEnabled)
                        .tint(controlTintColor)
                } header: {
                    Text("Notifications")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enable this to receive manifestation notification. Set the schedule when creating or editing a manifestation.")
                        manifestNotificationFooter
                    }
                }

                Section {
                    Toggle("Haptic Feedback", isOn: $hapticsEnabled)
                        .tint(controlTintColor)
                }

                Section("Developer") {
                    NavigationLink("Developer Tools") {
                        DeveloperMenuView()
                    }
                }
                Section {
                    EmptyView()
                } footer: {
                    Link(destination: URL(string: "https://x.com/bartbak_")!) {
                        Text(buildNumberText)
                            .multilineTextAlignment(.center)
                    }
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, isiPad ? 32 : 0)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .tint(controlTintColor)
            .task {
                reconcileCalendarAccessState()
                await reconcileManifestNotificationAccessState()
            }
            .onChange(of: isCalendarIntegrationEnabled) { _, isEnabled in
                guard !isReconcilingCalendarToggle else { return }
                handleCalendarToggleChange(isEnabled)
            }
            .onChange(of: manifestNotificationsEnabled) { _, isEnabled in
                guard !isReconcilingManifestNotificationToggle else { return }
                handleManifestNotificationToggleChange(isEnabled)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(doneButtonColor)
                }
            }
        }
        .id(appearanceSetting)
        .preferredColorScheme(preferredColorScheme)
    }

    private var plusButtonColorBinding: Binding<Color> {
        Binding(
            get: { AppTheme.baseInterfaceTintColor(from: interfaceTintHex) },
            set: { interfaceTintHex = $0.hexString }
        )
    }

    private var isUsingCustomPlusButtonColor: Bool {
        interfaceTintHex != AppSettingsDefaults.interfaceTintHex
    }

    private var controlTintColor: Color {
        .blue
    }

    private var preferredColorScheme: ColorScheme? {
        AppTheme.preferredColorScheme(for: appearanceSetting)
    }

    private var effectiveColorScheme: ColorScheme {
        preferredColorScheme ?? colorScheme
    }

    private var doneButtonColor: Color {
        effectiveColorScheme == .dark ? .white : .black
    }

    private var buildNumberText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        return "Moments \(version),\nMade by Bart Bak,\nin ZH, Switzerland."
    }

    @ViewBuilder
    private var calendarFooter: some View {
        switch calendarService.authorizationStatus {
        case .notDetermined:
            EmptyView()
        case .fullAccess:
            EmptyView()
        case .denied, .restricted, .writeOnly:
            VStack(alignment: .leading, spacing: 8) {
                Text("Access denied. Open Settings to allow calendar access.")
                Button("Open Settings", action: openAppSettings)
            }
        @unknown default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var manifestNotificationFooter: some View {
        switch manifestNotificationService.authorizationStatus {
        case .notDetermined:
            EmptyView()
        case .authorized, .provisional, .ephemeral:
            EmptyView()
        case .denied:
            VStack(alignment: .leading, spacing: 8) {
                Text("Notifications are blocked. Open Settings to allow manifestation reminders.")
                Button("Open Settings", action: openAppSettings)
            }
        @unknown default:
            EmptyView()
        }
    }

    private func handleCalendarToggleChange(_ isEnabled: Bool) {
        guard isEnabled else { return }

        Task { @MainActor in
            let granted = await calendarService.requestAccess()
            if !granted {
                setCalendarIntegrationEnabled(false)
            }
        }
    }

    private func handleManifestNotificationToggleChange(_ isEnabled: Bool) {
        if !isEnabled {
            reconcileManifestNotifications()
            return
        }

        Task { @MainActor in
            let granted = await manifestNotificationService.requestAuthorization()
            if !granted {
                setManifestNotificationsEnabled(false)
            }
            await manifestNotificationService.refreshAuthorizationStatus()
            reconcileManifestNotifications()
        }
    }

    private func reconcileCalendarAccessState() {
        calendarService.refreshAuthorizationStatus()
        if isCalendarIntegrationEnabled && calendarService.authorizationStatus != .fullAccess {
            setCalendarIntegrationEnabled(false)
        }
    }

    private func reconcileManifestNotificationAccessState() async {
        await manifestNotificationService.refreshAuthorizationStatus()
        if manifestNotificationsEnabled && !manifestNotificationsAuthorized {
            setManifestNotificationsEnabled(false)
        }
        reconcileManifestNotifications()
    }

    private func setCalendarIntegrationEnabled(_ isEnabled: Bool) {
        isReconcilingCalendarToggle = true
        isCalendarIntegrationEnabled = isEnabled
        isReconcilingCalendarToggle = false
    }

    private func setManifestNotificationsEnabled(_ isEnabled: Bool) {
        isReconcilingManifestNotificationToggle = true
        manifestNotificationsEnabled = isEnabled
        isReconcilingManifestNotificationToggle = false
    }

    private var manifestNotificationsAuthorized: Bool {
        switch manifestNotificationService.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    private func reconcileManifestNotifications() {
        Task { @MainActor in
            await manifestNotificationService.reconcile(countdowns: repository.countdowns)
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

enum AppSettingsKeys {
    static let appearance = "settings.appearance"
    static let interfaceTintHex = "settings.interfaceTintHex"
    static let backgroundGradientEnabled = "settings.backgroundGradient.enabled"
    static let calendarIntegrationEnabled = "settings.calendarIntegration.enabled"
    static let manifestNotificationsEnabled = "settings.manifestNotifications.enabled"
    static let manifestNotificationsDefaultRhythm = "settings.manifestNotifications.defaultRhythm"
    static let manifestNotificationsHour = "settings.manifestNotifications.hour"
    static let manifestNotificationsMinute = "settings.manifestNotifications.minute"
    static let hapticsEnabled = "settings.haptics.enabled"
    static let hasSeenIntroSheet = "settings.hasSeenIntroSheet"
}

enum AppSettingsDefaults {
    static let appearance = "system"
    static let interfaceTintHex = "#D3E2FF"
    static let backgroundGradientEnabled = true
    static let calendarIntegrationEnabled = false
    static let manifestNotificationsEnabled = false
    static let manifestNotificationsDefaultRhythm = ManifestNotificationRhythm.daily.rawValue
    static let manifestNotificationsHour = 9
    static let manifestNotificationsMinute = 0
    static let hapticsEnabled = true
    static let hasSeenIntroSheet = false
}

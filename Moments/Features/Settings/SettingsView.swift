import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var repository: CountdownRepository
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage(AppSettingsKeys.appearance) private var appearanceSetting = AppSettingsDefaults.appearance
    @AppStorage(AppSettingsKeys.interfaceTintHex) private var interfaceTintHex = AppSettingsDefaults.interfaceTintHex
    @AppStorage(AppSettingsKeys.backgroundGradientEnabled) private var backgroundGradientEnabled = AppSettingsDefaults.backgroundGradientEnabled
    @AppStorage(AppSettingsKeys.calendarIntegrationEnabled) private var isCalendarIntegrationEnabled = AppSettingsDefaults.calendarIntegrationEnabled
    @AppStorage(AppSettingsKeys.manifestNotificationsEnabled) private var manifestNotificationsEnabled = AppSettingsDefaults.manifestNotificationsEnabled
    @AppStorage(AppSettingsKeys.hapticsEnabled) private var hapticsEnabled = AppSettingsDefaults.hapticsEnabled

    @StateObject private var manifestNotificationService = ManifestNotificationService.shared
    @State private var isReconcilingManifestNotificationToggle = false
    @State private var selectedAppIcon = AppIconOption.current
    @State private var isUpdatingAppIcon = false
    @State private var appIconErrorMessage: String?
    @State private var showingPremiumPaywall = false
    @State private var highlightedPaywallFeature: PremiumFeature?
    @State private var settingsBadgeRotation = 0.0

    private var isiPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        HStack {
                            Spacer()

                            if subscriptionService.isPremium {
                                premiumSettingsHeaderIcon
                            } else {
                                Image("Settings")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 88, height: 88)
                            }

                            Spacer()
                        }

                        if subscriptionService.isPremium {
                            Text("Thank you for the support")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)
                        } else if showsUpgradeButton {
                            Text("Turn intention into momentum. Count down to the life you're creating.")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 32)

                            Button("Get Plus") {
                                showingPremiumPaywall = true
                            }
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .adaptiveGlassProminentButtonStyle()
                            .tint(plusButtonTintColor)
                            .foregroundStyle(plusButtonLabelColor)
                        }
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
                    if subscriptionService.isPremium {
                        HStack(spacing: 12) {
                            ForEach(AppIconOption.allCases) { option in
                                Button {
                                    updateAppIcon(to: option)
                                } label: {
                                    appIconPreview(option, size: 64, cornerRadius: 16)
                                        .frame(maxWidth: .infinity)
                                        .padding(6)
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                                .strokeBorder(
                                                    selectedAppIcon == option ? controlTintColor : .clear,
                                                    lineWidth: 2
                                                )
                                        }
                                }
                                .buttonStyle(.plain)
                                .disabled(isUpdatingAppIcon || !supportsAlternateIcons)
                            }
                        }
                        .padding(.vertical, 4)
                    } else {
                        PremiumLockedRowButton("Alternate Icons") {
                            highlightedPaywallFeature = .alternateIcons
                        }
                    }
                } header: {
                    Text("App Icon")
                } footer: {
                    if let appIconErrorMessage {
                        Text(appIconErrorMessage)
                    }
                }

                Section("Calendar") {
                    if subscriptionService.isPremium {
                        NavigationLink {
                            CalendarSyncSettingsView()
                        } label: {
                            LabeledContent("Calendar Sync") {
                                Text(calendarSyncStatusText)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        PremiumLockedRowButton("Calendar Sync") {
                            highlightedPaywallFeature = .calendarSync
                        }
                    }
                }

                Section {
                    if subscriptionService.isPremium {
                        Toggle("Manifestation Reminder", isOn: $manifestNotificationsEnabled)
                            .tint(controlTintColor)
                    } else {
                        PremiumLockedRowButton("Manifestation Reminder") {
                            highlightedPaywallFeature = .manifestationReminders
                        }
                    }
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
                syncSelectedAppIcon()
                await reconcileManifestNotificationAccessState()
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
        .sheet(isPresented: $showingPremiumPaywall) {
            PremiumPaywallView()
                .environmentObject(subscriptionService)
        }
        .sheet(item: $highlightedPaywallFeature) { feature in
            PremiumPaywallView(highlightedFeature: feature)
                .environmentObject(subscriptionService)
        }
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

    private var premiumSettingsHeaderIcon: some View {
        HStack(spacing: -32) {
            Image("AppIconRainbowPreview")
                .resizable()
                .scaledToFill()
                .frame(width: 88, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                }

            Image(settingsSubscriberBadgeAssetName)
                .resizable()
                .scaledToFit()
                .frame(width: 97, height: 97)
                .rotationEffect(.degrees(settingsBadgeRotation))
        }
        .onAppear {
            guard settingsBadgeRotation == 0 else { return }

            withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
                settingsBadgeRotation = 360
            }
        }
    }

    private var settingsSubscriberBadgeAssetName: String {
        effectiveColorScheme == .dark ? "SubscriberBadgeDark" : "SubscriberBadge"
    }

    private var showsUpgradeButton: Bool {
        !subscriptionService.isPremium
    }

    private var showsManageSubscriptionsButton: Bool {
        if case .premium(.subscription) = subscriptionService.accessState {
            return true
        }

        return false
    }

    private var showsPrivacyPolicyButton: Bool {
        subscriptionService.privacyPolicyURL != nil && !showsManageSubscriptionsButton
    }

    private var plusButtonTintColor: Color {
        effectiveColorScheme == .dark ? .white : .black
    }

    private var plusButtonLabelColor: Color {
        effectiveColorScheme == .dark ? .black : .white
    }

    private func openManageSubscriptions() {
        guard let url = subscriptionService.manageSubscriptionsURL else { return }
        openURL(url)
    }

    private func openPrivacyPolicy() {
        guard let url = subscriptionService.privacyPolicyURL else { return }
        openURL(url)
    }

    private var buildNumberText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        return "Moments \(version),\nMade by Bart Bak,\nin ZH, Switzerland."
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

    private func reconcileManifestNotificationAccessState() async {
        await manifestNotificationService.refreshAuthorizationStatus()
        if manifestNotificationsEnabled && !manifestNotificationsAuthorized {
            setManifestNotificationsEnabled(false)
        }
        reconcileManifestNotifications()
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

    private var calendarSyncStatusText: String {
        isCalendarIntegrationEnabled ? "On" : "Off"
    }

    private var supportsAlternateIcons: Bool {
        UIApplication.shared.supportsAlternateIcons
    }

    private func syncSelectedAppIcon() {
        selectedAppIcon = AppIconOption.current
    }

    private func updateAppIcon(to option: AppIconOption) {
        guard supportsAlternateIcons else { return }

        isUpdatingAppIcon = true
        appIconErrorMessage = nil

        UIApplication.shared.setAlternateIconName(option.alternateIconName) { error in
            Task { @MainActor in
                isUpdatingAppIcon = false

                if let error {
                    appIconErrorMessage = error.localizedDescription
                    syncSelectedAppIcon()
                    return
                }

                selectedAppIcon = option
            }
        }
    }

    private func appIconPreview(
        _ option: AppIconOption,
        size: CGFloat = 44,
        cornerRadius: CGFloat = 10
    ) -> some View {
        Image(option.previewAssetName)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.10), radius: 8, y: 3)
    }

}

struct CalendarSyncSettingsView: View {
    @EnvironmentObject private var repository: CountdownRepository
    @EnvironmentObject private var subscriptionService: SubscriptionService

    @AppStorage(AppSettingsKeys.calendarIntegrationEnabled) private var isCalendarIntegrationEnabled = AppSettingsDefaults.calendarIntegrationEnabled
    @AppStorage(AppSettingsKeys.calendarSyncCalendarIdentifier) private var selectedCalendarIdentifier = AppSettingsDefaults.calendarSyncCalendarIdentifier

    @StateObject private var calendarService = CalendarService.shared
    @State private var isReconcilingCalendarToggle = false
    @State private var highlightedPaywallFeature: PremiumFeature?

    var body: some View {
        Form {
            if subscriptionService.isPremium {
                Section("Calendar Sync") {
                    Toggle("Sync future events", isOn: $isCalendarIntegrationEnabled)
                        .tint(controlTintColor)
                }

                Section {
                    if calendarService.availableCalendars.isEmpty {
                        LabeledContent("Calendar") {
                            Text("No iCloud calendar")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Picker("Calendar", selection: calendarSelectionBinding) {
                            ForEach(calendarService.availableCalendars) { option in
                                Text(option.displayName).tag(option.id)
                            }
                        }
                        .disabled(!isCalendarIntegrationEnabled)
                    }
                } header: {
                    Text("Sync To")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Choose which calendar receives synced future events.")
                        calendarFooter
                    }
                }
            } else {
                Section("Calendar Sync") {
                    PremiumLockedRowButton("Sync future events") {
                        highlightedPaywallFeature = .calendarSync
                    }
                }

                Section {
                    PremiumLockedRowButton("Calendar") {
                        highlightedPaywallFeature = .calendarSync
                    }
                } header: {
                    Text("Sync To")
                } footer: {
                    Text("Unlock calendar sync with Moments Plus.")
                }
            }
        }
        .navigationTitle("Calendar Sync")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            reconcileCalendarAccessState()
            ensureSelectedCalendarIdentifier()
        }
        .onChange(of: isCalendarIntegrationEnabled) { _, isEnabled in
            guard !isReconcilingCalendarToggle else { return }
            handleCalendarToggleChange(isEnabled)
        }
        .onChange(of: selectedCalendarIdentifier) { oldValue, newValue in
            guard oldValue != newValue, !newValue.isEmpty else { return }

            Task { @MainActor in
                await repository.reconcileCalendarEvents()
            }
        }
        .sheet(item: $highlightedPaywallFeature) { feature in
            PremiumPaywallView(highlightedFeature: feature)
                .environmentObject(subscriptionService)
        }
    }

    private var controlTintColor: Color {
        .blue
    }

    private var calendarSelectionBinding: Binding<String> {
        Binding(
            get: {
                if calendarService.availableCalendars.contains(where: { $0.id == selectedCalendarIdentifier }) {
                    return selectedCalendarIdentifier
                } else {
                    return calendarService.availableCalendars.first?.id ?? selectedCalendarIdentifier
                }
            },
            set: { selectedCalendarIdentifier = $0 }
        )
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

    private func handleCalendarToggleChange(_ isEnabled: Bool) {
        if !isEnabled {
            Task { @MainActor in
                await repository.reconcileCalendarEvents()
            }
            return
        }

        Task { @MainActor in
            let granted = await calendarService.requestAccess()
            if granted {
                ensureSelectedCalendarIdentifier()
                await repository.reconcileCalendarEvents()
            } else {
                setCalendarIntegrationEnabled(false)
            }
        }
    }

    private func reconcileCalendarAccessState() {
        calendarService.refreshAuthorizationStatus()
        if isCalendarIntegrationEnabled && calendarService.authorizationStatus != .fullAccess {
            setCalendarIntegrationEnabled(false)
        }
    }

    private func ensureSelectedCalendarIdentifier() {
        calendarService.refreshAvailableCalendars()

        if calendarService.availableCalendars.contains(where: { $0.id == selectedCalendarIdentifier }) {
            return
        }

        if let firstIdentifier = calendarService.availableCalendars.first?.id {
            selectedCalendarIdentifier = firstIdentifier
        }
    }

    private func setCalendarIntegrationEnabled(_ isEnabled: Bool) {
        isReconcilingCalendarToggle = true
        isCalendarIntegrationEnabled = isEnabled
        isReconcilingCalendarToggle = false
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

struct PremiumLockedRowButton: View {
    let title: String
    var action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .foregroundStyle(.primary)

                Spacer()

                PremiumPill()
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

struct PremiumPill: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text("Plus")
            .font(.caption.weight(.semibold))
            .foregroundStyle(colorScheme == .dark ? .black : .white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(colorScheme == .dark ? Color.white : Color.black)
            )
    }
}

enum AppSettingsKeys {
    static let appearance = "settings.appearance"
    static let interfaceTintHex = "settings.interfaceTintHex"
    static let backgroundGradientEnabled = "settings.backgroundGradient.enabled"
    static let calendarIntegrationEnabled = "settings.calendarIntegration.enabled"
    static let calendarSyncCalendarIdentifier = "settings.calendarIntegration.calendarIdentifier"
    static let manifestNotificationsEnabled = "settings.manifestNotifications.enabled"
    static let manifestNotificationsDefaultRhythm = "settings.manifestNotifications.defaultRhythm"
    static let manifestNotificationsHour = "settings.manifestNotifications.hour"
    static let manifestNotificationsMinute = "settings.manifestNotifications.minute"
    static let hapticsEnabled = "settings.haptics.enabled"
    static let hasSeenIntroSheet = "settings.hasSeenIntroSheet"
    static let freeCreatedMomentCount = "settings.freeTier.createdMomentCount"
    static let freeAIGenerationCount = "settings.freeTier.aiGenerationCount"
}

enum AppSettingsDefaults {
    static let appearance = "system"
    static let interfaceTintHex = "#D3E2FF"
    static let backgroundGradientEnabled = true
    static let calendarIntegrationEnabled = false
    static let calendarSyncCalendarIdentifier = ""
    static let manifestNotificationsEnabled = false
    static let manifestNotificationsDefaultRhythm = ManifestNotificationRhythm.daily.rawValue
    static let manifestNotificationsHour = 9
    static let manifestNotificationsMinute = 0
    static let hapticsEnabled = true
    static let hasSeenIntroSheet = false
}

enum AppIconOption: String, CaseIterable, Identifiable {
    case original
    case fog
    case dark
    case rainbow

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .original:
            return "Original"
        case .fog:
            return "Fog"
        case .dark:
            return "Dark"
        case .rainbow:
            return "Rainbow"
        }
    }

    var description: String {
        switch self {
        case .original:
            return "The current Moments icon."
        case .fog:
            return "A softer monochrome variant."
        case .dark:
            return "A darker monochrome variant."
        case .rainbow:
            return "A multicolor variant."
        }
    }

    var alternateIconName: String? {
        switch self {
        case .original:
            return nil
        case .fog:
            return "AppIconFog"
        case .dark:
            return "AppIconDark"
        case .rainbow:
            return "AppIconRainbow"
        }
    }

    var previewAssetName: String {
        switch self {
        case .original:
            return "AppIconOriginalPreview"
        case .fog:
            return "AppIconFogPreview"
        case .dark:
            return "AppIconDarkPreview"
        case .rainbow:
            return "AppIconRainbowPreview"
        }
    }

    static var current: AppIconOption {
        let alternateIconName = UIApplication.shared.alternateIconName
        return allCases.first(where: { $0.alternateIconName == alternateIconName }) ?? .original
    }
}

private extension Color {
    var resolvedLuminance: Double {
        let uiColor = UIColor(self).resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0

        uiColor.getRed(&red, green: &green, blue: &blue, alpha: nil)
        return 0.2126 * Double(red) + 0.7152 * Double(green) + 0.0722 * Double(blue)
    }
}

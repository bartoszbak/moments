import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage(AppSettingsKeys.appearance) private var appearanceSetting = AppSettingsDefaults.appearance
    @AppStorage(AppSettingsKeys.interfaceTintHex) private var interfaceTintHex = AppSettingsDefaults.interfaceTintHex
    @AppStorage(AppSettingsKeys.calendarIntegrationEnabled) private var isCalendarIntegrationEnabled = AppSettingsDefaults.calendarIntegrationEnabled
    @AppStorage(AppSettingsKeys.hapticsEnabled) private var hapticsEnabled = AppSettingsDefaults.hapticsEnabled

    @StateObject private var calendarService = CalendarService.shared
    @State private var isReconcilingCalendarToggle = false

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

                    if isUsingCustomPlusButtonColor {
                        Button("Reset to Default") {
                            interfaceTintHex = AppSettingsDefaults.interfaceTintHex
                        }
                        .foregroundStyle(interfaceTintColor)
                    }
                } header: {
                    Text("Appearance")
                }

                Section {
                    Toggle("Add moments to Calendar", isOn: $isCalendarIntegrationEnabled)
                        .tint(interfaceTintColor)
                } header: {
                    Text("Calendar")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Moments will appear as events in your Apple calendar.")
                        calendarFooter
                    }
                }

                Section {
                    Toggle("Haptic Feedback", isOn: $hapticsEnabled)
                        .tint(interfaceTintColor)
                }

                Section("Developer") {
                    NavigationLink("Developer Tools") {
                        DeveloperMenuView()
                    }
                }
                Section {
                    EmptyView()
                } footer: {
                    Text(buildNumberText)
                        .font(.footnote.weight(.medium))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .tint(interfaceTintColor)
            .task {
                reconcileCalendarAccessState()
            }
            .onChange(of: isCalendarIntegrationEnabled) { _, isEnabled in
                guard !isReconcilingCalendarToggle else { return }
                handleCalendarToggleChange(isEnabled)
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

    private var interfaceTintColor: Color {
        AppTheme.defaultInterfaceTintColor(for: effectiveColorScheme)
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
        return "Moments \(version),\nMade by Bart Bak\nin Zh, Switzerland."
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
        guard isEnabled else { return }

        Task { @MainActor in
            let granted = await calendarService.requestAccess()
            if !granted {
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

enum AppSettingsKeys {
    static let appearance = "settings.appearance"
    static let interfaceTintHex = "settings.interfaceTintHex"
    static let calendarIntegrationEnabled = "settings.calendarIntegration.enabled"
    static let hapticsEnabled = "settings.haptics.enabled"
    static let hasSeenIntroSheet = "settings.hasSeenIntroSheet"
}

enum AppSettingsDefaults {
    static let appearance = "system"
    static let interfaceTintHex = "#000000"
    static let calendarIntegrationEnabled = false
    static let hapticsEnabled = true
    static let hasSeenIntroSheet = false
}

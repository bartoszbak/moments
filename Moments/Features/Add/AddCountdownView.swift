import SwiftUI
import UIKit
import UserNotifications

extension Notification.Name {
    static let countdownCreated = Notification.Name("countdownCreated")
}

struct MomentDescriptionEditorView: View {
    @Binding var text: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))

                    if text.isEmpty {
                        Text("Optional")
                            .foregroundStyle(.tertiary)
                            .padding(.top, 20)
                            .padding(.leading, 20)
                    }

                    TextEditor(text: $text)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 240)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                }
                .frame(maxWidth: .infinity, minHeight: 240, alignment: .top)

                Text("Example: \"I'm going for the meetup to hang out and chill.\"")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
            .padding(16)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Description")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "minus")
                }
                .accessibilityLabel("Clear description")
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .foregroundStyle(.red)
            }
        }
    }
}

struct TargetDatePickerRow: View {
    @Binding var targetDate: Date
    let tintColor: Color

    var body: some View {
        LabeledContent("Targeted date") {
            DatePicker(
                "",
                selection: $targetDate,
                displayedComponents: .date
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            .foregroundStyle(tintColor)
            .font(.body)
        }
    }
}

struct UpsellBanner: View {
    let iconName: String
    let iconColor: Color
    let message: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: iconName)
                    .font(.system(size: 27, weight: .medium))
                    .foregroundStyle(iconColor)
                    .frame(width: 44, height: 44)

                Text(message)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)

                Spacer(minLength: 8)

                PremiumPill()
            }
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
        }
        .buttonStyle(.plain)
    }
}

struct ManifestNotificationSettingsRows: View {
    @Binding var isEnabled: Bool
    @Binding var rhythm: ManifestNotificationRhythm
    @Binding var reminderTime: Date

    let authorizationStatus: UNAuthorizationStatus
    let tintColor: Color
    let openSettings: () -> Void

    var body: some View {
        Toggle("Notification", isOn: $isEnabled)
            .tint(tintColor)

        if isEnabled {
            Picker("Rhythm", selection: $rhythm) {
                ForEach(ManifestNotificationRhythm.allCases, id: \.self) { option in
                    Text(option.title).tag(option)
                }
            }

            DatePicker(
                "Time",
                selection: $reminderTime,
                displayedComponents: .hourAndMinute
            )
        }
    }
}

struct AddCountdownView: View {
    @EnvironmentObject private var repository: CountdownRepository
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage(AppSettingsKeys.appearance) private var appearanceSetting = AppSettingsDefaults.appearance
    @AppStorage(AppSettingsKeys.manifestNotificationsEnabled) private var manifestNotificationsGlobalEnabled = AppSettingsDefaults.manifestNotificationsEnabled
    @AppStorage(AppSettingsKeys.manifestNotificationsHour) private var manifestNotificationsHour = AppSettingsDefaults.manifestNotificationsHour
    @AppStorage(AppSettingsKeys.manifestNotificationsMinute) private var manifestNotificationsMinute = AppSettingsDefaults.manifestNotificationsMinute
    @AppStorage(AppSettingsKeys.manifestNotificationsDefaultRhythm) private var manifestNotificationsDefaultRhythm = AppSettingsDefaults.manifestNotificationsDefaultRhythm

    @StateObject private var manifestNotificationService = ManifestNotificationService.shared
    @State private var title = ""
    @State private var detailsText = ""
    @State private var targetDate = Calendar.current.startOfDay(
        for: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    )
    @State private var background: BackgroundSelection = .preset(5)
    @State private var startPercentage: Double = WidgetProgressDefaults.startPercentage
    @State private var showProgress: Bool = true
    @State private var showDate: Bool = true
    @State private var isMinimalisticWidget = false
    @State private var minimalWidgetProgressStyle: MinimalWidgetProgressStyle = .defaultStyle
    @State private var widgetFontOption: WidgetFontOption = .defaultOption
    @State private var showSymbol: Bool = true
    @State private var sfSymbolName: String? = MomentSymbolPolicy.defaultSymbolName
    @State private var showSymbolPicker = false
    @State private var isFutureManifestation = false
    @State private var manifestNotificationsEnabled = false
    @State private var manifestNotificationRhythm: ManifestNotificationRhythm = .daily
    @State private var manifestReminderTime = Calendar.current.startOfDay(for: Date())
    @State private var isCreating = false
    @State private var showTitleError = false
    @State private var hasInitializedManifestNotificationSettings = false
    @State private var highlightedPaywallFeature: PremiumFeature?

    private var isValid: Bool {
        return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var showsProgressIndicatorSection: Bool {
        if isFutureManifestation { return false }
        return Calendar.current.startOfDay(for: targetDate) >= Calendar.current.startOfDay(for: Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Moment name", text: $title)
                        .onChange(of: title) { _, _ in
                            if showTitleError, !title.isEmpty { showTitleError = false }
                        }
                    NavigationLink {
                        MomentDescriptionEditorView(text: $detailsText)
                    } label: {
                        LabeledContent("Description") {
                            Text(detailsActionTitle)
                                .fontWeight(.semibold)
                                .foregroundStyle(.tint)
                        }
                    }
                    SymbolOptionsRows(
                        showSymbol: $showSymbol,
                        sfSymbolName: $sfSymbolName,
                        showSymbolPicker: $showSymbolPicker
                    )
                    if showTitleError {
                        Label("Title is required", systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(.red).font(.caption)
                    }
                }
                Section("Manifestation") {
                    Toggle("Future manifestation", isOn: $isFutureManifestation)
                    if isFutureManifestation {
                        if subscriptionService.isPremium {
                            ManifestNotificationSettingsRows(
                                isEnabled: $manifestNotificationsEnabled,
                                rhythm: $manifestNotificationRhythm,
                                reminderTime: $manifestReminderTime,
                                authorizationStatus: manifestNotificationService.authorizationStatus,
                                tintColor: controlTintColor,
                                openSettings: openAppSettings
                            )
                        } else {
                            UpsellBanner(
                                iconName: "bell.badge",
                                iconColor: .secondary,
                                message: "Unlock manifestation reminders"
                            ) {
                                highlightedPaywallFeature = .manifestationReminders
                            }
                        }
                    }
                }
                if !isFutureManifestation {
                    Section("Time") {
                        TargetDatePickerRow(targetDate: $targetDate, tintColor: controlTintColor)
                        if !subscriptionService.isPremium {
                            UpsellBanner(
                                iconName: "calendar",
                                iconColor: .secondary,
                                message: "Unlock calendar sync,\nnotifications"
                            ) {
                                highlightedPaywallFeature = .calendarSync
                            }
                        }
                    }
                }
                BackgroundPickerSection(
                    selection: $background
                )
                WidgetOptionsSection(
                    allowsDateOption: !isFutureManifestation,
                    showsProgressBarStyleOption: showsProgressIndicatorSection,
                    isMinimalisticWidget: $isMinimalisticWidget,
                    minimalWidgetProgressStyle: $minimalWidgetProgressStyle,
                    showDate: $showDate,
                    widgetFontOption: $widgetFontOption
                )
                if showsProgressIndicatorSection {
                    ProgressStartPickerSection(
                        isEnabled: $showProgress,
                        value: $startPercentage
                    )
                }
            }
            .nativeGlassToggleStyle(tintColor: controlTintColor)
            .tint(controlTintColor)
            .navigationTitle("Add a Moment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Cancel")
                    .foregroundStyle(toolbarButtonColor)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: create) {
                        Image(systemName: "checkmark")
                    }
                        .accessibilityLabel("Create")
                        .disabled(!isValid || isCreating)
                        .fontWeight(.semibold)
                        .foregroundStyle(confirmationButtonColor)
                }
            }
        }
        .sheet(isPresented: $showSymbolPicker) {
            SFSymbolPickerView(selectedSymbol: $sfSymbolName, tintColor: controlTintColor)
        }
        .sheet(item: $highlightedPaywallFeature) { feature in
            PremiumPaywallView(highlightedFeature: feature)
                .environmentObject(subscriptionService)
        }
        .onChange(of: isFutureManifestation) { _, enabled in
            if enabled {
                showDate = false
                isMinimalisticWidget = false
            }
        }
        .onChange(of: manifestNotificationsEnabled) { _, isEnabled in
            handleManifestNotificationToggleChange(isEnabled)
        }
        .task {
            initializeManifestNotificationSettingsIfNeeded()
            await manifestNotificationService.refreshAuthorizationStatus()
        }
        .preferredColorScheme(preferredColorScheme)
    }

    private func create() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDetails = detailsText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { showTitleError = true; return }
        isCreating = true
        let newID = UUID()
        let normalizedSymbolName = MomentSymbolPolicy.normalized(sfSymbolName)
        persistManifestNotificationDefaults()

        var imagePath: String?
        var thumbPath: String?
        var colorIndex: Int?
        var colorHex: String?

        switch background {
        case .photo(let image):
            if let paths = ImageStorageService.save(image: image, id: newID) {
                imagePath = paths.backgroundPath
                thumbPath = paths.thumbnailPath
            }
        case .preset(let idx):
            colorIndex = idx
            colorHex = ColorPalette.presets[idx].hexString
        case .custom(let color):
            colorHex = color.hexString
        case .none:
            break
        }

        do {
            try repository.create(
                id: newID,
                title: trimmed,
                detailsText: trimmedDetails.isEmpty ? nil : trimmedDetails,
                targetDate: Calendar.current.startOfDay(for: targetDate),
                backgroundImagePath: imagePath, thumbnailImagePath: thumbPath,
                backgroundColorIndex: colorIndex, backgroundColorHex: colorHex,
                startPercentage: startPercentage,
                showProgress: showProgress,
                showDate: showDate,
                isMinimalisticWidget: isFutureManifestation ? false : isMinimalisticWidget,
                minimalWidgetProgressStyle: minimalWidgetProgressStyle,
                widgetFontOption: widgetFontOption,
                sfSymbolName: normalizedSymbolName,
                isFutureManifestation: isFutureManifestation,
                manifestNotificationsEnabled: isFutureManifestation && manifestNotificationsEnabled,
                manifestNotificationRhythm: isFutureManifestation ? manifestNotificationRhythm : nil,
                manifestNotificationWeekday: manifestNotificationWeekday
            )
            subscriptionService.recordCreatedMoment()
            reconcileManifestNotifications()
            AppHaptics.impact(.medium)
            NotificationCenter.default.post(name: .countdownCreated, object: nil)
            dismiss()
        } catch { isCreating = false }
    }

    private var preferredColorScheme: ColorScheme? {
        AppTheme.preferredColorScheme(for: appearanceSetting)
    }

    private var effectiveColorScheme: ColorScheme {
        preferredColorScheme ?? colorScheme
    }

    private var controlTintColor: Color {
        .blue
    }

    private var toolbarButtonColor: Color {
        effectiveColorScheme == .dark ? .white : .black
    }

    private var confirmationButtonColor: Color {
        isValid && !isCreating ? controlTintColor : .secondary
    }

    private var detailsActionTitle: String {
        detailsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Add" : "Edit"
    }

    private var defaultManifestRhythm: ManifestNotificationRhythm {
        ManifestNotificationRhythm(rawValue: manifestNotificationsDefaultRhythm) ?? .daily
    }

    private var storedManifestReminderTime: Date {
        let baseDate = Calendar.current.startOfDay(for: Date())
        return Calendar.current.date(
            bySettingHour: manifestNotificationsHour,
            minute: manifestNotificationsMinute,
            second: 0,
            of: baseDate
        ) ?? baseDate
    }

    private var manifestNotificationWeekday: Int? {
        guard isFutureManifestation, manifestNotificationRhythm == .weekly else { return nil }
        return Calendar.current.component(.weekday, from: Date())
    }

    private func initializeManifestNotificationSettingsIfNeeded() {
        guard !hasInitializedManifestNotificationSettings else { return }
        manifestNotificationRhythm = defaultManifestRhythm
        manifestReminderTime = storedManifestReminderTime
        hasInitializedManifestNotificationSettings = true
    }

    private func handleManifestNotificationToggleChange(_ isEnabled: Bool) {
        guard isEnabled else { return }

        Task { @MainActor in
            let granted = await manifestNotificationService.requestAuthorization()
            guard granted else {
                manifestNotificationsEnabled = false
                return
            }

            await manifestNotificationService.refreshAuthorizationStatus()
        }
    }

    private func persistManifestNotificationDefaults() {
        guard isFutureManifestation else { return }

        let components = Calendar.current.dateComponents([.hour, .minute], from: manifestReminderTime)
        manifestNotificationsHour = components.hour ?? AppSettingsDefaults.manifestNotificationsHour
        manifestNotificationsMinute = components.minute ?? AppSettingsDefaults.manifestNotificationsMinute

        if manifestNotificationsEnabled {
            manifestNotificationsGlobalEnabled = true
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func reconcileManifestNotifications() {
        Task { @MainActor in
            await manifestNotificationService.reconcile(countdowns: repository.countdowns)
        }
    }

}

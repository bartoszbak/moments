import SwiftUI
import UIKit

struct EditCountdownView: View {
    let countdownID: UUID
    var onDelete: (() -> Void)? = nil

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
    @State private var targetDate = Date()
    @State private var background: BackgroundSelection = .none
    @State private var startPercentage: Double = WidgetProgressDefaults.startPercentage
    @State private var showProgress: Bool = true
    @State private var showDate: Bool = true
    @State private var isMinimalisticWidget = false
    @State private var minimalWidgetProgressStyle: MinimalWidgetProgressStyle = .defaultStyle
    @State private var widgetFontOption: WidgetFontOption = .defaultOption
    @State private var showSymbol: Bool = false
    @State private var isFutureManifestation = false
    @State private var sfSymbolName: String? = nil
    @State private var showSymbolPicker = false
    @State private var hasLoaded = false
    @State private var showDeleteConfirmation = false
    @State private var manifestNotificationsEnabled = false
    @State private var manifestNotificationRhythm: ManifestNotificationRhythm = .daily
    @State private var manifestReminderTime = Calendar.current.startOfDay(for: Date())
    @State private var photoChanged = false
    @State private var existingImagePath: String? = nil
    @State private var existingThumbPath: String? = nil
    @State private var highlightedPaywallFeature: PremiumFeature?

    private var countdown: Countdown? {
        repository.countdowns.first { $0.id == countdownID }
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
                    selection: $background,
                    onNewPhotoSelected: { photoChanged = true }
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
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete")
                            Spacer()
                        }
                    }
                }
            }
            .nativeGlassToggleStyle(tintColor: controlTintColor)
            .tint(controlTintColor)
            .sheet(isPresented: $showSymbolPicker) {
                SFSymbolPickerView(selectedSymbol: $sfSymbolName, tintColor: controlTintColor)
            }
            .sheet(item: $highlightedPaywallFeature) { feature in
                PremiumPaywallView(highlightedFeature: feature)
                    .environmentObject(subscriptionService)
            }
            .alert("Delete this moment?", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive, action: delete)
                Button("Cancel", role: .cancel) { }
            }
            .navigationTitle("Edit Moment")
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
                    Button(action: save) {
                        Image(systemName: "checkmark")
                    }
                        .accessibilityLabel("Save")
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .fontWeight(.semibold)
                        .foregroundStyle(confirmationButtonColor)
                }
            }
            .onAppear {
                guard !hasLoaded, let countdown else { return }
                title = countdown.title
                detailsText = countdown.detailsText ?? ""
                targetDate = Calendar.current.startOfDay(for: countdown.targetDate)
                existingImagePath = countdown.backgroundImageURL?.path
                existingThumbPath = countdown.thumbnailImageURL?.path

                if let thumbURL = countdown.thumbnailImageURL,
                   let image = UIImage(contentsOfFile: thumbURL.path) {
                    background = .photo(image)
                } else if let idx = countdown.backgroundColorIndex,
                          countdown.backgroundColorHex == ColorPalette.presets[idx].hexString {
                    background = .preset(idx)
                } else if let hex = countdown.backgroundColorHex,
                          let color = Color(hex: hex) {
                    background = .custom(color)
                } else if let idx = countdown.backgroundColorIndex {
                    background = .preset(idx)
                }
                startPercentage = countdown.startPercentage
                showProgress = countdown.showProgress
                showDate = countdown.showDate
                isMinimalisticWidget = countdown.isMinimalisticWidget
                minimalWidgetProgressStyle = countdown.minimalWidgetProgressStyle
                widgetFontOption = countdown.widgetFontOption
                isFutureManifestation = countdown.isFutureManifestation
                manifestNotificationsEnabled = countdown.manifestNotificationsEnabled
                manifestNotificationRhythm = countdown.manifestNotificationRhythm ?? defaultManifestRhythm
                manifestReminderTime = storedManifestReminderTime
                sfSymbolName = MomentSymbolPolicy.normalized(countdown.sfSymbolName)
                showSymbol = sfSymbolName != nil
                hasLoaded = true
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
                await manifestNotificationService.refreshAuthorizationStatus()
            }
        }
        .preferredColorScheme(preferredColorScheme)
    }

    private func save() {
        guard let countdown else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDetails = detailsText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let normalizedTargetDate = Calendar.current.startOfDay(for: targetDate)
        let normalizedDetails = trimmedDetails.isEmpty ? nil : trimmedDetails
        let normalizedSymbolName = MomentSymbolPolicy.normalized(sfSymbolName)
        persistManifestNotificationDefaults()
        let invalidatesReflection =
            trimmed != countdown.title ||
            normalizedTargetDate != Calendar.current.startOfDay(for: countdown.targetDate) ||
            isFutureManifestation != countdown.isFutureManifestation ||
            normalizedDetails != countdown.detailsText

        var imagePath: String?? = nil
        var thumbPath: String?? = nil
        var colorIndex: Int?? = nil
        var colorHex: String?? = nil

        switch background {
        case .photo(let image):
            if photoChanged {
                if let paths = ImageStorageService.save(image: image, id: countdown.id) {
                    imagePath = .some(paths.backgroundPath)
                    thumbPath = .some(paths.thumbnailPath)
                    colorIndex = .some(nil)
                    colorHex = .some(nil)
                }
            } else {
                // Photo unchanged — preserve existing paths
                imagePath = .some(existingImagePath)
                thumbPath = .some(existingThumbPath)
                colorIndex = .some(nil)
                colorHex = .some(nil)
            }
        case .preset(let idx):
            colorIndex = .some(idx)
            colorHex = .some(ColorPalette.presets[idx].hexString)
            if existingImagePath != nil || existingThumbPath != nil {
                if let p = existingImagePath { try? FileManager.default.removeItem(atPath: p) }
                if let p = existingThumbPath { try? FileManager.default.removeItem(atPath: p) }
                imagePath = .some(nil)
                thumbPath = .some(nil)
            }
        case .custom(let color):
            colorIndex = .some(nil)
            colorHex = .some(color.hexString)
            if existingImagePath != nil || existingThumbPath != nil {
                if let p = existingImagePath { try? FileManager.default.removeItem(atPath: p) }
                if let p = existingThumbPath { try? FileManager.default.removeItem(atPath: p) }
                imagePath = .some(nil)
                thumbPath = .some(nil)
            }
        case .none:
            colorIndex = .some(nil)
            colorHex = .some(nil)
            if existingImagePath != nil || existingThumbPath != nil {
                if let p = existingImagePath { try? FileManager.default.removeItem(atPath: p) }
                if let p = existingThumbPath { try? FileManager.default.removeItem(atPath: p) }
                imagePath = .some(nil)
                thumbPath = .some(nil)
            }
        }

        try? repository.update(
            countdown,
            title: trimmed,
            detailsText: .some(normalizedDetails),
            targetDate: normalizedTargetDate,
            backgroundImagePath: imagePath, thumbnailImagePath: thumbPath,
            backgroundColorIndex: colorIndex, backgroundColorHex: colorHex,
            startPercentage: startPercentage,
            showProgress: showProgress,
            showDate: showDate,
            isMinimalisticWidget: isFutureManifestation ? false : isMinimalisticWidget,
            minimalWidgetProgressStyle: minimalWidgetProgressStyle,
            widgetFontOption: widgetFontOption,
            sfSymbolName: .some(normalizedSymbolName),
            reflectionSurfaceText: invalidatesReflection ? .some(nil) : nil,
            reflectionText: invalidatesReflection ? .some(nil) : nil,
            reflectionGuidanceText: invalidatesReflection ? .some(nil) : nil,
            reflectionPrimaryText: invalidatesReflection ? .some(nil) : nil,
            reflectionExpandedText: invalidatesReflection ? .some(nil) : nil,
            reflectionGeneratedAt: invalidatesReflection ? .some(nil) : nil,
            isFutureManifestation: isFutureManifestation,
            manifestNotificationsEnabled: isFutureManifestation ? manifestNotificationsEnabled : false,
            manifestNotificationRhythm: isFutureManifestation ? .some(manifestNotificationRhythm) : .some(nil),
            manifestNotificationWeekday: .some(manifestNotificationWeekday(for: countdown))
        )
        reconcileManifestNotifications()
        AppHaptics.impact(.light)
        dismiss()
    }

    private func delete() {
        guard let countdown else { return }
        try? repository.delete(countdown)
        AppHaptics.impact(.medium)
        if let onDelete {
            onDelete()
        } else {
            dismiss()
        }
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
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : controlTintColor
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

    private func manifestNotificationWeekday(for countdown: Countdown) -> Int? {
        guard isFutureManifestation, manifestNotificationRhythm == .weekly else { return nil }
        return countdown.manifestNotificationWeekday
            ?? Calendar.current.component(.weekday, from: Date())
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

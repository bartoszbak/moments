import SwiftUI
struct EditCountdownView: View {
    let countdownID: UUID

    @EnvironmentObject private var repository: CountdownRepository
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage(AppSettingsKeys.appearance) private var appearanceSetting = AppSettingsDefaults.appearance

    @State private var title = ""
    @State private var targetDate = Date()
    @State private var background: BackgroundSelection = .none
    @State private var startPercentage: Double = 1.0
    @State private var showDate: Bool = true
    @State private var showSymbol: Bool = false
    @State private var sfSymbolName: String? = nil
    @State private var showSymbolPicker = false
    @State private var hasLoaded = false
    @State private var showDeleteConfirmation = false
    @State private var photoChanged = false
    @State private var existingImagePath: String? = nil
    @State private var existingThumbPath: String? = nil

    private var countdown: Countdown? {
        repository.countdowns.first { $0.id == countdownID }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Countdown name", text: $title)
                }
                Section("Target Date") {
                    TargetDatePickerRow(targetDate: $targetDate, tintColor: interfaceTintColor)
                }
                BackgroundPickerSection(
                    selection: $background,
                    onNewPhotoSelected: { photoChanged = true }
                )
                WidgetOptionsSection(
                    showDate: $showDate,
                    showSymbol: $showSymbol,
                    sfSymbolName: $sfSymbolName,
                    showSymbolPicker: $showSymbolPicker
                )
                ProgressStartPickerSection(value: $startPercentage)
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
            .tint(interfaceTintColor)
            .sheet(isPresented: $showSymbolPicker) {
                SFSymbolPickerView(selectedSymbol: $sfSymbolName, tintColor: interfaceTintColor)
            }
            .alert("Delete this moment?", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive, action: delete)
                Button("Cancel", role: .cancel) { }
            }
            .navigationTitle("Edit Moment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(toolbarButtonColor)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .fontWeight(.semibold)
                        .foregroundStyle(toolbarButtonColor)
                }
            }
            .onAppear {
                guard !hasLoaded, let countdown else { return }
                title = countdown.title
                targetDate = Calendar.current.startOfDay(for: countdown.targetDate)
                if let idx = countdown.backgroundColorIndex {
                    background = .preset(idx)
                } else if let hex = countdown.backgroundColorHex,
                          let color = Color(hex: hex) {
                    background = .custom(color)
                } else if let thumbURL = countdown.thumbnailImageURL,
                          let image = UIImage(contentsOfFile: thumbURL.path) {
                    background = .photo(image)
                    existingImagePath = countdown.backgroundImageURL?.path
                    existingThumbPath = thumbURL.path
                }
                startPercentage = countdown.startPercentage
                showDate = countdown.showDate
                sfSymbolName = countdown.sfSymbolName
                showSymbol = countdown.sfSymbolName != nil
                hasLoaded = true
            }
        }
        .preferredColorScheme(preferredColorScheme)
    }

    private func save() {
        guard let countdown else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

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
            targetDate: Calendar.current.startOfDay(for: targetDate),
            backgroundImagePath: imagePath, thumbnailImagePath: thumbPath,
            backgroundColorIndex: colorIndex, backgroundColorHex: colorHex,
            startPercentage: startPercentage,
            showDate: showDate,
            sfSymbolName: .some(sfSymbolName)
        )
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        dismiss()
    }

    private func delete() {
        guard let countdown else { return }
        try? repository.delete(countdown)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
    }

    private var preferredColorScheme: ColorScheme? {
        AppTheme.preferredColorScheme(for: appearanceSetting)
    }

    private var effectiveColorScheme: ColorScheme {
        preferredColorScheme ?? colorScheme
    }

    private var interfaceTintColor: Color {
        AppTheme.defaultInterfaceTintColor(for: effectiveColorScheme)
    }

    private var toolbarButtonColor: Color {
        effectiveColorScheme == .dark ? .white : .black
    }
}

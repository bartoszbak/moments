import SwiftUI
struct TargetDatePickerRow: View {
    @Binding var targetDate: Date
    let tintColor: Color

    var body: some View {
        LabeledContent("Date") {
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

struct AddCountdownView: View {
    @EnvironmentObject private var repository: CountdownRepository
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage(AppSettingsKeys.appearance) private var appearanceSetting = AppSettingsDefaults.appearance

    @State private var title = ""
    @State private var detailsText = ""
    @State private var targetDate = Calendar.current.startOfDay(
        for: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    )
    @State private var background: BackgroundSelection = .none
    @State private var startPercentage: Double = 1.0
    @State private var showDate: Bool = true
    @State private var showSymbol: Bool = false
    @State private var sfSymbolName: String? = nil
    @State private var showSymbolPicker = false
    @State private var isFutureManifestation = false
    @State private var isCreating = false
    @State private var showTitleError = false

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var showsProgressIndicatorSection: Bool {
        if isFutureManifestation { return false }
        Calendar.current.startOfDay(for: targetDate) >= Calendar.current.startOfDay(for: Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("e.g. New Year, Vacation…", text: $title)
                        .onChange(of: title) { _, _ in
                            if showTitleError, !title.isEmpty { showTitleError = false }
                        }
                    if showTitleError {
                        Label("Title is required", systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(.red).font(.caption)
                    }
                }
                Section {
                    TextField("Optional", text: $detailsText, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Description")
                } footer: {
                    Text("Context for intelligence")
                }
                Section("Target Date") {
                    Toggle("Future manifestation", isOn: $isFutureManifestation)
                    TargetDatePickerRow(targetDate: $targetDate, tintColor: controlTintColor)
                        .opacity(isFutureManifestation ? 0.45 : 1)
                        .disabled(isFutureManifestation)
                }
                BackgroundPickerSection(
                    selection: $background
                )
                WidgetOptionsSection(
                    showDate: $showDate,
                    showSymbol: $showSymbol,
                    sfSymbolName: $sfSymbolName,
                    showSymbolPicker: $showSymbolPicker
                )
                if showsProgressIndicatorSection {
                    ProgressStartPickerSection(value: $startPercentage)
                }
            }
            .tint(controlTintColor)
            .navigationTitle("Add a Moment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(toolbarButtonColor)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create", action: create)
                        .disabled(!isValid || isCreating)
                        .fontWeight(.semibold)
                        .foregroundStyle(toolbarButtonColor)
                }
            }
        }
        .sheet(isPresented: $showSymbolPicker) {
            SFSymbolPickerView(selectedSymbol: $sfSymbolName, tintColor: controlTintColor)
        }
        .preferredColorScheme(preferredColorScheme)
    }

    private func create() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDetails = detailsText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { showTitleError = true; return }
        isCreating = true
        let newID = UUID()

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
                showDate: showDate,
                sfSymbolName: sfSymbolName,
                isFutureManifestation: isFutureManifestation
            )
            AppHaptics.impact(.medium)
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
}

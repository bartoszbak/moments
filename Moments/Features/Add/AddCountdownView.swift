import SwiftUI

struct MomentDescriptionEditorView: View {
    @Binding var text: String

    var body: some View {
        Form {
            Section {
                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("Optional")
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                    }

                    TextEditor(text: $text)
                        .frame(minHeight: 220)
                }
            } footer: {
                Text("Example: \"I'm going for the meetup to hang out and chill.\"")
            }
        }
        .navigationTitle("Description")
        .navigationBarTitleDisplayMode(.inline)
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
        return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var showsProgressIndicatorSection: Bool {
        if isFutureManifestation { return false }
        return Calendar.current.startOfDay(for: targetDate) >= Calendar.current.startOfDay(for: Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("e.g. New Year, Vacation…", text: $title)
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
                    if showTitleError {
                        Label("Title is required", systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(.red).font(.caption)
                    }
                }
                Section("Target Date") {
                    Toggle("Future manifestation", isOn: $isFutureManifestation)
                    if !isFutureManifestation {
                        TargetDatePickerRow(targetDate: $targetDate, tintColor: controlTintColor)
                    }
                }
                BackgroundPickerSection(
                    selection: $background
                )
                WidgetOptionsSection(
                    allowsDateOption: !isFutureManifestation,
                    showDate: $showDate,
                    showSymbol: $showSymbol,
                    sfSymbolName: $sfSymbolName,
                    showSymbolPicker: $showSymbolPicker
                )
                if showsProgressIndicatorSection {
                    ProgressStartPickerSection(value: $startPercentage)
                }
            }
            .nativeGlassToggleStyleOnIPad(tintColor: controlTintColor)
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
                        .foregroundStyle(toolbarButtonColor)
                }
            }
        }
        .sheet(isPresented: $showSymbolPicker) {
            SFSymbolPickerView(selectedSymbol: $sfSymbolName, tintColor: controlTintColor)
        }
        .onChange(of: isFutureManifestation) { _, enabled in
            if enabled {
                showDate = false
            }
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
                sfSymbolName: normalizedSymbolName,
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

    private var detailsActionTitle: String {
        detailsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Add" : "Edit"
    }
}

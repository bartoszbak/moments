import SwiftUI
import PhotosUI

struct AddCountdownView: View {
    @EnvironmentObject private var repository: CountdownRepository
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var targetDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var background: BackgroundSelection = .none
    @State private var isCreating = false
    @State private var showTitleError = false
    @State private var showPastDateWarning = false

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
                Section("Target Date") {
                    DatePicker("Date & Time", selection: $targetDate, displayedComponents: [.date, .hourAndMinute])
                    if showPastDateWarning {
                        Label("This date is in the past", systemImage: "clock.badge.exclamationmark.fill")
                            .foregroundStyle(.orange).font(.caption)
                    }
                }
                BackgroundPickerSection(selection: $background)
            }
            .navigationTitle("New Countdown")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create", action: create)
                        .disabled(!isValid || isCreating).fontWeight(.semibold)
                }
            }
            .onChange(of: targetDate) { _, date in showPastDateWarning = date < Date() }
        }
    }

    private func create() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { showTitleError = true; return }
        isCreating = true

        var imagePath: String?
        var thumbPath: String?
        var colorIndex: Int?
        var colorHex: String?

        switch background {
        case .photo(let image):
            if let paths = ImageStorageService.save(image: image, id: UUID()) {
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
                title: trimmed, targetDate: targetDate,
                backgroundImagePath: imagePath, thumbnailImagePath: thumbPath,
                backgroundColorIndex: colorIndex, backgroundColorHex: colorHex
            )
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            dismiss()
        } catch { isCreating = false }
    }
}

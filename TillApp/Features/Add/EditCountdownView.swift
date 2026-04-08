import SwiftUI
import PhotosUI

struct EditCountdownView: View {
    let countdownID: UUID

    @EnvironmentObject private var repository: CountdownRepository
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var targetDate = Date()
    @State private var background: BackgroundSelection = .none
    @State private var startPercentage: Double = 1.0
    @State private var allowPastDate = false
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
                    Toggle("Allow Past Date", isOn: $allowPastDate)
                    if allowPastDate {
                        DatePicker("Date & Time", selection: $targetDate, displayedComponents: [.date, .hourAndMinute])
                    } else {
                        DatePicker("Date & Time", selection: $targetDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                    }
                    if allowPastDate && targetDate < Date() {
                        Label("Past dates are allowed and will show days since", systemImage: "clock.badge.exclamationmark.fill")
                            .foregroundStyle(.orange).font(.caption)
                    }
                }
                BackgroundPickerSection(selection: $background, onNewPhotoSelected: { photoChanged = true })
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
            .alert("Delete this countdown?", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive, action: delete)
                Button("Cancel", role: .cancel) { }
            }
            .navigationTitle("Edit Countdown")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                guard !hasLoaded, let countdown else { return }
                title = countdown.title
                targetDate = countdown.targetDate
                allowPastDate = countdown.targetDate < Date()
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
                hasLoaded = true
            }
            .onChange(of: allowPastDate) { _, isEnabled in
                if !isEnabled, targetDate < Date() {
                    targetDate = Date()
                }
            }
        }
    }

    private func save() {
        guard let countdown else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var imagePath: String?
        var thumbPath: String?
        var colorIndex: Int?? = nil
        var colorHex: String?? = nil

        switch background {
        case .photo(let image):
            if photoChanged {
                if let paths = ImageStorageService.save(image: image, id: countdown.id) {
                    imagePath = paths.backgroundPath
                    thumbPath = paths.thumbnailPath
                    colorIndex = .some(nil)
                    colorHex = .some(nil)
                }
            } else {
                // Photo unchanged — preserve existing paths, don't re-save thumbnail as background
                imagePath = existingImagePath
                thumbPath = existingThumbPath
                colorIndex = .some(nil)
                colorHex = .some(nil)
            }
        case .preset(let idx):
            colorIndex = .some(idx)
            colorHex = .some(ColorPalette.presets[idx].hexString)
        case .custom(let color):
            colorIndex = .some(nil)
            colorHex = .some(color.hexString)
        case .none:
            break
        }

        try? repository.update(
            countdown, title: trimmed, targetDate: targetDate,
            backgroundImagePath: imagePath, thumbnailImagePath: thumbPath,
            backgroundColorIndex: colorIndex, backgroundColorHex: colorHex,
            startPercentage: startPercentage
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
}

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
    @State private var hasLoaded = false

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
                    DatePicker("Date & Time", selection: $targetDate, displayedComponents: [.date, .hourAndMinute])
                    if targetDate < Date() {
                        Label("This date is in the past", systemImage: "clock.badge.exclamationmark.fill")
                            .foregroundStyle(.orange).font(.caption)
                    }
                }
                BackgroundPickerSection(selection: $background)
                ProgressStartPickerSection(value: $startPercentage)
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
                if let idx = countdown.backgroundColorIndex {
                    background = .preset(idx)
                } else if let hex = countdown.backgroundColorHex,
                          let color = Color(hex: hex) {
                    background = .custom(color)
                } else if let thumbURL = countdown.thumbnailImageURL,
                          let image = UIImage(contentsOfFile: thumbURL.path) {
                    background = .photo(image)
                }
                startPercentage = countdown.startPercentage
                hasLoaded = true
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
            if let paths = ImageStorageService.save(image: image, id: countdown.id) {
                imagePath = paths.backgroundPath
                thumbPath = paths.thumbnailPath
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
}

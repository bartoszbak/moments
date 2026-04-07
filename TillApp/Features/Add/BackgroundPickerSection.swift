import SwiftUI
import PhotosUI

enum BackgroundSelection {
    case none
    case preset(Int)
    case custom(Color)
    case photo(UIImage)
}

struct BackgroundPickerSection: View {
    @Binding var selection: BackgroundSelection
    var onNewPhotoSelected: (() -> Void)? = nil
    @State private var photoItem: PhotosPickerItem?
    @State private var customColor: Color = .accentColor

    var body: some View {
        Section(
            header: Text("Widget Background"),
            footer: Text("Shown behind your countdown on the home screen widget.")
        ) {
            colorRow
            photoPicker
        }
        .onAppear {
            if case .custom(let c) = selection { customColor = c }
        }
        .onChange(of: photoItem) { _, item in loadPhoto(from: item) }
    }

    // MARK: - Color Grid

    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    private var colorRow: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(0..<ColorPalette.presets.count, id: \.self) { presetButton(index: $0) }
            customPickerButton
        }
        .padding(.vertical, 8)
    }

    // Preset swatches — tap to select, tap again to deselect
    private func presetButton(index: Int) -> some View {
        let p = ColorPalette.presets[index]
        let isSelected = { if case .preset(let i) = selection { return i == index }; return false }()
        return swatchButton(isSelected: isSelected, action: {
            if isSelected { selection = .none } else { selection = .preset(index) }
            photoItem = nil
        }) {
            ZStack {
                Circle().fill(p.color)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(p.usesLightText ? Color.white : Color.black)
                }
            }
        }
    }

    // Custom color picker — plain dot, identical look to preset swatches
    private var customPickerButton: some View {
        let isSelected = { if case .custom = selection { return true }; return false }()
        return ColorPicker(selection: $customColor, supportsOpacity: false) {
            ZStack {
                Circle().fill(isSelected ? customColor : Color.secondary.opacity(0.2))
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(customColor.luminance < 0.5 ? Color.white : Color.black)
                }
            }
            .frame(width: 36, height: 36)
            .overlay(Circle().strokeBorder(isSelected ? Color.primary : .clear, lineWidth: 2))
        }
        .labelsHidden()
        .onChange(of: customColor) { _, c in
            selection = .custom(c)
            photoItem = nil
        }
    }

    // Generic swatch button wrapper
    private func swatchButton<Label: View>(
        isSelected: Bool,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) -> some View {
        Button(action: action) {
            label()
                .frame(width: 36, height: 36)
                .overlay(Circle().strokeBorder(isSelected ? Color.primary : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Photo Picker

    private var photoPicker: some View {
        PhotosPicker(selection: $photoItem, matching: .images) {
            HStack(spacing: 14) {
                if case .photo(let image) = selection {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 36, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    Text("Edit")
                        .font(.body).foregroundStyle(.primary)
                    Spacer()
                    Button {
                        selection = .none
                        photoItem = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                } else {
                    Label("Choose Photo", systemImage: "photo.on.rectangle.angled")
                        .font(.body)
                        .foregroundStyle(.primary)
                }
            }
        }
    }

    // MARK: - Load Photo

    private func loadPhoto(from item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    selection = .photo(image)
                    onNewPhotoSelected?()
                }
            }
        }
    }
}

// MARK: - Color luminance helper for text contrast

private extension Color {
    var luminance: Double {
        let ui = UIColor(self).resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: nil)
        return 0.2126 * Double(r) + 0.7152 * Double(g) + 0.0722 * Double(b)
    }
}

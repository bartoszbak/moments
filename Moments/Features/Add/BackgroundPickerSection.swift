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
    @Environment(\.colorScheme) private var colorScheme
    var onNewPhotoSelected: (() -> Void)? = nil
    @State private var photoItem: PhotosPickerItem?
    @State private var customColor = ColorPalette.presets.first?.color ?? .blue

    private let swatchSize: CGFloat = 40

    var body: some View {
        Section(
            header: Text("Widget"),
            footer: Text("Photo will have priority over color.")
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
    private let pickerPresetIndices = Array(ColorPalette.presets.indices)

    private var colorRow: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(pickerPresetIndices, id: \.self) { presetButton(index: $0) }
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
            swatchFill(
                color: p.color,
                isSelected: isSelected,
                borderColor: selectionBorderColor(for: p.color)
            )
        }
    }

    // Custom color picker — plain dot, identical look to preset swatches
    private var customPickerButton: some View {
        let isSelected = { if case .custom = selection { return true }; return false }()
        return ColorPicker(selection: $customColor, supportsOpacity: false) {
            swatchFill(
                color: isSelected ? customColor : Color.secondary.opacity(0.2),
                isSelected: isSelected,
                borderColor: selectionBorderColor(for: customColor)
            )
            .frame(width: swatchSize, height: swatchSize)
        }
        .labelsHidden()
        .accessibilityLabel("Custom color")
        .onChange(of: customColor) { old, c in
            guard old != c else { return }
            selection = .custom(c)
            photoItem = nil
        }
    }

    private func swatchFill(
        color: Color,
        isSelected: Bool,
        borderColor: Color
    ) -> some View {
        ZStack {
            Circle()
                .fill(color)

            if isSelected {
                selectionBorder(for: borderColor)
            }
        }
    }

    private func selectionBorder(for color: Color) -> some View {
        Circle()
            .strokeBorder(color, lineWidth: 2)
            .padding(3)
    }

    private func selectionBorderColor(for color: Color) -> Color {
        if colorScheme == .dark {
            return Color(uiColor: .secondarySystemGroupedBackground)
        }

        return color.luminance > 0.92 ? .black : .white
    }

    // Generic swatch button wrapper
    private func swatchButton<Label: View>(
        isSelected: Bool,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) -> some View {
        Button(action: action) {
            label()
                .frame(width: swatchSize, height: swatchSize)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Photo Picker

    private var photoPicker: some View {
        HStack(spacing: 14) {
            if case .photo(let image) = selection {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                PhotosPicker(selection: $photoItem, matching: .images) {
                    photoActionLink(title: "Edit")
                }

                Spacer()

                Button {
                    selection = .none
                    photoItem = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                        .font(.title3)
                }
                .padding(.trailing, 10)
                .buttonStyle(.plain)
            } else {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    photoActionLink(title: "Choose Photo")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func photoActionLink(title: String) -> some View {
        Text(title)
            .font(.body.weight(.medium))
            .foregroundStyle(.tint)
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

struct WidgetOptionsSection: View {
    var allowsDateOption: Bool = true
    var showsProgressBarStyleOption: Bool = true
    @Binding var isMinimalisticWidget: Bool
    @Binding var minimalWidgetProgressStyle: MinimalWidgetProgressStyle
    @Binding var showDate: Bool
    @Binding var widgetFontOption: WidgetFontOption

    var body: some View {
        Section {
            if allowsDateOption {
                Toggle("Minimalistic Widget", isOn: $isMinimalisticWidget)

                if isMinimalisticWidget && showsProgressBarStyleOption {
                    Picker("Progress Bar", selection: $minimalWidgetProgressStyle) {
                        ForEach(MinimalWidgetProgressStyle.allCases) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                }

                Toggle("Show Date on Widget", isOn: $showDate)
            }

            Picker("Font", selection: $widgetFontOption) {
                ForEach(WidgetFontOption.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
        }
    }
}

struct SymbolOptionsRows: View {
    @Binding var showSymbol: Bool
    @Binding var sfSymbolName: String?
    @Binding var showSymbolPicker: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Toggle("Add Symbol", isOn: $showSymbol.animation())
            .onChange(of: showSymbol) { _, enabled in
                if enabled {
                    if sfSymbolName == nil {
                        sfSymbolName = MomentSymbolPolicy.defaultSymbolName
                    }
                } else {
                    sfSymbolName = nil
                }
            }

        if showSymbol {
            Button { showSymbolPicker = true } label: {
                LabeledContent("Symbol") {
                    if let name = MomentSymbolPolicy.normalized(sfSymbolName) {
                        Image(systemName: name)
                            .font(.title3)
                            .foregroundStyle(symbolButtonColor)
                    } else {
                        Text("Choose…")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .foregroundStyle(.primary)
        }
    }

    private var symbolButtonColor: Color {
        colorScheme == .dark ? .white : .black
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

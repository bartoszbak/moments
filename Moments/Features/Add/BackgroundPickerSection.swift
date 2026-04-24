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
    @State private var customColor = Color(hue: 0.72, saturation: 0.72, brightness: 0.72)
    @State private var customHue: Double = 0.72
    @State private var customBrightness: Double = 0.45

    private let swatchSize: CGFloat = 36
    private let colorRowSpacing: CGFloat = 18
    private let customSaturation: Double = 0.72
    private let minimumCustomBrightness: Double = 0.38

    var body: some View {
        Section(
            header: Text("Widget"),
            footer: Text("Photo will have priority over color.")
        ) {
            colorPickerPanel
            photoPicker
        }
        .onAppear {
            if case .custom(let c) = selection {
                customColor = c
                syncCustomControls(from: c)
            }
        }
        .onChange(of: photoItem) { _, item in loadPhoto(from: item) }
    }

    // MARK: - Color Grid

    private let pickerPresetIndices = [5, 3, 1, 0, 4]

    private var isCustomSelected: Bool {
        if case .custom = selection { return true }
        return false
    }

    private var colorPickerPanel: some View {
        VStack(spacing: 22) {
            HStack(spacing: colorRowSpacing) {
                customPickerButton
                    .frame(width: swatchSize, height: swatchSize)

                colorPickerDivider

                HStack(spacing: 17) {
                    ForEach(pickerPresetIndices, id: \.self) { presetButton(index: $0) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isCustomSelected {
                VStack(spacing: 18) {
                    HueSelectionSlider(value: $customHue) {
                        updateCustomColorFromControls()
                    }

                    BrightnessSelectionSlider(
                        hue: customHue,
                        saturation: customSaturation,
                        value: $customBrightness
                    ) {
                        updateCustomColorFromControls()
                    }
                }
            }
        }
        .padding(.vertical, 11)
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
                isSelected: isSelected
            )
        }
    }

    // Custom color picker — hue ring that reveals inline controls.
    private var customPickerButton: some View {
        Button {
            updateCustomColorFromControls()
        } label: {
            customColorSwatch(isSelected: isCustomSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Custom color")
    }

    private var colorPickerDivider: some View {
        RoundedRectangle(cornerRadius: 1, style: .continuous)
            .fill(Color.secondary.opacity(colorScheme == .dark ? 0.35 : 0.2))
            .frame(width: 1, height: swatchSize * 0.72)
            .padding(.horizontal, 2)
    }

    private func customColorSwatch(isSelected: Bool) -> some View {
        ZStack {
            AngularGradient(
                colors: [
                    .red,
                    .orange,
                    .yellow,
                    .green,
                    .cyan,
                    .blue,
                    .purple,
                    .pink,
                    .red
                ],
                center: .center
            )
            .clipShape(Circle())

            if isSelected {
                selectedSwatchDot
            }
        }
        .frame(width: swatchSize, height: swatchSize)
    }

    private func updateCustomColorFromControls() {
        customColor = Color(
            hue: customHue,
            saturation: saturation(fromSliderPosition: customBrightness),
            brightness: brightness(fromSliderPosition: customBrightness)
        )
        selection = .custom(customColor)
        photoItem = nil
    }

    private func syncCustomControls(from color: Color) {
        let uiColor = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        guard uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return
        }

        customHue = Double(hue)
        customBrightness = sliderPosition(
            fromSaturation: Double(saturation),
            brightness: Double(brightness)
        )
    }

    private func brightness(fromSliderPosition position: Double) -> Double {
        1 - (position.clamped(to: 0...1) * (1 - minimumCustomBrightness))
    }

    private func saturation(fromSliderPosition position: Double) -> Double {
        customSaturation * position.clamped(to: 0...1)
    }

    private func sliderPosition(fromSaturation saturation: Double, brightness: Double) -> Double {
        let saturationPosition = saturation.clamped(to: 0...customSaturation) / customSaturation
        let brightnessPosition = (1 - brightness.clamped(to: minimumCustomBrightness...1)) / (1 - minimumCustomBrightness)
        return max(saturationPosition, brightnessPosition)
            .clamped(to: 0...1)
    }

    private func swatchFill(
        color: Color,
        isSelected: Bool
    ) -> some View {
        ZStack {
            Circle()
                .fill(color)

            if isSelected {
                selectedSwatchDot
            }
        }
    }

    private var selectedSwatchDot: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 16, height: 16)
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.18 : 0.1), radius: 1, y: 0.5)
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
        .frame(width: swatchSize, height: swatchSize)
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
                    photoActionLink(title: "Select Photo")
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

private struct HueSelectionSlider: View {
    @Binding var value: Double
    let onChange: () -> Void

    var body: some View {
        ColorSelectionSlider(
            value: $value,
            track: {
                LinearGradient(
                    colors: [
                        Color(red: 243 / 255, green: 51 / 255, blue: 2 / 255),
                        Color(red: 230 / 255, green: 178 / 255, blue: 0 / 255),
                        Color(red: 168 / 255, green: 242 / 255, blue: 46 / 255),
                        Color(red: 0 / 255, green: 218 / 255, blue: 144 / 255),
                        Color(red: 2 / 255, green: 121 / 255, blue: 234 / 255),
                        Color(red: 161 / 255, green: 58 / 255, blue: 245 / 255),
                        Color(red: 196 / 255, green: 6 / 255, blue: 242 / 255),
                        Color(red: 240 / 255, green: 25 / 255, blue: 66 / 255)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            },
            thumbColor: Color(hue: value, saturation: 0.84, brightness: 0.92),
            onChange: onChange
        )
    }
}

private struct BrightnessSelectionSlider: View {
    let hue: Double
    let saturation: Double
    @Binding var value: Double
    let onChange: () -> Void

    private let minimumBrightness = 0.38

    private var selectedBrightness: Double {
        1 - (value.clamped(to: 0...1) * (1 - minimumBrightness))
    }

    private var selectedSaturation: Double {
        saturation * value.clamped(to: 0...1)
    }

    var body: some View {
        ColorSelectionSlider(
            value: $value,
            track: {
                LinearGradient(
                    colors: [
                        .white,
                        Color(hue: hue, saturation: saturation, brightness: 0.78),
                        Color(hue: hue, saturation: saturation, brightness: 0.38)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            },
            thumbColor: Color(hue: hue, saturation: selectedSaturation, brightness: selectedBrightness),
            onChange: onChange
        )
    }
}

private struct ColorSelectionSlider<Track: View>: View {
    @Binding var value: Double
    @ViewBuilder var track: () -> Track
    let thumbColor: Color
    let onChange: () -> Void

    private let trackHeight: CGFloat = 30
    private let thumbSize: CGFloat = 32

    var body: some View {
        GeometryReader { geometry in
            let width = max(1, geometry.size.width)
            let travelWidth = max(1, width - thumbSize)
            let clampedValue = value.clamped(to: 0...1)
            let thumbX = (thumbSize / 2) + (CGFloat(clampedValue) * travelWidth)

            ZStack(alignment: .leading) {
                track()
                    .clipShape(Capsule())
                    .overlay {
                        Capsule()
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    }
                    .frame(height: trackHeight)

                Circle()
                    .fill(Color(uiColor: .systemBackground))
                    .frame(width: thumbSize, height: thumbSize)
                    .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
                    .overlay {
                        Circle()
                            .fill(thumbColor)
                            .padding(8)
                    }
                    .offset(x: thumbX - (thumbSize / 2))
                    .allowsHitTesting(false)
            }
            .frame(height: thumbSize)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        value = ((gesture.location.x - (thumbSize / 2)) / travelWidth).clamped(to: 0...1)
                        onChange()
                    }
            )
        }
        .frame(height: thumbSize)
        .padding(.horizontal, 4)
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

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

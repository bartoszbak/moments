import SwiftUI

struct ProgressStartPickerSection: View {
    @Binding var isEnabled: Bool
    @Binding var value: Double

    var body: some View {
        Section {
            Toggle("Show Progress on Widget", isOn: $isEnabled)

            if isEnabled {
                Slider(value: $value, in: 0.5...1.0, step: 0.125) {
                    EmptyView()
                } minimumValueLabel: {
                    Text("50%").font(.caption)
                } maximumValueLabel: {
                    Text("100%").font(.caption)
                }
            }
        } footer: {
            Text("Set the progress start point. It begins at the selected percentage and shrinks to zero by the event day.")
        }
    }
}
